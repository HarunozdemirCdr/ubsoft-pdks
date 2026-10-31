// Varsayılan yalnız planlar. --apply canlı geçişi uygular; hiçbir kayıt silmez.
// Firebase CLI'ın açık hesabı kullanılır; erişim anahtarları dosyaya/çıktıya yazılmaz.
const fs = require('node:fs');
const path = require('node:path');
const auth = require(path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/auth.js'));
const apply = process.argv.includes('--apply');
const project = 'ubsoft-pdks';
const accountEmail = 'harun123gimba@gmail.com';
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const name = `projects/${project}/databases/(default)/documents/`;
let token;
const value = x => x===null?{nullValue:null}:typeof x==='string'?{stringValue:x}:typeof x==='boolean'?{booleanValue:x}:typeof x==='number'?{integerValue:String(x)}:{mapValue:{fields:Object.fromEntries(Object.entries(x).map(([k,v])=>[k,value(v)]))}};
const plain = x => x.stringValue ?? (x.booleanValue!==undefined?x.booleanValue:x.integerValue!==undefined?Number(x.integerValue):x.timestampValue!==undefined?x.timestampValue:x.mapValue?Object.fromEntries(Object.entries(x.mapValue.fields??{}).map(([k,v])=>[k,plain(v)])):null);
async function call(url, options={}) {
 const r = await fetch(url,{...options,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json',...options.headers}});
 if(!r.ok)throw new Error(`Firestore HTTP ${r.status}: ${r.statusText}`);
 return r.json();
}
async function list(collection){
 const docs=[];let next='';
 do{const q=await call(`${base}/${collection}?pageSize=300${next?'&pageToken='+encodeURIComponent(next):''}`);docs.push(...(q.documents??[]));next=q.nextPageToken??'';}while(next);
 return docs;
}
function update(doc,patch){return {update:{name:doc.name,fields:{...doc.fields,...patch}},updateMask:{fieldPaths:Object.keys(patch)},currentDocument:{updateTime:doc.updateTime}};}
async function main(){
 const account=auth.getAllAccounts().find(a=>a.user.email===accountEmail);
 if(!account)throw new Error('Yetkili Firebase hesabı eklenmemiş.');
 const credentials=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
 token=credentials.access_token;
 if(!token)throw new Error('Firebase erişim oturumu yenilenemedi.');
 const tenants=await list('tenants');const snapshot=[];const writes=[];
 const totals={dorms:0,presence:0,splitQr:0,unknownStudents:0};
 for(const tenant of tenants){
  const tid=tenant.name.split('/').at(-1);if(tid==='_system')continue;totals.dorms++;
  const prefix=`tenants/${tid}`;
  const [users,events,points,indexes,states,defaults]=await Promise.all(['users','attendance','checkpoints','qrIndex','presence','roleDefaults'].map(c=>list(`${prefix}/${c}`)));
  snapshot.push(tenant,...users,...events,...points,...indexes,...states,...defaults);
  for (const role of ['staff','admin']) {
   const doc=defaults.find(d=>d.name.endsWith('/'+role));
   const old=doc?.fields.permissions?.mapValue?.fields??{};
   const permissions={...old,'punch.create':value(role==='staff'),'attendance.viewOwn':value(true)};
   if(old['punch.create']?.booleanValue===(role==='staff')&&old['attendance.viewOwn']?.booleanValue===true)continue;
   if(doc)writes.push(update(doc,{permissions:{mapValue:{fields:permissions}}}));
   else writes.push({update:{name:name+`${prefix}/roleDefaults/${role}`,fields:{permissions:{mapValue:{fields:permissions}}}},currentDocument:{exists:false}});
  }
  const existing=new Set(states.map(d=>d.name.split('/').at(-1)));
  const valid=events.filter(d=>d.fields.voided?.booleanValue!==true&&d.fields.at?.timestampValue)
    .sort((a,b)=>a.fields.at.timestampValue.localeCompare(b.fields.at.timestampValue));
  for(const user of users.filter(d=>d.fields.role?.stringValue==='staff')){
   const uid=user.name.split('/').at(-1);if(existing.has(uid))continue;
   const latest=valid.filter(d=>d.fields.userId?.stringValue===uid).at(-1);
   if(!latest){totals.unknownStudents++;continue;}
   writes.push({update:{name:name+`${prefix}/presence/${uid}`,fields:{
    userId:value(uid),inside:value(latest.fields.type.stringValue==='in'),eventId:value(latest.name.split('/').at(-1)),
    at:latest.fields.at,checkpoint:latest.fields.checkpointName??value(''),revision:value(1),
    migratedFrom:value('attendance-v1'),lateMinutes:value(0),earlyExit:value(false),earlyEntry:value(false),
   }},currentDocument:{exists:false}});totals.presence++;
  }
  const codes=new Set(indexes.map(d=>d.name.split('/').at(-1)));
  let candidate=1;let added=0;
  for(const point of points.filter(d=>d.fields.kind?.stringValue==='both')){
   const id=point.name.split('/').at(-1);const exitId=id+'_exit_v2';
   if(points.some(d=>d.name.endsWith('/'+exitId)))throw new Error('Yarım QR geçişi var; elle inceleyin.');
   while(codes.has(String(candidate)))candidate++;
   const code=String(candidate++);codes.add(code);
   writes.push(update(point,{kind:value('in'),name:value(`${plain(point.fields.name)} · Giriş`),migrationVersion:value(2)}));
   writes.push({update:{name:name+`${prefix}/checkpoints/${exitId}`,fields:{...point.fields,
    kind:value('out'),code:value(code),name:value(`${plain(point.fields.name)} · Çıkış`),migrationVersion:value(2)}},currentDocument:{exists:false}});
   writes.push({update:{name:name+`${prefix}/qrIndex/${code}`,fields:{checkpointId:value(exitId),migrationVersion:value(2)}},currentDocument:{exists:false}});
   added++;totals.splitQr++;
  }
  if(added){const counters=plain(tenant.fields.counters??{mapValue:{fields:{}}});
   writes.push(update(tenant,{counters:value({...counters,checkpointCount:(counters.checkpointCount??points.length)+added})}));}
 }
 console.log(JSON.stringify({mode:apply?'apply':'dry-run',project,...totals,plannedWrites:writes.length}));
 if(!apply)return;
 const dir=path.resolve('.local-backups');fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,`dorm-migration-${new Date().toISOString().replaceAll(':','-')}.json`),JSON.stringify({project,documents:snapshot},null,2));
 for(let i=0;i<writes.length;i+=300)await call(base+':commit',{method:'POST',body:JSON.stringify({writes:writes.slice(i,i+300)})});
 console.log('Geçiş tamamlandı. Eski hareketler korundu; ortak QR için yeni çıkış etiketleri yazdırılmalı.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
