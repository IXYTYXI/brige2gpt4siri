export const appIDs = ['maps', 'music', 'wechat'];
export const actions = ['reply', 'clarify', 'unsupported', 'open_app', 'create_reminder', 'set_alarm'];
export const schema = {
  type: 'object', additionalProperties: false,
  properties: {
    action: { type: 'string', enum: actions },
    app_id: { type: ['string', 'null'], enum: [...appIDs, null] },
    title: { type: ['string', 'null'] },
    at: { type: ['string', 'null'] },
    reply_zh: { type: 'string' },
  },
  required: ['action', 'app_id', 'title', 'at', 'reply_zh'],
};

export class BridgeError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
const badInput = () => new BridgeError(400, 'invalid_request', '请求格式不正确，请重新输入。');
const badPlan = () => new BridgeError(502, 'invalid_plan', '未能可靠理解请求，请换一种说法。');
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const text = (x, max) => typeof x === 'string' && x.trim().length > 0 && x.length <= max;

// Reject normalized impossible dates (e.g. February 30) and require explicit offset.
export function instant(value) {
  if (typeof value !== 'string') return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(Z|([+-])(\d{2}):(\d{2}))$/.exec(value);
  if (!m) return null;
  const [, y, mo, d, h, mi, s, zone, , oh, om] = m;
  const days = new Date(Date.UTC(+y, +mo, 0)).getUTCDate();
  if (+y < 2000 || +mo < 1 || +mo > 12 || +d < 1 || +d > days || +h > 23 || +mi > 59 || +s > 59 ||
      (zone !== 'Z' && (+oh > 14 || +om > 59 || (+oh === 14 && +om !== 0)))) return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

export function validateRequest(body) {
  if (!object(body) || Object.keys(body).some(k => !['text', 'timezone', 'supports_alarm'].includes(k)) ||
      !text(body.text, 2000) || !text(body.timezone, 100) || typeof body.supports_alarm !== 'boolean') throw badInput();
  try { new Intl.DateTimeFormat('en', { timeZone: body.timezone }).format(); } catch { throw badInput(); }
  return { ...body, text: body.text.trim() };
}

export function validatePlan(p, { now = Date.now(), supportsAlarm = true } = {}) {
  if (!object(p) || Object.keys(p).sort().join() !== [...schema.required].sort().join() ||
      !actions.includes(p.action) || !text(p.reply_zh, 1000)) throw badPlan();
  const passive = ['reply', 'clarify', 'unsupported'].includes(p.action);
  if (passive) {
    if (p.app_id !== null || p.title !== null || p.at !== null) throw badPlan();
  } else if (p.action === 'open_app') {
    if (!appIDs.includes(p.app_id) || p.title !== null || p.at !== null) throw badPlan();
  } else {
    if (p.app_id !== null || !text(p.title, 120)) throw badPlan();
    if (p.at !== null) {
      const date = instant(p.at);
      if (date === null || date <= now || date > now + 366 * 86400000) throw badPlan();
    }
    if (p.action === 'set_alarm' && (!supportsAlarm || p.at === null)) throw badPlan();
  }
  return p;
}
