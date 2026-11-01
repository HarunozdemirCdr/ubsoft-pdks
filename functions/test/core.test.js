'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {validateRelays,commandFor,enqueue}=require('../core');
const now=100000, status={lastSeen:now,sessionId:'a'.repeat(32)};
const cfg={paired:true,enabled:true,deviceId:'board',relays:{8:'exit'}};
const event={schemaVersion:2,type:'out',checkpointId:'exit',at:now};
test('all eight channels support either direction and unused channels stay absent',()=>{
  const points={},relays={};for(let i=1;i<=8;i++){points['p'+i]={kind:i%2?'out':'in',active:true};relays[i]='p'+i;}
  assert.deepEqual(validateRelays(relays,points),relays);
  assert.deepEqual(validateRelays({},points),{});
  assert.throws(()=>validateRelays({9:'p1'},points));assert.throws(()=>validateRelays({1:'p1',8:'p1'},points));
  assert.throws(()=>validateRelays({1:'x'},{x:{kind:'both',active:true}}));
  assert.throws(()=>validateRelays({1:'x'},{x:{kind:'in',active:false}}));
});
test('relay 8 receives exit pulse, channel 1 may also be an exit',()=>{
 assert.equal(commandFor(event,cfg,status,now).relay,8);
 assert.equal(commandFor(event,{...cfg,relays:{1:'exit'}},status,now).relay,1);
 assert.equal(commandFor(event,cfg,status,now).pulseMs,1000);
});
test('old, offline, disabled, demo and unmapped events fail closed',()=>{
 assert.equal(commandFor(event,cfg,status,now+10000).skip,'expired');
 assert.equal(commandFor(event,cfg,null,now).skip,'offline');
 assert.equal(commandFor(event,cfg,{...status,lastSeen:now-21000},now).skip,'offline');
 assert.equal(commandFor(event,{...cfg,enabled:false},status,now).skip,'disabled');
 assert.equal(commandFor({...event,demoSource:'demo'},cfg,status,now).skip,'ineligible');
 assert.equal(commandFor({...event,checkpointId:'other'},cfg,status,now).skip,'unmapped');
});
test('retried dispatch cannot resurrect an acknowledged command',()=>{
 const c=commandFor(event,cfg,status,now);const a=enqueue(null,'event1',c);
 assert.equal(a.commands.event1.sequence,1);delete a.commands.event1;
 assert.equal(enqueue(a,'event1',c),undefined);
 const b=enqueue(a,'event2',c);assert.equal(b.commands.event2.sequence,2);
 const d=enqueue(b,'event3',{...c,relay:1});assert.equal(d.commands.event3.sequence,1);
});
test('server enforces location policy independently of client verdict',()=>{
 const {locationAllowed}=require('../core');const point={latitude:41,longitude:29,radiusMeters:75};
 assert.equal(locationAllowed({verdict:'verified'},point,{}),false);
 assert.equal(locationAllowed({},point,{requireLocation:false}),true);
 assert.equal(locationAllowed({location:{latitude:42,longitude:29,accuracy:999999}},point,{blockOutsideScans:true}),false);
 assert.equal(locationAllowed({location:{latitude:41,longitude:29}},point,{blockOutsideScans:true}),true);
});
test('on-demand sessions remain addressable without periodic heartbeat writes',()=>{
 const old={...status,lastSeen:now-86400000,mode:'on_demand'};
 assert.equal(commandFor(event,cfg,old,now).relay,8);
 assert.equal(commandFor(event,cfg,{...old,sessionId:'invalid'},now).skip,'offline');
 assert.equal(commandFor({...event,at:now-10000},cfg,old,now).skip,'expired');
});
test('manual probe ignores unrelated/stale replies and removes its listener',async()=>{
 const {waitForProbe}=require('../core');const at=Date.now();let listener,removed=0;
 const ref={on:(_,fn)=>{listener=fn;},off:(_,fn)=>{assert.equal(fn,listener);removed++;}};
 const pending=waitForProbe(ref,'requested','session',at,1000);
 listener({val:()=>({requestId:'other',sessionId:'session',lastSeen:at})});
 listener({val:()=>({requestId:'requested',sessionId:'session',lastSeen:at-5000})});
 assert.equal(removed,0);
 listener({val:()=>({requestId:'requested',sessionId:'session',lastSeen:at})});
 assert.equal((await pending.promise).requestId,'requested');assert.equal(removed,1);pending.stop();assert.equal(removed,1);
});
test('manual probe timeout is bounded and stops listening',async()=>{
 const {waitForProbe}=require('../core');let removed=0;
 const ref={on:()=>{},off:()=>{removed++;}};
 const pending=waitForProbe(ref,'request','session',Date.now(),15);
 assert.equal(await pending.promise,null);assert.equal(removed,1);
});
