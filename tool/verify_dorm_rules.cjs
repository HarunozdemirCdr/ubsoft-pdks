// Yalnız demo projesindeki yerel emulator üzerinde çalışır, canlı veriye erişmez.
const assert = require('node:assert/strict');
const project = 'demo-yurt-test';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Firestore ve Auth emulator zorunlu');
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const name = `projects/${project}/databases/(default)/documents/`;
const account = async (email) => {
  const r = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:'Test-123456',returnSecureToken:true})});
  const v = await r.json(); assert.ok(r.ok,JSON.stringify(v)); return {uid:v.localId,token:v.idToken};
};
const val = v => v===null ? {nullValue:null} : typeof v==='boolean'?{booleanValue:v}:
  typeof v==='number'?{integerValue:String(v)}:v instanceof Date?{timestampValue:v.toISOString()}:
  typeof v==='string'?{stringValue:v}:{mapValue:{fields:fields(v)}};
const fields = obj => Object.fromEntries(Object.entries(obj).map(([k,v])=>[k,val(v)]));
const write = (path,data,server=[]) => ({update:{name:name+path,fields:fields(data)},
  ...(server.length?{updateTransforms:server.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})});
const commit = async (token,writes) => fetch(base+':commit',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify({writes})});
const seed = async (p,d)=>{const r=await commit('owner',[write(p,d)]);assert.ok(r.ok,await r.text());};
let passed=0;
async function check(label,allowed,token,writes){const r=await commit(token,writes);const body=await r.text();assert.equal(r.ok,allowed,`${label}: ${r.status} ${body}`);passed++;console.log('PASS '+label);}
async function main(){
  const student=await account('student@test.example');const admin=await account('admin@test.example');const outsider=await account('outsider@test.example');
  const tid='dorm';const root=`tenants/${tid}`;
  await seed(root,{status:'active',subscription:{expiresAt:new Date(Date.now()+86400000)},counters:{userCount:1,checkpointCount:2}});
  await seed(`${root}/users/${student.uid}`,{uid:student.uid,tenantId:tid,status:'active',role:'staff',permissions:{}});
  await seed(`${root}/users/${admin.uid}`,{uid:admin.uid,tenantId:tid,status:'active',role:'admin',permissions:{}});
  await seed(`${root}/roleDefaults/staff`,{permissions:{'punch.create':true,'attendance.viewOwn':true}});
  await seed(`${root}/checkpoints/in`,{kind:'in',code:'1',active:true});
  await seed(`${root}/checkpoints/out`,{kind:'out',code:'2',active:true});
  await seed(`${root}/checkpoints/both`,{kind:'both',code:'3',active:true});
  let id=0;
  function movement(who,type,cp=type,revision=1){
    const eid='e'+(++id);const point=cp==='in'?'1':cp==='out'?'2':'3';
    return [write(`${root}/attendance/${eid}`,{userId:who.uid,tenantId:tid,type,checkpointId:cp,checkpointCode:point,dateKey:'2026-11-01',verdict:'verified',schemaVersion:2,voided:false},['at']),
      write(`${root}/presence/${who.uid}`,{userId:who.uid,inside:type==='in',eventId:eid,revision},['at'])];
  }
  await check('okutma ve kalıcı durum birlikte yazılır',true,student.token,movement(student,'in'));
  await check('aynı yöne ikinci okutma reddedilir',false,student.token,movement(student,'in','in',2));
  await check('bekleme süresi sunucuda uygulanır',false,student.token,movement(student,'out','out',2));
  await check('yanlış yönlü QR reddedilir',false,student.token,movement(student,'out','in',2));
  await check('ortak QR reddedilir',false,student.token,movement(student,'in','both',2));
  await check('yönetici öğrenci adına hareket oluşturamaz',false,admin.token,movement(admin,'in'));
  await check('başka yurdun kullanıcısı yazamaz',false,outsider.token,movement(outsider,'in'));
  const concurrent = await account('concurrent@test.example');
  await seed(`${root}/users/${concurrent.uid}`,{uid:concurrent.uid,tenantId:tid,status:'active',role:'staff',permissions:{}});
  const simultaneous = await Promise.all([commit(concurrent.token,movement(concurrent,'in')),commit(concurrent.token,movement(concurrent,'in'))]);
  assert.equal(simultaneous.filter(r=>r.ok).length,1);passed++;console.log('PASS iki cihazın aynı anda girişi tek kayıt oluşturur');
  await check('eşlenmemiş günlük durum yazılamaz',false,student.token,[write(`${root}/presence/${student.uid}`,{userId:student.uid,inside:false,eventId:'missing',revision:2},['at'])]);
  await check('öğrenci sayaç değiştiremez',false,student.token,[write(root,{status:'active',subscription:{expiresAt:new Date(Date.now()+86400000)},counters:{userCount:0}})]);
  await seed(`${root}/presence/${student.uid}`,{userId:student.uid,inside:true,at:new Date(Date.now()-120000),eventId:'old',revision:1});
  await check('geçerli çıkış kalıcı durumu günceller',true,student.token,movement(student,'out','out',2));
  const standalone=movement(student,'in','in',3).slice(0,1);
  await check('presence olmadan asıl hareket yazılamaz',false,student.token,standalone);
  const leave={userId:student.uid,from:new Date(),until:new Date(Date.now()+86400000),reason:'Aile izni',revoked:false,actor:admin.uid};
  await check('öğrenci kendi iznini onaylayamaz',false,student.token,[write(`${root}/leaves/a`,leave,['createdAt','updatedAt'])]);
  await check('yönetici izin tanımlar',true,admin.token,[write(`${root}/leaves/a`,leave,['createdAt','updatedAt'])]);
  const read=await fetch(`${base}/${root}/leaves/a`,{headers:{Authorization:`Bearer ${outsider.token}`}});assert.equal(read.status,403);passed++;console.log('PASS başka yurt izinleri okuyamaz');
  await seed(root,{status:'closed',subscription:{expiresAt:new Date(Date.now()+86400000)}});
  await seed(`${root}/presence/${student.uid}`,{userId:student.uid,inside:false,at:new Date(Date.now()-120000),eventId:'old',revision:2});
  await check('kapalı yurt yazma kabul etmez',false,student.token,movement(student,'in','in',3));
  console.log(`${passed} emulator güvenlik kontrolü geçti.`);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
