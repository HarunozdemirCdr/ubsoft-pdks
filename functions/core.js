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
function validCoords(lat, lon) {
  return Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180 && !(lat === 0 && lon === 0);
}
function distanceMeters(point, location) {
  if (!point || !location || !validCoords(point.latitude, point.longitude) || !validCoords(location.latitude, location.longitude)) return null;
  const rad = x => x * Math.PI / 180;
  const a = Math.sin(rad(location.latitude - point.latitude) / 2) ** 2 + Math.cos(rad(point.latitude)) * Math.cos(rad(location.latitude)) * Math.sin(rad(location.longitude - point.longitude) / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
}
function evaluateLocation(event, point) {
  const radius = Number(point?.radiusMeters || 75);
  const dist = distanceMeters(point, event?.location);
  if (dist == null) return { verdict: 'unavailable', distanceMeters: null, radiusMeters: radius };
  if (dist <= radius) return { verdict: 'verified', distanceMeters: dist, radiusMeters: radius };
  const accuracy = Math.min(Math.max(Number(event?.location?.accuracy) || 0, 0), 150);
  return { verdict: dist <= radius + accuracy ? 'borderline' : 'outside', distanceMeters: dist, radiusMeters: radius };
}
function locationAllowed(event, point, settings = {}) {
  if (!validCoords(point.latitude, point.longitude)) return true;
  const loc = evaluateLocation(event, point);
  if (loc.verdict === 'unavailable') return settings.requireLocation === false;
  if (settings.blockOutsideScans !== true) return true;
  return loc.verdict !== 'outside';
}
function _toMs(value) {
  if (value == null) return null;
  if (typeof value === 'number') return value;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}
function _dayHours(policy = {}, dateKey, weekday) {
  const base = policy.hours || { earliestExit: 360, latestEntry: 1350, earliestEntry: null, enabled: true };
  return policy.exceptions?.[dateKey] || policy.weekdays?.[String(weekday)] || base;
}
function _trParts(ms) {
  const d = new Date(ms + 3 * 3600000);
  const y = d.getUTCFullYear();
  const m = d.getUTCMonth() + 1;
  const day = d.getUTCDate();
  const key = `${y}-${String(m).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const weekday = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  const minute = d.getUTCHours() * 60 + d.getUTCMinutes();
  return { y, m, day, key, weekday, minute };
}
function evaluateDormPolicy(atMs, { entry, policy = {}, leave = null, departedAtMs = null } = {}) {
  const tr = _trParts(atMs);
  const dayHours = _dayHours(policy, tr.key, tr.weekday);
  const earliestExitDay = Number(dayHours.earliestExit ?? 360);
  let cy = tr.y, cm = tr.m, cd = tr.day;
  if (tr.minute < earliestExitDay) {
    const prev = new Date(Date.UTC(tr.y, tr.m - 1, tr.day) - 86400000);
    cy = prev.getUTCFullYear();
    cm = prev.getUTCMonth() + 1;
    cd = prev.getUTCDate();
  }
  const cycleKey = `${cy}-${String(cm).padStart(2, '0')}-${String(cd).padStart(2, '0')}`;
  const cycleWd = new Date(Date.UTC(cy, cm - 1, cd)).getUTCDay() || 7;
  const ch = _dayHours(policy, cycleKey, cycleWd);
  const cExit = Number(ch.earliestExit ?? 360);
  const cLatest = Number(ch.latestEntry ?? 1350);
  const deadlineMinutes = (cLatest < cExit ? cLatest + 1440 : cLatest) + Number(policy.tolerance || 0);
  const deadlineMs = Date.UTC(cy, cm - 1, cd, 0, deadlineMinutes - 180, 0);

  const lFrom = leave && !leave.revoked ? _toMs(leave.from) : null;
  const lUntil = leave && !leave.revoked ? _toMs(leave.until) : null;
  const permitted = lFrom != null && lUntil != null && atMs >= lFrom && atMs <= lUntil;

  let lateMinutes = entry && ch.enabled !== false && !permitted && atMs > deadlineMs
    ? Math.floor((atMs - deadlineMs) / 60000)
    : 0;
  if (entry && !permitted && lUntil != null && departedAtMs != null && lUntil >= departedAtMs && atMs > lUntil) {
    lateMinutes = Math.floor((atMs - lUntil) / 60000);
  }
  const earlyExit = !entry && !permitted && dayHours.enabled !== false && tr.minute < earliestExitDay;
  const earlyEntry = entry && !permitted && dayHours.enabled !== false && dayHours.earliestEntry != null && tr.minute < Number(dayHours.earliestEntry);
  return { lateMinutes, earlyExit, earlyEntry, permitted, cycleDate: cycleKey };
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
module.exports = {PULSE_MS, COMMAND_TTL_MS, hash, validId, validateRelays, evaluateLocation, evaluateDormPolicy, locationAllowed, commandFor, waitForProbe, enqueue};
