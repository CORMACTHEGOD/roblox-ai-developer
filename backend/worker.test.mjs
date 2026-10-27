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

const preparedRequest = (body, authToken = env.CLIENT_TOKEN) => new Request(origin + '/v1/prepare', {
  method: 'POST',
  headers: { 'content-type': 'application/json', authorization: 'Bearer ' + authToken },
  body: JSON.stringify(body)
});

const doorPlan = {
  summary: 'Reuse Door if present, otherwise create it, plus a touch handler',
  steps: [
    { path: 'Workspace/Door', className: 'Part', properties: [
      { name: 'Anchored', value: 'true' },
      { name: 'Size', value: '4,7,1' }
    ], source: '' },
    { path: 'Workspace/Door/TouchHandler', className: 'Script', properties: [],
      source: 'local part = script.Parent\npart.Touched:Connect(function() print("hi") end)' }
  ]
};

test('unified Prepare requires auth, credentials, consented game outline', async () => {
  const base = { prompt: 'Build a working door', model: 'gpt-6-luna', gameOutline: 'Workspace: Door [Part]' };
  assert.equal((await worker.fetch(preparedRequest(base, 'wrong'), env)).status, 401);
  assert.equal((await worker.fetch(preparedRequest(base), {})).status, 503);
  assert.equal((await worker.fetch(preparedRequest({ prompt: base.prompt, model: base.model }), env)).status, 400);
  assert.equal((await worker.fetch(preparedRequest({ ...base, gameOutline: 'x'.repeat(11001) }), env)).status, 400);
});

test('unified Prepare returns coordinated Part and Script plan, but never applies it', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  globalThis.fetch = async (url, opts) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(opts.headers.authorization, 'Bearer ' + env.OPENAI_API_KEY);
    const sent = JSON.parse(opts.body);
    assert.equal(sent.model, 'gpt-6-luna');
    assert.equal(sent.store, false);
    assert.equal(sent.reasoning.effort, 'low');
    assert.equal(sent.text.format.name, 'orange_juice_multi_object_plan');
    assert.ok(sent.input.includes('Workspace: Door [Part]'));
    return new Response(JSON.stringify({output: [{
      type: 'message', content: [{type: 'output_text', text: JSON.stringify(doorPlan)}]
    }]}), {status: 200});
  };
  const r = await worker.fetch(preparedRequest({
    prompt: 'Build a working door', model: 'gpt-6-luna', gameOutline: 'Workspace: Door [Part]'
  }), env);
  assert.equal(r.status, 200);
  const body = await r.json();
  assert.deepEqual(body.plan, doorPlan);
  assert.equal(body.applied, false);
  assert.equal(body.requiresApproval, true);
  assert.ok(!JSON.stringify(body).includes(env.OPENAI_API_KEY));
});

test('unified Prepare rejects duplicate paths, unsupported classes and unsafe format', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  const invalid = [
    { ...doorPlan, steps: [doorPlan.steps[0], doorPlan.steps[0]] },
    { ...doorPlan, steps: [{ ...doorPlan.steps[0], className: 'DataStoreService' }] },
    { ...doorPlan, steps: [{ ...doorPlan.steps[0], path: 'Players/Hacked' }] },
    { ...doorPlan, steps: [{ ...doorPlan.steps[0], source: 'print("invalid")' }] },
    { ...doorPlan, steps: Array.from({ length: 25 }, (_, i) => ({
      ...doorPlan.steps[0], path: 'Workspace/Part' + i
    })) }
  ];
  for (const plan of invalid) {
    globalThis.fetch = async () => new Response(JSON.stringify({output: [
      { type: 'message', content: [{type: 'output_text', text: JSON.stringify(plan)}] }
    ]}), {status: 200});
    const r = await worker.fetch(preparedRequest({
      prompt: 'Build a working door', model: 'gpt-6-luna', gameOutline: 'Workspace'
    }), env);
    assert.equal(r.status, 502);
  }
});

