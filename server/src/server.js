import http from 'node:http';
import { createHash, timingSafeEqual } from 'node:crypto';
import { BridgeError, validateRequest } from './protocol.js';

const hash = value => createHash('sha256').update(value).digest();
export function createServer({ token, planner, clock = Date.now, requestsPerMinute = 30, maxConcurrent = 3 }) {
  if (typeof token !== 'string' || token.length < 32) throw new Error('BRIDGE_TOKEN must contain at least 32 characters.');
  const expected = hash(`Bearer ${token}`);
  let windowStart = clock(), count = 0, active = 0;
  const server = http.createServer(async (req, res) => {
    function send(status, body) {
      if (res.destroyed) return;
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      res.end(JSON.stringify(body));
    }
    let acquired = false;
    try {
      if (req.method === 'GET' && req.url === '/health') return send(200, { status: 'ok' });
      if (!timingSafeEqual(expected, hash(req.headers.authorization ?? ''))) throw new BridgeError(401, 'unauthorized', '服务令牌无效，请检查设置。');
      if (req.method !== 'POST' || req.url !== '/v1/plan') throw new BridgeError(404, 'not_found', '接口不存在。');
      if (!/^application\/json(?:\s*;|$)/i.test(req.headers['content-type'] ?? '')) throw new BridgeError(415, 'content_type', '需要JSON请求。');
      if (clock() - windowStart >= 60000) { windowStart = clock(); count = 0; }
      if (++count > requestsPerMinute || active >= maxConcurrent) throw new BridgeError(429, 'rate_limited', '请求太频繁，请稍后重试。');
      active++; acquired = true;
      const chunks = [];
      let length = 0;
      // Data listeners let us reject oversized bodies without destroying the socket before the 413 response.
      const body = await new Promise((resolve, reject) => {
        req.on('data', chunk => {
          length += chunk.length;
          if (length > 16384) reject(new BridgeError(413, 'body_too_large', '请求太长。'));
          else chunks.push(chunk);
        });
        req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
        req.on('error', reject);
        req.on('aborted', () => reject(new BridgeError(400, 'aborted', '请求已取消。')));
      });
      let parsed;
      try { parsed = JSON.parse(body); } catch { throw new BridgeError(400, 'invalid_json', '请求不是有效JSON。'); }
      const request = validateRequest(parsed);
      send(200, { plan: await planner(request) });
    } catch (error) {
      const known = error instanceof BridgeError;
      send(known ? error.status : 500, { error: { code: known ? error.code : 'internal_error', message: known ? error.message : '服务暂时不可用。' } });
    } finally { if (acquired) active--; }
  });
  server.requestTimeout = 30000;
  server.headersTimeout = 10000;
  server.timeout = 35000;
  return server;
}
