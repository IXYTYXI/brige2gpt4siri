import { createPlanner } from './planner.js';
import { createServer } from './server.js';
const server = createServer({
  token: process.env.BRIDGE_TOKEN,
  planner: createPlanner({ apiKey: process.env.OPENAI_API_KEY, model: process.env.OPENAI_MODEL }),
});
const port = Number(process.env.PORT ?? 8787);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT must be 1–65535.');
server.listen(port, process.env.HOST ?? '127.0.0.1', () => console.log(`Bridge listening on port ${port}`));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)));