test('unified Prepare supports combined client/server UI and remote dependency steps', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  const combo = {
    summary: 'Create a shop GUI, communication remote, and server handler',
    steps: [
      {path: 'ReplicatedStorage/BuyItem', className: 'RemoteEvent', properties: [], source: ''},
      {path: 'StarterGui/ShopGui', className: 'ScreenGui', properties: [], source: ''},
      {path: 'StarterGui/ShopGui/BuyButton', className: 'TextButton',
        properties: [{name:'Text', value:'Buy'}], source:''},
      {path: 'StarterGui/ShopGui/BuyButton/BuyClient', className: 'LocalScript',
        properties: [], source:'game.ReplicatedStorage:WaitForChild("BuyItem"):FireServer()'},
      {path: 'ServerScriptService/ShopHandler', className: 'Script',
        properties: [], source:'game.ReplicatedStorage:WaitForChild("BuyItem").OnServerEvent:Connect(function(player) print(player.Name) end)'}
    ]
  };
  globalThis.fetch = async () => new Response(JSON.stringify({
    output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(combo)}]}]
  }), {status:200});
  const r=await worker.fetch(preparedRequest({
    prompt:'Create a shop button with working server event',
    model:'gpt-6-luna', gameOutline:'StarterGui: empty; ReplicatedStorage: empty'
  }),env);
  assert.equal(r.status, 200);
  assert.deepEqual((await r.json()).plan.steps, combo.steps);
});

test('Prepare reports upstream timeouts distinctly without leaking credentials', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  globalThis.fetch = async () => {
    const error = new Error('network deadline exceeded');
    error.name = 'TimeoutError';
    throw error;
  };
  const response = await worker.fetch(preparedRequest({
    prompt: 'Make a treasure chest with parts, a lid and a prompt',
    model: 'gpt-6-luna',
    gameOutline: 'Workspace direct children: 0'
  }), env);
  assert.equal(response.status, 504);
  const body = await response.json();
  assert.equal(body.kind, 'upstream_timeout');
  assert.match(body.error, /too long/i);
  assert.ok(!JSON.stringify(body).includes(env.OPENAI_API_KEY));
  assert.ok(!JSON.stringify(body).includes(env.CLIENT_TOKEN));
});

test('Prepare identifies transient upstream connection errors', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  globalThis.fetch = async () => { throw new TypeError('fetch failed'); };
  const response = await worker.fetch(preparedRequest({
    prompt: 'Make a chest', model: 'gpt-6-luna', gameOutline: 'Workspace empty'
  }), env);
  assert.equal(response.status, 502);
  assert.equal((await response.json()).kind, 'upstream_network');
});


test('Roblox game link research resolves public place metadata and sends factual stats to model', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  const visited = [];
  globalThis.fetch = async (url, options) => {
    visited.push(url);
    if (url === 'https://apis.roblox.com/universes/v1/places/8737899170/universe') {
      return new Response(JSON.stringify({universeId: 3317771874}), {status: 200});
    }
    if (url === 'https://games.roblox.com/v1/games?universeIds=3317771874') {
      return new Response(JSON.stringify({data: [{
        id: 3317771874, rootPlaceId: 8737899170, name: 'Public Sample Game',
        description: 'Collect cute pets and explore new areas',
        playing: 50000, visits: 1000000, favoritedCount: 1200,
        genre_l1: 'Simulation', updated: '2026-10-20T00:00:00Z'
      }]}), {status: 200});
    }
    if (url === 'https://api.openai.com/v1/responses') {
      const sent = JSON.parse(options.body);
      assert.ok(sent.input.includes('Public Sample Game'));
      assert.ok(sent.input.includes('current players=50000'));
      assert.ok(sent.input.includes('NOT in-game UI screenshots'));
      assert.ok(sent.instructions.includes('ORIGINAL'));
      return new Response(JSON.stringify({output: [{
        type: 'message', content: [{type: 'output_text',
          text: JSON.stringify({summary:'Make original shop UI',steps:[{
            path:'StarterGui/ShopGui',className:'ScreenGui',properties:[],source:''
          }]})
        }]
      }]}), {status: 200});
    }
    throw new Error('Unexpected network destination: ' + url);
  };
  const r = await worker.fetch(preparedRequest({
    prompt:'Design an original Roblox shop inspired by https://www.roblox.com/games/8737899170/Pet-Simulator-99',
    model:'gpt-6-luna',
    gameOutline:'StarterGui direct children: 0',
    researchTrending:false,
    referenceLinks:[]
  }), env);
  assert.equal(r.status, 200);
  const body = await r.json();
  assert.equal(body.research.games.length, 1);
  assert.equal(body.research.games[0].source, 'user_link');
  assert.equal(body.research.games[0].playing, 50000);
  assert.equal(body.applied, false);
  assert.deepEqual(visited, [
    'https://apis.roblox.com/universes/v1/places/8737899170/universe',
    'https://games.roblox.com/v1/games?universeIds=3317771874',
    'https://api.openai.com/v1/responses'
  ]);
});

