const SmeeClient = require('smee-client');

const source = process.env.SOURCE_URL;
const target = process.env.TARGET_URL;

if (!source || !target) {
  console.error('SOURCE_URL and TARGET_URL environment variables are required');
  process.exit(1);
}

const smee = new SmeeClient({
  source: source,
  target: target,
  logger: console
});

const events = smee.start();

events.close();
