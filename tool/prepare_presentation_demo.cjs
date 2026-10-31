// Demo verilerini inceleme ve sunum verilerini güvenli biçimde ekleme aracı.
const fs = require('node:fs');
const path = require('node:path');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
const crypto = require('node:crypto');
const apply = process.argv.includes('--apply');
const project = 'ubsoft-pdks';
const tid = 'turgev-demo';
const root = `projects/${project}/databases/(default)/documents/`;
const base = `https://firestore.googleapis.com/v1/${root.slice(0,-1)}`;
let token;
async function request(url, body) {
 const r = await fetch(url, {method:body?'POST':'GET', headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'}, ...(body?{body:JSON.stringify(body)}:{})});
 if(!r.ok) throw new Error(`HTTP ${r.status}: ${await r.text()}`);
 return r.json();
}
const decode = v => v.stringValue ?? v.timestampValue ?? (v.integerValue!==undefined?Number(v.integerValue):v.doubleValue!==undefined?v.doubleValue:v.booleanValue!==undefined?v.booleanValue:v.mapValue?Object.fromEntries(Object.entries(v.mapValue.fields??{}).map(([k,x])=>[k,decode(x)])):null);
async function list(c) {let docs=[], page='';do {const r=await request(`${base}/${c}?pageSize=1000${page?'&pageToken='+encodeURIComponent(page):''}`);docs.push(...(r.documents??[]));page=r.nextPageToken??'';}while(page);return docs;}
const encode = v => v===null?{nullValue:null}:v instanceof Date?{timestampValue:v.toISOString()}:typeof v==='string'?{stringValue:v}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]))}};
const fields = o => Object.fromEntries(Object.entries(o).map(([k,v])=>[k,encode(v)]));
const plain = d => Object.fromEntries(Object.entries(d.fields).map(([k,v])=>[k,decode(v)]));
const canonical = v => JSON.stringify(v,(_,x)=>x&&typeof x==='object'&&!Array.isArray(x)?Object.fromEntries(Object.entries(x).sort(([a],[b])=>a.localeCompare(b))):x);
const names=['Zehra Acar','Esma Yıldız','İrem Çelik','Büşra Koç','Rabia Arslan','Hatice Güneş','Zümra Polat','Sümeyye Kılıç','Meryem Eren','Hümeyra Şen','Betül Yavuz','Nisa Bulut','Aslı Yalçın','Ceren Duman','İlayda Kurt','Ecrin Uçar','Sena Karaca','Derya Özkan','Şevval Tekin','Havva Kaplan','Dila Erdem','Sare Taş','Melike Sezer','Yasemin Keskin','Tuğba Akın','Ayşenur Korkmaz','Hilal Baş'];
const seed='presentation-demo-v1';
const now=new Date();
const localNow=new Date(now.getTime()+3*3600000);
const today=localNow.toISOString().slice(0,10);
const dayKey = offset => new Date(Date.parse(today+'T00:00:00Z')+offset*86400000).toISOString().slice(0,10);
const at = (offset,minute) => new Date(Date.parse(dayKey(offset)+'T00:00:00+03:00')+minute*60000);
const policy={hours:{earliestExit:360,latestEntry:1350,earliestEntry:420,enabled:true},tolerance:10,weekdays:{},exceptions:{}};
async function populate(snapshot) {
 if(plain(snapshot.tenant).name!=='TÜRGEV Demo') throw new Error('Hedef doğrulaması başarısız');
 const existing=snapshot.collections.users.filter(d=>d.fields.demoSource?.stringValue===seed);
 if(existing.length) throw new Error('Sunum verileri daha önce eklenmiş. Yeniden yazmak yerine mevcut verileri kullanın.');
 console.log(JSON.stringify({mode:apply?'apply':'dry-run',target:tid,newStudents:names.length,historyDays:14,existingStudentsPreserved:3,scenarios:['çoklu giriş çıkış','geç giriş','erken çıkış','erken giriş','gece yarısı dönüş','dönüşü geciken','aktif izin','süresi dolan izin','gelecek izin','iptal izin','başlangıç kaydı yok','konum uyarısı','gerekçeli geçersiz hareket']}));
 if(!apply) return;
 const writes=[];const accounts=[];
 const add=(collection,id,body)=>writes.push({update:{name:root+`tenants/${tid}/${collection}/${id}`,fields:fields({...body,demoSource:seed})},currentDocument:{exists:false}});
 const actor=snapshot.collections.users.find(d=>d.fields.email?.stringValue==='mudire@turgevdemo.com').name.split('/').at(-1);
 let eventCount=0,dayCount=0;const counts={inside:0,outside:0,unknown:0};
 for(let i=0;i<names.length;i++) {
  const email=`sunum${String(i+1).padStart(2,'0')}@turgevdemo.com`;
  const password=crypto.randomBytes(24).toString('base64url');
  const identity=`https://identitytoolkit.googleapis.com/v1/projects/${project}`;
  const lookup=await request(identity+'/accounts:lookup',{email:[email]});
  let uid=lookup.users?.[0]?.localId;
  if(uid) throw new Error(`Sunum adresi zaten var: ${email}; otomatik yeniden kullanılmadı.`);
  const created=await request(identity+'/accounts',{email,password,emailVerified:false,displayName:names[i]});
  uid=created.localId;if(!uid)throw new Error('Demo kimliği oluşturulamadı');
  accounts.push({uid,email,password});
  fs.writeFileSync(path.resolve('.local-backups','presentation-created-accounts.json'),JSON.stringify(accounts,null,2));
  add('users',uid,{uid,email,displayName:names[i],tenantId:tid,role:'staff',status:'active',permissions:{},studentNumber:`D2026${String(i+4).padStart(3,'0')}`,room:String(101+Math.floor(i/3)),note:'Sunum için kurgusal öğrenci',createdAt:at(-20,720),updatedAt:now});
  if(i===26){counts.unknown++;continue;}
  let all=[];
  const addEvent=(offset,minute,type,options={})=>{
   const time=at(offset,minute); if(time>now) return;
   const cp=type==='in'?'giris':'cikis';
   const id=`present_v1_${uid}_${dayKey(offset)}_${String(minute).padStart(4,'0')}_${type}`;
   const isPermitted=options.permitted??false;
   const localMinute=minute%1440;
   const late=type==='in'&&!isPermitted?(localMinute<360?localMinute+1440-1360:Math.max(0,localMinute-1360)):0;
   const body={tenantId:tid,userId:uid,userName:names[i],type,at:time,dateKey:new Date(time.getTime()+10800000).toISOString().slice(0,10),checkpointId:cp,checkpointName:type==='in'?'Yurt Ana Giriş':'Yurt Çıkış Kapısı',checkpointCode:type==='in'?'1':'2',verdict:i===11?'unavailable':i===12?'borderline':'verified',radiusMeters:75,lateMinutes:late,earlyExit:type==='out'&&localMinute<360&&!isPermitted,earlyEntry:type==='in'&&localMinute<420&&!isPermitted,permitted:isPermitted,cycleDate:dayKey(offset),policy,voided:false,schemaVersion:2,demoScenario:options.scenario??'Düzenli giriş çıkış'};
   all.push({id,body});
  };
  for(let d=-14;d<=-2;d++) {
   if(i===7 && d===-3){addEvent(d,480,'out');addEvent(d+1,25,'in',{scenario:'Gece yarısından sonra dönüş'});continue;}
   if(i===7 && d===-2){addEvent(d,840,'out');addEvent(d,1200,'in');continue;}
   const early=i===5 && d%3===0;
   const multi=i%3===1 || (i===0 && d%2===0);
   addEvent(d,i===6?300:early?320:480+(i%5)*7,'out',{scenario:early?'Erken çıkış':'Düzenli çıkış'});
   if(multi){addEvent(d,730,'in');addEvent(d,850,'out');}
   addEvent(d,i===2 && d%2===0?1390:i===6?410:1180+(i%7)*10,'in',{scenario:i===2?'Geç giriş':multi?'Aynı gün birden çok giriş çıkış':i===6?'Erken giriş':'Zamanında dönüş'});
  }
  addEvent(-1,480,'out');
  // Dönüşü gecikenler ve izinliler dün çıkmış, henüz geri dönmemiştir.
  const stayOutside=[3,4,8,9,10].includes(i);
  if(!stayOutside) addEvent(-1,i===2?1395:1200,'in',{scenario:i===2?'Geç giriş':'Zamanında dönüş'});
  if(!stayOutside) {
   addEvent(0,i===5?325:480,'out');
   if(i%4===0){addEvent(0,720,'in');addEvent(0,840,'out');}
   if(![13,14].includes(i)) addEvent(0,i===2?1380:1180+(i%6)*10,'in',{scenario:i===2?'Geç giriş':'Güncel dönüş'});
  }
  if([8,9,10,15,16].includes(i)) {
   const spec=i===8?{from:at(-1,420),until:at(2,1200),reason:'Aile ziyareti için izin',revoked:false}:i===9?{from:at(-1,420),until:new Date(now.getTime()-3600000),reason:'Dönüş saati geçen izin',revoked:false}:i===10?{from:at(-1,420),until:at(1,1200),reason:'İptal edilmiş izin örneği',revoked:true}:i===15?{from:at(1,480),until:at(3,1200),reason:'Gelecek tarihli aile ziyareti',revoked:false}:{from:at(-7,480),until:at(-6,1200),reason:'Tamamlanmış geçmiş izin',revoked:false};
   const id=`present_v1_leave_${uid}`;
   for(const e of all) if(!spec.revoked && e.body.at>=spec.from && e.body.at<=spec.until){e.body.permitted=true;e.body.lateMinutes=0;e.body.earlyExit=false;e.body.earlyEntry=false;}
   add('leaves',id,{userId:uid,...spec,actor,createdAt:at(-14,600),updatedAt:now,...(spec.revoked?{revokedBy:actor}:{})});
   if(!spec.revoked && spec.until>now) add('leaveLocks',uid,{userId:uid,...spec,leaveId:id,actor,updatedAt:now});
  }
  all.sort((a,b)=>a.body.at-b.body.at);
  for(let n=1;n<all.length;n++) if(all[n].body.type===all[n-1].body.type) throw new Error(`Hareket sırası hatalı: ${i} ${all[n].body.dateKey}`);
  for(const e of all){add('attendance',e.id,e.body);eventCount++;}
  const days=Map.groupBy(all,e=>e.body.dateKey);
  for(const [key,events] of days) {
   const ins=events.filter(e=>e.body.type==='in');const outs=events.filter(e=>e.body.type==='out');
   let openAt=null,minutes=0;for(const e of events){if(e.body.type==='in')openAt=e.body.at;else if(openAt){minutes+=Math.floor((e.body.at-openAt)/60000);openAt=null;}}
   add('attendanceDays',`${uid}_${key}`,{tenantId:tid,userId:uid,userName:names[i],dateKey:key,firstEntryAt:ins[0]?.body.at??null,lastEntryAt:ins.at(-1)?.body.at??null,lastExitAt:outs.at(-1)?.body.at??null,entryCount:ins.length,exitCount:outs.length,workedMinutes:minutes,open:events.at(-1).body.type==='in',late:ins.some(e=>e.body.lateMinutes>0),worstVerdict:events[0].body.verdict,updatedAt:now});dayCount++;
  }
  const last=all.at(-1); const inside=last.body.type==='in';counts[inside?'inside':'outside']++;
  add('presence',uid,{userId:uid,inside,eventId:last.id,at:last.body.at,checkpoint:last.body.checkpointName,revision:all.length,lateMinutes:last.body.lateMinutes,earlyExit:last.body.earlyExit,earlyEntry:last.body.earlyEntry,permitted:last.body.permitted});
  if(i===17) add('attendance',`present_v1_void_${uid}`,{...all[0].body,voided:true,voidReason:'Sunum senaryosu yanlışlıkla alınan mükerrer kayıt',voidedBy:actor,voidedAt:now,demoScenario:'Gerekçeli geçersiz kayıt'});
 }
 const old=plain(snapshot.tenant);
 writes.push({update:{name:snapshot.tenant.name,fields:{settings:encode({...old.settings,dormPolicy:policy}),counters:encode({...old.counters,userCount:snapshot.collections.users.length+names.length}),updatedAt:encode(now)}},updateMask:{fieldPaths:['settings','counters','updatedAt']},currentDocument:{updateTime:snapshot.tenant.updateTime}});
 fs.writeFileSync(path.resolve('.local-backups','presentation-planned-writes.json'),JSON.stringify({project,tid,writes},null,2));
 for(let n=0;n<writes.length;n+=250) await request(base+':commit',{writes:writes.slice(n,n+250)});
 const verify=Object.fromEntries(await Promise.all(['users','attendance','attendanceDays','presence','leaves'].map(async c=>[c,(await list(`tenants/${tid}/${c}`)).length])));
 console.log(JSON.stringify({applied:true,newStudents:names.length,generatedEvents:eventCount,generatedDays:dayCount,newStudentStates:counts,verifiedTotals:verify,generatedAt:now.toISOString()},null,2));
}
async function main() {
 const account=auth.getAllAccounts().find(a=>a.user.email==='harun123gimba@gmail.com');
 if(!account)throw new Error('Yetkili hesap bulunamadı');
 token=(await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform'])).access_token;
 const tenant=await request(`${base}/tenants/${tid}`);
 const cols=['users','checkpoints','presence','attendance','attendanceDays','leaves','leaveLocks'];
 const snapshot={tenant,collections:Object.fromEntries(await Promise.all(cols.map(async c=>[c,await list(`tenants/${tid}/${c}`)])))};
 if(process.argv.includes('--verify')) {
  const students=snapshot.collections.users.filter(d=>d.fields.role?.stringValue==='staff');
  const events=snapshot.collections.attendance.filter(d=>d.fields.demoSource?.stringValue===seed&&d.fields.voided?.booleanValue!==true).map(d=>({id:d.name.split('/').at(-1),...plain(d)}));
  const grouped=Map.groupBy(events,e=>e.userId);let sequenceErrors=0,stateErrors=0;
  for(const [uid,rows] of grouped){rows.sort((a,b)=>a.at.localeCompare(b.at));for(let n=1;n<rows.length;n++)if(rows[n].type===rows[n-1].type)sequenceErrors++;const s=snapshot.collections.presence.find(d=>d.name.endsWith('/'+uid));if(!s||plain(s).eventId!==rows.at(-1).id||plain(s).inside!==(rows.at(-1).type==='in'))stateErrors++;}
  const dayGroups=Map.groupBy(events,e=>e.userId+'_'+e.dateKey);
  const before=JSON.parse(fs.readFileSync(path.resolve('.local-backups','presentation-before.json'),'utf8'));
  const preserved=before.collections.attendance.every(d=>snapshot.collections.attendance.some(x=>x.name===d.name&&canonical(x.fields)===canonical(d.fields)));
  console.log(JSON.stringify({verifiedStudents:students.length,verifiedMovements:snapshot.collections.attendance.length,sequenceErrors,stateErrors,originalMovementsPreserved:preserved,multipleTripDays:[...dayGroups.values()].filter(es=>es.filter(e=>e.type==='in').length>1).length,lateEntries:events.filter(e=>e.lateMinutes>0).length,earlyExits:events.filter(e=>e.earlyExit).length,earlyEntries:events.filter(e=>e.earlyEntry).length,leaveRecords:snapshot.collections.leaves.length,futureMovementErrors:events.filter(e=>new Date(e.at)>new Date()).length},null,2));
  if(sequenceErrors||stateErrors||!preserved)throw new Error('Demo bütünlük doğrulaması başarısız');
  return;
 }
 const dir=path.resolve('.local-backups'); fs.mkdirSync(dir,{recursive:true});
 const backup=path.join(dir,`presentation-before-${now.toISOString().replaceAll(':','-')}.json`);
 fs.writeFileSync(backup,JSON.stringify(snapshot,null,2));
 const baseline=path.join(dir,'presentation-before.json');
 if(!fs.existsSync(baseline))fs.writeFileSync(baseline,JSON.stringify(snapshot,null,2));
 await populate(snapshot);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
