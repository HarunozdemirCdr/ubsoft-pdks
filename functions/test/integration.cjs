'use strict';
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
if(!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_AUTH_EMULATOR_HOST||!process.env.FIREBASE_DATABASE_EMULATOR_HOST)throw new Error('All emulators required');
const project='demo-yurt-turnstile';
const {initializeApp}=require('firebase-admin/app');const {getAuth}=require('firebase-admin/auth');const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');const {getDatabase}=require('firebase-admin/database');
initializeApp({projectId:project,databaseURL:`https://${project}-default-rtdb.firebaseio.com`});
const db=getFirestore(),rtdb=getDatabase(),auth=getAuth();
const base=`http://127.0.0.1:5001/${project}/europe-west1/`;
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function waitFor(read,check,label){for(let i=0;i<50;i++){const v=await read();if(check(v))return v;await delay(200);}throw new Error('Timed out: '+label);}
async function account(email){const u=await auth.createUser({email,password:'Test-123456'});const r=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email,password:'Test-123456',returnSecureToken:true})});const v=await r.json();assert.ok(v.idToken);return{uid:u.uid,token:v.idToken};}
async function call(name,data,token){const r=await fetch(base+name,{method:'POST',headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify({data})});const v=await r.json();return{ok:r.ok,...v};}
async function main(){
 const admin=await account('admin@test.example'),student=await account('student@test.example');
 const tid='dorm',other='elsewhere';
 for(const id of [tid,other]){
  await db.doc(`tenants/${id}`).set({status:'active',subscription:{expiresAt:Timestamp.fromMillis(Date.now()+86400000)}});
  await db.doc(`tenants/${id}/users/${admin.uid}`).set({role:'admin',status:'active'});
 }
 await db.doc(`tenants/${tid}/users/${student.uid}`).set({role:'staff',status:'active'});
 for(const [id,kind]of[['entry','in'],['exit','out']])await db.doc(`tenants/${tid}/checkpoints/${id}`).set({kind,active:true,code:id});
 const did=crypto.randomBytes(16).toString('hex'),secret=crypto.randomBytes(32).toString('hex');
 const registration={deviceId:did,deviceSecret:secret,hardwareId:'112233445566'};
 let r=await fetch(base+'registerTurnstileDevice',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(registration)});assert.equal(r.status,200,await r.text());
 r=await fetch(base+'registerTurnstileDevice',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({...registration,deviceSecret:'b'.repeat(64)})});assert.equal(r.status,403);
 assert.equal((await call('bindTurnstileDevice',{tenantId:tid,deviceId:did},student.token)).ok,false);
 assert.equal((await call('bindTurnstileDevice',{tenantId:tid,deviceId:did},admin.token)).ok,true);
 assert.equal((await call('bindTurnstileDevice',{tenantId:other,deviceId:did},admin.token)).ok,false);
 assert.equal((await rtdb.ref(`bindings/${did}`).get()).val().tenantId,tid);
 assert.equal((await call('saveTurnstileRelays',{tenantId:tid,relays:{1:'entry',8:'exit'}},admin.token)).ok,true);
 assert.equal((await call('saveTurnstileRelays',{tenantId:tid,relays:{1:'entry',8:'entry'}},admin.token)).ok,false);
 const statusRef=rtdb.ref(`turnstiles/${tid}/${did}/status`);
 await statusRef.set({lastSeen:Date.now(),sessionId:'a'.repeat(32),firmware:'emulator'});
 assert.equal((await call('getTurnstileStatus',{tenantId:tid},admin.token)).result.online,true);
 async function movement(id,type,cp){
  const batch=db.batch();batch.set(db.doc(`tenants/${tid}/presence/${student.uid}`),{eventId:id});
  batch.set(db.doc(`tenants/${tid}/attendance/${id}`),{schemaVersion:2,userId:student.uid,checkpointId:cp,checkpointCode:cp,type,at:FieldValue.serverTimestamp(),voided:false});await batch.commit();
 }
 await movement('event1','in','entry');
 const commandRef=rtdb.ref(`turnstiles/${tid}/${did}/control/commands/event1`);
 const command=await waitFor(async()=> (await commandRef.get()).val(),v=>v?.trigger===true,'entry command');assert.equal(command.relay,1);assert.equal(command.pulseMs,1000);
 await rtdb.ref(`turnstiles/${tid}/${did}/acks/event1`).set({status:'pulse_started',relay:1,sequence:command.sequence,sessionId:command.sessionId});
 await waitFor(async()=> (await db.doc(`tenants/${tid}/attendance/event1`).get()).data(),v=>v?.turnstile?.status==='pulse_started','ack propagation');
 await waitFor(async()=> (await commandRef.get()).val(),v=>v===null,'command cleanup');
 await statusRef.update({lastSeen:Date.now()});await movement('event8','out','exit');
 const eight=await waitFor(async()=> (await rtdb.ref(`turnstiles/${tid}/${did}/control/commands/event8`).get()).val(),v=>v?.trigger===true,'relay8 command');assert.equal(eight.relay,8);
 await statusRef.update({lastSeen:Date.now()-30000});await movement('offline','in','entry');
 await waitFor(async()=> (await db.doc(`tenants/${tid}/attendance/offline`).get()).data(),v=>v?.turnstile?.status==='offline','offline result');
 assert.equal((await rtdb.ref(`turnstiles/${tid}/${did}/control/commands/offline`).get()).exists(),false);
 // A stale startup record cannot be reported online without a fresh reply.
 await statusRef.set({lastSeen:Date.now()-86400000,sessionId:'a'.repeat(32),firmware:'2.2.3',mode:'on_demand'});
 const commandsRef=rtdb.ref(`turnstiles/${tid}/${did}/control/commands`);
 const responder=snap=>{const p=snap.val();if(p?.kind==='probe')statusRef.set({lastSeen:Date.now(),sessionId:p.sessionId,firmware:'2.2.3',mode:'on_demand',requestId:p.requestId});};
 commandsRef.on('child_added',responder);
 const manual=await call('getTurnstileStatus',{tenantId:tid},admin.token);
 commandsRef.off('child_added',responder);
 assert.equal(manual.result.online,true);
 const remaining=(await commandsRef.get()).val()||{};assert.equal(Object.keys(remaining).some(k=>k.startsWith('_probe_')),false);
 const noReply=await call('getTurnstileStatus',{tenantId:tid},admin.token);assert.equal(noReply.result.online,false);
 assert.equal(Object.keys((await commandsRef.get()).val()||{}).some(k=>k.startsWith('_probe_')),false);
 await statusRef.set({lastSeen:Date.now()-86400000,sessionId:'a'.repeat(32),firmware:'2.2.3',mode:'on_demand'});
 await movement('withoutHeartbeat','in','entry');
 const idleCommand=await waitFor(async()=> (await rtdb.ref(`turnstiles/${tid}/${did}/control/commands/withoutHeartbeat`).get()).val(),v=>v?.trigger===true,'dispatch without periodic heartbeat');
 assert.equal(idleCommand.relay,1);
 console.log('PASS registration, secret ownership, permanent binding, admin authorization, mapping, relay1/8 dispatch, acknowledgement cleanup, legacy offline flow, manual probe reply/timeout/cleanup and dispatch without heartbeat.');
}
main().then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1);});
