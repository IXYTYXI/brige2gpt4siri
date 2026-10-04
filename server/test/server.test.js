import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from '../src/server.js';
const token = 'test-token-'.repeat(5);
const body = { text: '你好', timezone: 'Asia/Shanghai', supports_alarm: true };
const answer = { action: 'reply', app_id: null, title: null, at: null, reply_zh: '你好！' };
async function fixture(t, options = {}) {
  const server = createServer({ token, planner: async () => answer, ...options });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  return (payload = body, headers = {}, path = '/v1/plan') => fetch(`http://127.0.0.1:${server.address().port}${path}`, {
    method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...headers },
    body: typeof payload === 'string' ? payload : JSON.stringify(payload),
  });
}
test('authenticated request returns plan and no-store', async t => {
  const send = await fixture(t); const r = await send();
  assert.equal(r.status, 200); assert.equal(r.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await r.json(), { plan: answer });
});
test('authentication happens before planner and malformed requests are bounded', async t => {
  let calls = 0; const send = await fixture(t, { planner: async () => { calls++; return answer; } });
  assert.equal((await send(body, { Authorization: '' })).status, 401);
  assert.equal((await send('{broken')).status, 400);
  assert.equal((await send('x'.repeat(20000))).status, 413);
  assert.equal((await send(body, { 'Content-Type': 'text/plain' })).status, 415);
  assert.equal((await send(body, {}, '/other')).status, 404);
  assert.equal(calls, 0);
});
test('rate limit resets after its time window', async t => {
  let now = 0; const send = await fixture(t, { clock: () => now, requestsPerMinute: 1 });
  assert.equal((await send()).status, 200);
  assert.equal((await send()).status, 429);
  now = 60001;
  assert.equal((await send()).status, 200);
});
test('concurrency limit is released after completion', async t => {
  let release, entered;
  const started = new Promise(r => { entered = r; });
  const blocked = new Promise(r => { release = r; });
  const send = await fixture(t, { maxConcurrent: 1, planner: async () => { entered(); await blocked; return answer; } });
  const first = send(); await started;
  assert.equal((await send()).status, 429);
  release(); assert.equal((await first).status, 200);
  assert.equal((await send()).status, 200);
});
test('internal error details are never returned', async t => {
  const send = await fixture(t, { planner: async () => { throw new Error('private credential'); } });
  const r = await send(); assert.equal(r.status, 500);
  assert.ok(!(await r.text()).includes('credential'));
});
test('weak bearer tokens are refused at startup', () => assert.throws(() => createServer({ token: 'short', planner: async () => answer })));
