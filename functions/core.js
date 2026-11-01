'use strict';
const crypto = require('node:crypto');
const PULSE_MS = 1000;
const COMMAND_TTL_MS = 10000;
const HEARTBEAT_MAX_AGE_MS = 20000;
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(value);
function validateRelays(relays, points) {
  if (!relays || typeof relays !== 'object' || Array.isArray(relays) || Object.keys(relays).some(k => !/^[1-8]$/.test(k))) throw new Error('Röle numarası 1–8 arasında olmalıdır.');
  const result = {};
  for (const key of ['1','2','3','4','5','6','7','8']) {
    const id = relays[key];
    if (!id) continue;
    if (!validId(id) || !points[id] || !['in','out'].includes(points[id].kind) || points[id].active !== true) throw new Error('Etkin bir giriş veya çıkış QR noktası seçin.');
    if (Object.values(result).includes(id)) throw new Error('Bir QR noktası yalnız bir röleye bağlanabilir.');
    result[key] = id;
  }
  return result;
}
// Re-evaluate the existing location policy on the server; never trust the
// verdict/distance fields written by a browser to decide physical actuation.
function locationAllowed(event,point,settings={}) {
  const valid=(lat,lon)=>Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180&&!(lat===0&&lon===0);
  if(!valid(point.latitude,point.longitude))return true;
  const l=event.location;
  if(!l||!valid(l.latitude,l.longitude))return settings.requireLocation===false;
  if(settings.blockOutsideScans!==true)return true;
  const rad=x=>x*Math.PI/180;
  const a=Math.sin(rad(l.latitude-point.latitude)/2)**2+Math.cos(rad(point.latitude))*Math.cos(rad(l.latitude))*Math.sin(rad(l.longitude-point.longitude)/2)**2;
  const distance=6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(Math.max(0,1-a)));
  return distance<=Number(point.radiusMeters||75)+Math.min(Math.max(Number(l.accuracy)||0,0),150);
}
function commandFor(event, config, status, now) {
  if (!config?.paired || config.enabled !== true || !validId(config.deviceId)) return {skip:'disabled'};
  if (event.voided === true || event.demoSource || event.schemaVersion !== 2) return {skip:'ineligible'};
  const relay = Object.keys(config.relays || {}).find(k => config.relays[k] === event.checkpointId);
  if (!relay || !/^[1-8]$/.test(relay) || !['in','out'].includes(event.type)) return {skip:'unmapped'};
  const at = typeof event.at?.toMillis === 'function' ? event.at.toMillis() : event.at;
  if (!Number.isFinite(at) || at > now + 1000 || now >= at + COMMAND_TTL_MS) return {skip:'expired'};
  if (!status || typeof status.sessionId !== 'string' || !/^[a-f0-9]{32}$/.test(status.sessionId) || !Number.isFinite(status.lastSeen) || status.lastSeen > now + 1000 || (status.mode !== 'on_demand' && now - status.lastSeen > HEARTBEAT_MAX_AGE_MS)) return {skip:'offline'};
  return {relay:Number(relay), trigger:true, pulseMs:PULSE_MS, issuedAt:now, expiresAt:at+COMMAND_TTL_MS, sessionId:status.sessionId};
}
// The listener is installed before a probe is published, avoiding a fast-reply
// race. A timestamp alone is never treated as proof that a board is online.
function waitForProbe(ref, requestId, sessionId, requestedAt, timeoutMs=8000) {
  let finish;
  const promise=new Promise(resolve=>{
    let settled=false,timer;
    const listener=snap=>{
      const d=snap.val();
      if(d?.requestId===requestId && d.sessionId===sessionId && Number.isFinite(d.lastSeen) && d.lastSeen>=requestedAt-1000 && d.lastSeen<=Date.now()+1000)done(d);
    };
    function done(value){if(settled)return;settled=true;clearTimeout(timer);ref.off('value',listener);resolve(value);}
    finish=()=>done(null);
    timer=setTimeout(finish,timeoutMs);
    ref.on('value',listener,error=>done({error}));
  });
  return {promise,stop:()=>finish()};
}
function enqueue(current, eventId, command) {
  current ||= {};
  current.commands ||= {};
  current.sequences ||= {};
  // Function retries can never resurrect an acknowledged command.
  current.issued ||= {};
  if (current.issued[eventId]) return;
  const sequence = Number(current.sequences[command.relay] || 0) + 1;
  if (!Number.isSafeInteger(sequence)) throw new Error('Röle sıra sayacı geçersiz.');
  current.sequences[command.relay] = sequence;
  current.commands[eventId] = {...command, eventId, sequence};
  current.issued[eventId] = command.expiresAt;
  return current;
}
module.exports = {PULSE_MS, COMMAND_TTL_MS, hash, validId, validateRelays, locationAllowed, commandFor, waitForProbe, enqueue};
