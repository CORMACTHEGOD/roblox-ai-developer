# Roblox AI Developer — private-beta AI backend

This Cloudflare Worker lets Roblox Studio send prompts to OpenAI's Responses API and receive **text-only suggestions**. AI answers **do not modify your game**.

## IMPORTANT: private testing only

This prototype uses a **single private client token**, not public accounts. **Do not release this backend publicly or distribute its token.** Other users would otherwise be able to spend the backend owner's API budget. Real public launch requires identity-based sign-in, quotas, abuse protection, monitoring, spending limits, and age-appropriate privacy and safety controls.

## Connect when an eligible adult can manage account setup and billing

1. The account operator creates an OpenAI API project/key and a Cloudflare Worker, under each provider's terms. ChatGPT Plus **does not** include API credits.
2. In the Cloudflare Workers & Pages dashboard, create a new Worker; paste `backend/worker.mjs` into the Worker editor, and deploy.
3. In the Worker's **Settings → Variables and Secrets**, add two variables using the **Secret** type:
   - `OPENAI_API_KEY` — the operator's paid OpenAI API key.
   - `CLIENT_TOKEN` — a **different** long random private test token, used only to authenticate this private beta plugin.
4. Visit `https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev/health` in a browser; it should return JSON with `status: "ok"`. This test does not prove the AI credentials are working.
5. In the plugin enter the full HTTPS Worker URL, and paste the private test token into the Session Token field, then press Enter. The plugin clears the token field after loading it into memory for this Studio session. Don't share this token or enter an OpenAI API key in the plugin.
6. Type your request in the existing prompt textbox and click **Ask AI (Suggestion Only)**. A Roblox Studio permission dialog may ask to allow the plugin to contact your Worker.
7. **Share Game Outline** is OFF by default. If enabled, the plugin sends a limited list of object names and classes. No script source is collected or transmitted.

If the AI returns an answer, the plugin displays it in a scrollable panel but cannot apply it. The existing manually approved **Create folder...** command still works independently. The exact Worker URL and secret values are **not present in this repo**.

## Supported models

The bridge currently accepts `gpt-6-luna`, `gpt-6.1-sol`, and `gpt-6-astra`. All require OpenAI API billing and are subject to account access, model limits, and costs.

Gemini has deliberately not been enabled: its March 2026 terms require API users to be 18+ and restrict API clients likely to be accessed by under-18 users, making it unsuitable for our planned broadly available Roblox developer plugin.

## Testing

Run `node --test backend/worker.test.mjs` in the project root (Node.js 20+). All tests use mocked AI responses and cost nothing. A real AI response cannot be tested until the operator configures and deploys the Worker.

## Before public launch

Replace the shared token with per-user authentication and backend authorization; add per-user request quotas, rate limiting, billing controls, audit logs (without sensitive prompts), content safeguards appropriate for young users, privacy/consent notices, and abuse reporting. The model must never apply Studio changes on its own.
