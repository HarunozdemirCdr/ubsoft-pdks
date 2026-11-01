'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {ref,set,get}=require('firebase/database');
async function main(){
 const env=await initializeTestEnvironment({projectId:'demo-yurt-turnstile',database:{host:'127.0.0.1',port:9100,rules:fs.readFileSync('database.rules.json','utf8')}});
 try{
  await env.withSecurityRulesDisabled(async ctx=>{
   const d=ctx.database();await set(ref(d),{registry:{board:{uid:'device',tenantId:'dorm',enabled:true},other:{uid:'otherDevice',tenantId:'elsewhere',enabled:true}},bindings:{board:{bound:true,tenantId:'dorm'}},turnstiles:{dorm:{board:{control:{commands:{event:{relay:8,sequence:1,sessionId:'a'.repeat(32)}}}}}}});
  });
  const d=env.authenticatedContext('device',{turnstile:true,deviceId:'board'}).database();
  const stranger=env.authenticatedContext('student',{}).database();
  await assertSucceeds(get(ref(d,'bindings/board')));
  await assertFails(get(ref(d,'bindings/other')));
  await assertSucceeds(get(ref(d,'turnstiles/dorm/board/control/commands')));
  await assertFails(get(ref(d,'turnstiles/elsewhere/other/control/commands')));
  await assertFails(get(ref(stranger,'turnstiles/dorm/board/control/commands')));
  await assertFails(set(ref(d,'turnstiles/dorm/board/control/commands/forged'),{trigger:true}));
  await assertSucceeds(set(ref(d,'turnstiles/dorm/board/status'),{sessionId:'a'.repeat(32),lastSeen:Date.now(),firmware:'2.2.0'}));
  await assertFails(set(ref(d,'turnstiles/dorm/board/status'),{sessionId:'a'.repeat(32),lastSeen:Date.now()+60000,firmware:'2.2.0'}));
  const ack={relay:8,sequence:1,sessionId:'a'.repeat(32),status:'pulse_started'};
  await assertFails(set(ref(d,'turnstiles/dorm/board/acks/event'),{...ack,relay:1}));
  await assertFails(set(ref(d,'turnstiles/dorm/board/acks/event'),{...ack,status:'made_up'}));
  await assertSucceeds(set(ref(d,'turnstiles/dorm/board/acks/event'),ack));
  await assertFails(set(ref(d,'turnstiles/dorm/board/acks/missing'),ack));
  await assertFails(set(ref(d,'registry/board/tenantId'),'elsewhere'));
  const probeId='b'.repeat(32);
  const reply={sessionId:'a'.repeat(32),lastSeen:Date.now(),firmware:'2.2.3',mode:'on_demand',requestId:probeId};
  await assertFails(set(ref(d,'turnstiles/dorm/board/status'),reply));
  await env.withSecurityRulesDisabled(ctx=>set(ref(ctx.database(),'turnstiles/dorm/board/control/commands/_probe_'+probeId),{kind:'probe',sessionId:'a'.repeat(32),expiresAt:Date.now()+10000}));
  await assertSucceeds(set(ref(d,'turnstiles/dorm/board/status'),reply));
  await assertFails(set(ref(d,'turnstiles/dorm/board/status'),{...reply,mode:'polling'}));
  await env.withSecurityRulesDisabled(ctx=>set(ref(ctx.database(),'registry/board/enabled'),false));
  await assertFails(get(ref(d,'turnstiles/dorm/board/control/commands')));
  console.log('17 RTDB isolation, acknowledgement and disable checks passed.');
 }finally{await env.cleanup();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
