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
