import test from 'node:test';
import assert from 'node:assert/strict';
import { instant, validatePlan, validateRequest } from '../src/protocol.js';
const now = Date.parse('2026-10-04T12:00:00Z');
const base = { action: 'create_reminder', app_id: null, title: '买牛奶', at: '2026-10-05T18:00:00-04:00', reply_zh: '准备创建提醒。' };
const check = p => validatePlan(p, { now });
test('valid reminder preserves timezone instant; untimed reminder is permitted', () => {
  assert.equal(check(base), base);
  assert.equal(instant(base.at), Date.parse('2026-10-05T22:00:00Z'));
  assert.equal(check({ ...base, at: null }).at, null);
});
test('unknown actions, arbitrary URLs, extraneous fields and mixed parameters are rejected', () => {
  for (const patch of [{ action: 'send_message' }, { url: 'tel:123' }, { app_id: 'wechat' }, { title: '' }, { title: 'x'.repeat(121) }, { reply_zh: '' }])
    assert.throws(() => check({ ...base, ...patch }));
  assert.throws(() => check({ ...base, action: 'open_app', title: null, at: null, app_id: 'https://evil.test' }));
  assert.equal(check({ ...base, action: 'open_app', title: null, at: null, app_id: 'wechat' }).app_id, 'wechat');
});
test('dates must be real future instants within one year, with explicit offsets', () => {
  for (const at of ['tomorrow', '2026-10-05T08:00:00', '2026-10-03T08:00:00Z', '2027-10-07T08:00:00Z', '2027-02-30T08:00:00Z', '2026-13-05T08:00:00Z', '2026-10-05T25:00:00Z', '2026-10-05T08:00:00+15:00'])
    assert.throws(() => check({ ...base, at }), at);
});
test('alarms require a date and device capability', () => {
  assert.throws(() => check({ ...base, action: 'set_alarm', at: null }));
  assert.throws(() => validatePlan({ ...base, action: 'set_alarm' }, { now, supportsAlarm: false }));
  assert.equal(check({ ...base, action: 'set_alarm' }).action, 'set_alarm');
});
test('passive responses cannot hide action parameters', () => {
  for (const action of ['reply', 'clarify', 'unsupported']) {
    assert.throws(() => check({ ...base, action }));
    assert.equal(check({ ...base, action, title: null, at: null }).action, action);
  }
});
test('request timezone and bounded input are validated', () => {
  const r = { text: ' 明天提醒我 ', timezone: 'America/New_York', supports_alarm: true };
  assert.equal(validateRequest(r).text, '明天提醒我');
  for (const patch of [{ text: '' }, { text: 'x'.repeat(2001) }, { timezone: 'Not/AZone' }, { supports_alarm: 'true' }, { now: '2099-01-01' }])
    assert.throws(() => validateRequest({ ...r, ...patch }));
});
