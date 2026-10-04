import test from 'node:test';
import assert from 'node:assert/strict';
import { createPlanner } from '../src/planner.js';
const request = { text: '打开微信', timezone: 'Asia/Shanghai', supports_alarm: true };
const plan = { action: 'open_app', app_id: 'wechat', title: null, at: null, reply_zh: '准备打开微信。' };
const response = output => new Response(JSON.stringify({ status: 'completed', output: [{ type: 'message', content: [{ type: 'output_text', text: JSON.stringify(output) }] }] }));
const make = fetchImpl => createPlanner({ apiKey: 'test-only-key', model: 'test-model', fetchImpl });
test('Responses request uses strict schema, no storage, explicit timezone and no client clock', async () => {
  const planner = make(async (url, opts) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(opts.redirect, 'error');
    const body = JSON.parse(opts.body);
    assert.equal(body.store, false);
    assert.equal(body.text.format.strict, true);
    assert.equal(body.text.format.schema.additionalProperties, false);
    assert.equal(JSON.parse(body.input).timezone, 'Asia/Shanghai');
    assert.ok(JSON.parse(body.input).now);
    return response(plan);
  });
  assert.deepEqual(await planner(request), plan);
});
test('refusal becomes a non-executable Chinese response', async () => {
  const planner = make(async () => new Response(JSON.stringify({ status: 'completed', output: [{ type: 'message', content: [{ type: 'refusal', refusal: 'No' }] }] })));
  assert.equal((await planner(request)).action, 'unsupported');
});
test('upstream errors do not expose secrets or raw bodies', async () => {
  const planner = make(async () => new Response('secret account data', { status: 401 }));
  await assert.rejects(planner(request), e => e.code === 'upstream_error' && !e.message.includes('secret'));
});
test('network failures and truncated, invalid or forbidden outputs fail closed', async () => {
  const responses = [
    async () => { throw new Error('network'); },
    async () => new Response('{bad json'),
    async () => new Response(JSON.stringify({ status: 'incomplete', output: [] })),
    async () => response({ ...plan, action: 'send_message' }),
    async () => response({ ...plan, app_id: 'shortcuts://run-shortcut' }),
  ];
  for (const fetchImpl of responses) await assert.rejects(make(fetchImpl)(request));
});
