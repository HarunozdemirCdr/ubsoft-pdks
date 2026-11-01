'use strict';
const crypto = require('node:crypto');
const {initializeApp, getApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getDatabaseWithUrl} = require('firebase-admin/database');
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onValueCreated} = require('firebase-functions/v2/database');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {setGlobalOptions} = require('firebase-functions/v2');
const {hash, validId, validateRelays, locationAllowed, commandFor, waitForProbe, enqueue} = require('./core');
initializeApp();
setGlobalOptions({region:'europe-west1', maxInstances:3, memory:'256MiB', timeoutSeconds:30});
const db = getFirestore();
const auth = getAuth();
const emulator = !!process.env.FIREBASE_DATABASE_EMULATOR_HOST;
const databaseURL = emulator
  ? `https://${process.env.GCLOUD_PROJECT || 'demo-yurt-turnstile'}-default-rtdb.firebaseio.com`
  : 'https://ubsoft-pdks-turnstile.europe-west1.firebasedatabase.app';
const rtdb = getDatabaseWithUrl(databaseURL, getApp());
const configRef = tid => db.doc(`tenants/${tid}/turnstileConfig/controller`);
const devicePath = (tid,did) => `turnstiles/${tid}/${did}`;

async function administrator(request) {
  const tid = request.data?.tenantId;
  if (!request.auth || !validId(tid) || tid === '_system') throw new HttpsError('permission-denied','Yurt yöneticisi hesabıyla giriş yapın.');
  const [user, owner, tenant] = await Promise.all([
    db.doc(`tenants/${tid}/users/${request.auth.uid}`).get(),
    db.doc(`tenants/_system/users/${request.auth.uid}`).get(),
    db.doc(`tenants/${tid}`).get(),
  ]);
  const u=user.data(), o=owner.data(), t=tenant.data();
  if (!(u?.role==='admin' && u.status==='active') && !(o?.role==='superAdmin' && o.status==='active')) throw new HttpsError('permission-denied','Bu yurdun turnike ayarlarını yönetemezsiniz.');
  if (!t || t.status!=='active' || !t.subscription?.expiresAt || t.subscription.expiresAt.toMillis() <= Date.now()) throw new HttpsError('failed-precondition','Yurt hesabı kayıt kabul etmiyor.');
  return tid;
}

// Random identity and secret are generated and persisted by the board, never by
// a browser. Registration retries must prove possession of the same secret.
exports.registerTurnstileDevice = onRequest({cors:false,maxInstances:2},async(req,res)=>{
  if(req.method!=='POST'){res.status(405).end();return;}
  const {deviceId,hardwareId,deviceSecret}=req.body||{};
  const mac=typeof hardwareId==='string'?hardwareId.replaceAll(':','').toUpperCase():'';
  if(typeof deviceId!=='string'||typeof deviceSecret!=='string'||!/^[a-f0-9]{32}$/.test(deviceId||'')||!/^[A-F0-9]{12}$/.test(mac)||!/^[a-f0-9]{64}$/.test(deviceSecret||'')){res.status(400).json({error:'Geçersiz cihaz bilgisi.'});return;}
  try{
    const ref=db.doc(`turnstileRegistry/${deviceId}`), hw=db.doc(`turnstileHardware/${hash(mac)}`);
    await db.runTransaction(async tx=>{
      const [rs,hs]=await Promise.all([tx.get(ref),tx.get(hw)]);const r=rs.data(),h=hs.data();
      if((r&&(r.secretHash!==hash(deviceSecret)||r.hardwareHash!==hash(mac)))||(h&&h.deviceId!==deviceId))throw new Error('identity');
      if(!r)tx.create(ref,{secretHash:hash(deviceSecret),hardwareHash:hash(mac),tenantId:null,createdAt:FieldValue.serverTimestamp()});
      if(!h)tx.create(hw,{deviceId});
    });
    const uid=`turnstile_${deviceId}`, email=`${deviceId}@turnstile.invalid`;
    try{await auth.createUser({uid,email,password:deviceSecret,displayName:'Yurt turnike kartı'});}
    catch(e){if(e.code!=='auth/uid-already-exists')throw e;const u=await auth.getUser(uid);if(u.email!==email)throw new Error('identity');}
    await auth.setCustomUserClaims(uid,{turnstile:true,deviceId});
    // Do not downgrade a binding if a registration retry races with the admin.
    await rtdb.ref(`registry/${deviceId}`).transaction(c=>c||{uid,tenantId:'',enabled:false});
    await rtdb.ref(`bindings/${deviceId}`).transaction(c=>c||{bound:false,deviceId});
    res.json({deviceId,deviceEmail:email,databaseURL,relayPins:[26,27,25,32,14,12,13,15]});
  }catch(e){res.status(403).json({error:'Cihaz kaydı doğrulanamadı.'});}
});

