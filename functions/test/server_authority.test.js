'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluateLocation, evaluateDormPolicy } = require('../core');

test('evaluateLocation detects verified, borderline, outside, and unavailable', () => {
  const point = { latitude: 41.0, longitude: 29.0, radiusMeters: 75 };

  assert.equal(
    evaluateLocation({ location: { latitude: 41.0, longitude: 29.0, accuracy: 10 } }, point).verdict,
    'verified',
  );
  assert.equal(
    evaluateLocation({ location: { latitude: 41.001, longitude: 29.0, accuracy: 80 } }, point).verdict,
    'borderline',
  );
  assert.equal(
    evaluateLocation({ location: { latitude: 41.01, longitude: 29.0, accuracy: 15 } }, point).verdict,
    'outside',
  );
  assert.equal(
    evaluateLocation({}, point).verdict,
    'unavailable',
  );
});

test('evaluateDormPolicy calculates lateMinutes, earlyExit, and active leave on UTC+3', () => {
  const policy = {
    tolerance: 10,
    hours: { enabled: true, earliestExit: 360, latestEntry: 1350, earliestEntry: 420 },
  };
  // 2026-11-21 23:00 TR -> 20:00 UTC (deadline is 22:30 + 10m = 22:40 TR => 20 min late)
  const lateMs = Date.UTC(2026, 10, 21, 20, 0, 0);
  const late = evaluateDormPolicy(lateMs, { entry: true, policy });
  assert.equal(late.lateMinutes, 20);
  assert.equal(late.permitted, false);
  assert.equal(late.cycleDate, '2026-11-21');

  // Permitted by active leave
  const leave = {
    from: Date.UTC(2026, 10, 21, 15, 0, 0),
    until: Date.UTC(2026, 10, 22, 18, 0, 0),
    revoked: false,
  };
  const permitted = evaluateDormPolicy(lateMs, { entry: true, policy, leave });
  assert.equal(permitted.lateMinutes, 0);
  assert.equal(permitted.permitted, true);

  // 2026-11-21 05:30 TR -> 02:30 UTC (before 06:00 earliestExit => earlyExit + previous cycleDate)
  const earlyMs = Date.UTC(2026, 10, 21, 2, 30, 0);
  const early = evaluateDormPolicy(earlyMs, { entry: false, policy });
  assert.equal(early.earlyExit, true);
  assert.equal(early.cycleDate, '2026-11-20');
});
