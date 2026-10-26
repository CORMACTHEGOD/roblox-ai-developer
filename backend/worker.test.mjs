import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './worker.mjs';

const origin = 'https://example.workers.dev';
const env = { OPENAI_API_KEY: 'test-provider-secret', CLIENT_TOKEN: 'local-private-test-token' };

const jsonRequest = (body, token = env.CLIENT_TOKEN) => new Request(origin + '/v1/plan', {
  method: 'POST',
  headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
  body: JSON.stringify(body)
});

test('health does not reveal secrets', async () => {
  const r = await worker.fetch(new Request(origin + '/health'), env);
  const body = await r.text();
  assert.equal(r.status, 200);
  assert.ok(!body.includes(env.CLIENT_TOKEN));
  assert.ok(!body.includes(env.OPENAI_API_KEY));
});

test('requires authorization and secrets', async () => {
  assert.equal((await worker.fetch(jsonRequest({ prompt: 'hello', model: 'gpt-6-luna' }, 'wrong'), env)).status, 401);
  assert.equal((await worker.fetch(jsonRequest({ prompt: 'hello', model: 'gpt-6-luna' }), {})).status, 503);
});

test('validates prompt, model and outline before upstream', async () => {
  assert.equal((await worker.fetch(jsonRequest({ prompt: '', model: 'gpt-6-luna' }), env)).status, 400);
  assert.equal((await worker.fetch(jsonRequest({ prompt: 'ok', model: 'other' }), env)).status, 400);
  assert.equal((await worker.fetch(jsonRequest({ prompt: 'ok', model: 'gpt-6-luna', gameOutline: 'x'.repeat(6001) }), env)).status, 400);
});

test('bridges to OpenAI securely and only returns a suggestion', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  globalThis.fetch = async (url, opts) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(opts.headers.authorization, `Bearer ${env.OPENAI_API_KEY}`);
    const sent = JSON.parse(opts.body);
    assert.equal(sent.model, 'gpt-6.1-sol');
    assert.equal(sent.store, false);
    assert.ok(sent.input.includes('Workspace: Part [Part]'));
    return new Response(JSON.stringify({ output: [
      { type: 'message', content: [{ type: 'output_text', text: 'Add a Script under ServerScriptService.' }] }
    ] }), { status: 200 });
  };
  const r = await worker.fetch(jsonRequest({
    prompt: 'How do I add a script?', model: 'gpt-6.1-sol', gameOutline: 'Workspace: Part [Part]'
  }), env);
  assert.equal(r.status, 200);
  const body = await r.json();
  assert.equal(body.suggestion, 'Add a Script under ServerScriptService.');
  assert.equal(body.applied, false);
  assert.ok(!JSON.stringify(body).includes(env.OPENAI_API_KEY));
});

test('script proposal endpoint is private and rejects unsupported models', async () => {
  const body = { prompt: 'Create a welcome Script', model: 'gpt-6-luna' };
  const unauthorized = new Request(origin + '/v1/propose-script', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer wrong' },
    body: JSON.stringify(body)
  });
  assert.equal((await worker.fetch(unauthorized, env)).status, 401);
  const bad = new Request(origin + '/v1/propose-script', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer ' + env.CLIENT_TOKEN },
    body: JSON.stringify({ ...body, model: 'unknown' })
  });
  assert.equal((await worker.fetch(bad, env)).status, 400);
});

test('script proposal returns validated code without applying it', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  globalThis.fetch = async (url, options) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    const sent = JSON.parse(options.body);
    assert.equal(sent.text.format.type, 'json_schema');
    assert.equal(sent.text.format.strict, true);
    assert.equal(sent.store, false);
    return new Response(JSON.stringify({
      output: [{ type: 'message', content: [{ type: 'output_text',
        text: JSON.stringify({ name: 'WelcomeScript', code: 'print("Hello, Roblox!")' })
      }] }]
    }), { status: 200 });
  };
  const r = await worker.fetch(new Request(origin + '/v1/propose-script', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer ' + env.CLIENT_TOKEN },
    body: JSON.stringify({ model: 'gpt-6-luna', prompt: 'Create a welcome Script' })
  }), env);
  const body = await r.json();
  assert.equal(r.status, 200);
  assert.equal(body.proposal.name, 'WelcomeScript');
  assert.equal(body.proposal.service, 'ServerScriptService');
  assert.equal(body.proposal.code, 'print("Hello, Roblox!")');
  assert.equal(body.applied, false);
  assert.ok(!JSON.stringify(body).includes(env.OPENAI_API_KEY));
});

test('script proposal rejects malformed or oversized AI outputs', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  for (const raw of [
    '{not-json',
    JSON.stringify({ name: 'Invalid/Name', code: 'print(1)' }),
    JSON.stringify({ name: 'Okay', code: 'x'.repeat(9001) }),
    JSON.stringify({ name: 'Okay', code: '' })
  ]) {
    globalThis.fetch = async () => new Response(JSON.stringify({
      output: [{ type: 'message', content: [{ type: 'output_text', text: raw }] }]
    }), { status: 200 });
    const r = await worker.fetch(new Request(origin + '/v1/propose-script', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: 'Bearer ' + env.CLIENT_TOKEN },
      body: JSON.stringify({ model: 'gpt-6-luna', prompt: 'Create a welcome Script' })
    }), env);
    assert.equal(r.status, 502);
  }
});