exports.bindTurnstileDevice = onCall(async request=>{
  const tid=await administrator(request), did=request.data.deviceId;
  if(typeof did!=='string'||!/^[a-f0-9]{32}$/.test(did||''))throw new HttpsError('invalid-argument','Kartın 32 karakterli kimliğini girin.');
  const ref=configRef(tid),registry=db.doc(`turnstileRegistry/${did}`);
  const config=await db.runTransaction(async tx=>{
    const [rs,cs]=await Promise.all([tx.get(registry),tx.get(ref)]);const r=rs.data(),c=cs.data();
    if(!r)throw new HttpsError('not-found','Kart önce Wi-Fi üzerinden internete bağlanıp kaydolmalıdır.');
    if(r.tenantId&&r.tenantId!==tid)throw new HttpsError('already-exists','Kart başka bir yurda kalıcı olarak atanmış.');
    if(c?.paired&&c.deviceId!==did)throw new HttpsError('already-exists','Bu yurda zaten bir kart atanmış.');
    const next={deviceId:did,paired:true,enabled:c?.enabled??true,relays:c?.relays||{}};
    tx.update(registry,{tenantId:tid});
    tx.set(ref,{...next,updatedAt:FieldValue.serverTimestamp(),updatedBy:request.auth.uid},{merge:true});
    tx.set(db.doc(`tenants/${tid}/turnstileState/controller`),next);
    return next;
  });
  await rtdb.ref().update({[`registry/${did}`]:{uid:`turnstile_${did}`,tenantId:tid,enabled:config.enabled},[`bindings/${did}`]:{bound:true,tenantId:tid,deviceId:did}});
  return {ok:true,deviceId:did};
});

exports.saveTurnstileRelays = onCall(async request=>{
  const tid=await administrator(request);
  const relays=request.data.relays;
  if(!relays||typeof relays!=='object'||Array.isArray(relays)||Object.keys(relays).some(k=>!/^[1-8]$/.test(k)))throw new HttpsError('invalid-argument','Röle numarası 1–8 arasında olmalıdır.');
  const ref=configRef(tid);
  await db.runTransaction(async tx=>{
    const config=(await tx.get(ref)).data();
    if(!config?.paired)throw new HttpsError('failed-precondition','Önce kartı bu yurda bağlayın.');
    const points={};
    for(const id of Object.values(relays || {})) {
      if(!id)continue;if(!validId(id))throw new HttpsError('invalid-argument','QR noktası geçersiz.');
      points[id]=(await tx.get(db.doc(`tenants/${tid}/checkpoints/${id}`))).data();
    }
    let checked;try {checked=validateRelays(relays,points);}catch(error){throw new HttpsError('invalid-argument',error.message);}
    tx.update(ref,{relays:checked,updatedAt:FieldValue.serverTimestamp(),updatedBy:request.auth.uid});
    tx.set(db.doc(`tenants/${tid}/turnstileState/controller`),{deviceId:config.deviceId,paired:true,enabled:config.enabled,relays:checked});
  });
  return {ok:true};
});

exports.getTurnstileStatus = onCall(async request=>{
  const tid=await administrator(request);const c=(await configRef(tid).get()).data();
  if(!c?.paired)return {paired:false,online:false};
  const base=devicePath(tid,c.deviceId),statusRef=rtdb.ref(`${base}/status`);
  const status=(await statusRef.get()).val();
  const result={paired:true,online:false,lastSeen:status?.lastSeen||null,firmware:status?.firmware||'',checkedAt:Date.now()};
  if(c.enabled!==true)return {...result,disabled:true};
  // Compatibility while existing boards are being flashed with 2.2.3.
  if(status?.mode!=='on_demand')return {...result,legacy:true,online:!!status&&status.lastSeen<=Date.now()+1000&&Date.now()-status.lastSeen<20000};
  if(!/^[a-f0-9]{32}$/.test(status.sessionId||''))return result;
  const requestId=crypto.randomBytes(16).toString('hex'),requestedAt=Date.now();
  const probeRef=rtdb.ref(`${base}/control/commands/_probe_${requestId}`);
  const pending=waitForProbe(statusRef,requestId,status.sessionId,requestedAt);
  try{
    await probeRef.set({kind:'probe',requestId,sessionId:status.sessionId,expiresAt:requestedAt+10000});
    const reply=await pending.promise;
    if(reply?.error)throw new HttpsError('unavailable','Kartın yanıtı kontrol edilemedi. Yeniden deneyin.');
    return {...result,online:!!reply,lastSeen:reply?.lastSeen||result.lastSeen,checkedAt:Date.now()};
  }finally{pending.stop();await probeRef.remove();}
});

exports.setTurnstileEnabled = onCall(async request=>{
  const tid=await administrator(request);const enabled=request.data.enabled;
  if(typeof enabled!=='boolean')throw new HttpsError('invalid-argument','Etkinlik seçimi geçersiz.');
  const ref=configRef(tid), c=(await ref.get()).data();
  if(!c?.paired)throw new HttpsError('failed-precondition','Kart henüz bağlı değil.');
  await ref.update({enabled,updatedAt:FieldValue.serverTimestamp()});
  await rtdb.ref(`registry/${c.deviceId}/enabled`).set(enabled);
  await db.doc(`tenants/${tid}/turnstileState/controller`).set({enabled},{merge:true});
  return {ok:true};
});