test('Roblox Top Trending research optionally samples public chart metadata', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  globalThis.fetch = async (url, opts) => {
    if (url.startsWith('https://apis.roblox.com/explore-api/v1/get-sort-content')) {
      return new Response(JSON.stringify({data: [
        {universeId: 1001}, {universeId: 1002}, {universeId: 1003}
      ]}), {status: 200});
    }
    if (url === 'https://games.roblox.com/v1/games?universeIds=1001,1002,1003') {
      return new Response(JSON.stringify({data: [
        {id:1001,rootPlaceId:10,name:'Sample Game A',genre_l1:'Simulation',playing:120},
        {id:1002,rootPlaceId:11,name:'Sample Game B',genre_l1:'Adventure',playing:100},
        {id:1003,rootPlaceId:12,name:'Sample Game C',genre_l1:'Adventure',playing:80}
      ]}), {status:200});
    }
    if (url === 'https://api.openai.com/v1/responses') {
      assert.ok(JSON.parse(opts.body).input.includes('Sample Game A'));
      return new Response(JSON.stringify({output: [{
        type:'message',content:[{type:'output_text',
          text:JSON.stringify({summary:'Build original menu',steps:[{
            path:'StarterGui/Menu',className:'ScreenGui',properties:[],source:''
          }]})
        }]
      }]}), {status:200});
    }
    throw Error('Unexpected destination ' + url);
  };
  const r=await worker.fetch(preparedRequest({
    prompt:'Build a modern shop interface', model:'gpt-6-luna',
    gameOutline:'StarterGui direct children: 0',researchTrending:true
  }),env);
  assert.equal(r.status,200);
  const result=await r.json();
  assert.equal(result.research.games.length,3);
  assert.equal(result.research.games[0].source,'top_trending_chart');
  assert.equal(result.research.trendingChecked,true);
});

test('Roblox chart outage gracefully falls back to plan without falsely claiming trends', async (t) => {
  const previousFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = previousFetch; });
  globalThis.fetch = async (url) => {
    if (url.startsWith('https://apis.roblox.com/explore-api/')) {
      throw new TypeError('Roblox feed unavailable');
    }
    if (url === 'https://api.openai.com/v1/responses') {
      return new Response(JSON.stringify({output: [{
        type:'message',content:[{type:'output_text',
          text:JSON.stringify({summary:'Proposed',steps:[{
            path:'Workspace/Test',className:'Part',properties:[],source:''
          }]})
        }]
      }]}), {status:200});
    }
    throw Error('Unexpected URL: ' + url);
  };
  const r=await worker.fetch(preparedRequest({
    prompt:'Create a test Part', model:'gpt-6-luna',
    gameOutline:'Workspace direct children: 0',researchTrending:true
  }),env);
  assert.equal(r.status,200);
  const result=await r.json();
  assert.equal(result.research.games.length,0);
  assert.match(result.research.notes.join(' '),/unavailable/i);
});

test('Reference research input is bounded, unauthenticated arbitrary URLs are ignored', async () => {
  assert.equal((await worker.fetch(preparedRequest({
    prompt:'Build shop',model:'gpt-6-luna',gameOutline:'Workspace',referenceLinks:Array(5).fill('https://www.roblox.com/games/1/Title')
  }),env)).status,400);
  assert.equal((await worker.fetch(preparedRequest({
    prompt:'Build shop',model:'gpt-6-luna',gameOutline:'Workspace',researchTrending:'on'
  }),env)).status,400);
});