async function hardwareStatus(eventRef,status,extra={}) {
  await eventRef.set({turnstile:{status,...extra,updatedAt:FieldValue.serverTimestamp()}},{merge:true});
}

exports.dispatchTurnstile = onDocumentCreated({document:'tenants/{tenantId}/attendance/{eventId}',retry:true},async event=>{
  const e=event.data?.data();if(!e)return;
  const {tenantId:tid,eventId}=event.params;
  // Firestore permits characters which RTDB keys do not. Reject malformed
  // source paths before any command write, rather than retrying forever.
  if(!validId(tid)||!validId(eventId)||!validId(e.checkpointId)||typeof e.userId!=='string'||e.userId.includes('/'))return;
  const config=(await configRef(tid).get()).data();
  if(!config?.paired || !Object.values(config.relays||{}).includes(e.checkpointId))return;
  // Never replay an invocation whose earlier acknowledgement was already saved.
  const latest=(await event.data.ref.get()).data();
  if(latest?.turnstile?.status && !['queued'].includes(latest.turnstile.status))return;
  const [tenant,point,presence,user]=await Promise.all([db.doc(`tenants/${tid}`).get(),db.doc(`tenants/${tid}/checkpoints/${e.checkpointId}`).get(),db.doc(`tenants/${tid}/presence/${e.userId}`).get(),db.doc(`tenants/${tid}/users/${e.userId}`).get()]);
  const t=tenant.data(), p=point.data();
  if(t?.status!=='active'||!t.subscription?.expiresAt||t.subscription.expiresAt.toMillis()<=Date.now()||user.data()?.status!=='active'||p?.code!==e.checkpointCode||!p?.active||p.kind!==e.type||presence.data()?.eventId!==eventId||latest?.voided===true){await hardwareStatus(event.data.ref,'rejected');return;}
  if(!locationAllowed(e,p,t.settings)){await hardwareStatus(event.data.ref,'rejected');return;}
  const base=devicePath(tid,config.deviceId);
  const status=(await rtdb.ref(`${base}/status`).get()).val();
  const command=commandFor(e,config,status,Date.now());
  if(command.skip){if(command.skip!=='ineligible')await hardwareStatus(event.data.ref,command.skip);return;}
  // Record queued BEFORE publishing: a very fast acknowledgement cannot be
  // overwritten by a late queued write from this function.
  const ready=await db.runTransaction(async tx=>{
    const current=(await tx.get(event.data.ref)).data();
    if(!current || current.voided || (current.turnstile?.status && current.turnstile.status!=='queued'))return false;
    tx.set(event.data.ref,{turnstile:{status:'queued',deviceId:config.deviceId,relay:command.relay,updatedAt:FieldValue.serverTimestamp()}},{merge:true});return true;
  });
  if(!ready)return;
  await rtdb.ref(`${base}/control`).transaction(current=>enqueue(current,eventId,command));
});

exports.acknowledgeTurnstile = onValueCreated({ref:'/turnstiles/{tenantId}/{deviceId}/acks/{eventId}',instance:emulator?'demo-yurt-turnstile-default-rtdb':'ubsoft-pdks-turnstile',region:emulator?'us-central1':'europe-west1',retry:true},async event=>{
  const {tenantId:tid,deviceId:did,eventId}=event.params;
  const ack=event.data.val();
  const ref=db.doc(`tenants/${tid}/attendance/${eventId}`);
  const existing=(await ref.get()).data();
  if(existing?.turnstile?.deviceId===did) {
    await hardwareStatus(ref,ack.status,{deviceId:did,relay:ack.relay,sequence:ack.sequence});
  }
  const base=devicePath(tid,did);
  // Removal is idempotent; a retried acknowledgement cannot recreate a command.
  await rtdb.ref(base).update({[`control/commands/${eventId}`]:null,[`acks/${eventId}`]:null});
});

exports.expireTurnstileCommands = onSchedule('every 5 minutes',async()=>{
  const configs=await db.collectionGroup('turnstileConfig').get();
  for(const doc of configs.docs){const c=doc.data();if(!c.paired)continue;const tid=doc.ref.parent.parent.id;const ref=rtdb.ref(`${devicePath(tid,c.deviceId)}/control`);const data=(await ref.get()).val();if(!data)continue;const patch={};
    for(const [id,cmd]of Object.entries(data.commands||{})){if(cmd.expiresAt>=Date.now())continue;patch[`commands/${id}`]=null;const er=db.doc(`tenants/${tid}/attendance/${id}`);const e=(await er.get()).data();if(e?.turnstile?.status==='queued')await hardwareStatus(er,'expired',{deviceId:c.deviceId,relay:cmd.relay});}
    for(const [id,expiry]of Object.entries(data.issued||{}))if(expiry<Date.now()-3600000)patch[`issued/${id}`]=null;
    if(Object.keys(patch).length)await ref.update(patch);
  }
});
