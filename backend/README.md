# Orange Juice AI v0.7 — unified Prepare / Apply (private beta)

The Roblox Studio plugin now has **one natural-language request box**, **Prepare**, a complete **review preview**, and **Apply**.

## What Prepare actually does

- Reads the currently open Roblox Studio game's **Explorer hierarchy locally** on every Prepare (up to about 5,200 objects sampled across the main services).
- If the user has **explicitly opted in** to sharing game structure, sends up to 220 *selected* object paths/classes and limited properties (maximum 11,000 characters) to the Cloudflare Worker. **Never reads or uploads Script.Source.**
- The Worker uses the OpenAI Responses API with a structured JSON schema at POST `/v1/prepare`. It asks for a **complete set of dependent changes**, including models/Parts, GUI elements, and scripts when necessary, even if the user only requested the final behavior.
- If an existing suitable object is visible in the outline, the AI is instructed to reuse its exact path and propose only what is missing. A missing Part/GUI must be created **as part of the same proposal** as any scripts that use it.
- The plugin verifies all paths and supported properties against the **live game**, rejecting collisions and missing parents, then displays every action and the **full code** of proposed scripts.
- **Nothing changes** until the user presses Apply. Apply rechecks for edits since Prepare and uses a Roblox Studio Undo recording; on a failure it attempts to roll back.

## Supported in the first unified version

- **3D:** Folder, Model, Part, WedgePart, SpawnLocation
- **UI:** ScreenGui, Frame, TextLabel, TextButton, TextBox, ImageLabel, UICorner, UIStroke, UIListLayout, UIPadding
- **Interactions and data:** ProximityPrompt, ClickDetector, RemoteEvent, RemoteFunction, IntValue, NumberValue, BoolValue, StringValue
- **Code:** Script, LocalScript, ModuleScript

The AI can propose multiple objects **together in one approval**, for example:
- “Create a door that changes color when touched.” → reuse or create a Door Part, plus a Script inside it.
- “Make a shop UI with a close button.” → ScreenGui, Frame, labels/buttons and LocalScript with click handling.
- “Make a shop purchase button that contacts the server.” → GUI, LocalScript, RemoteEvent and server Script.
- “Add a checkpoint.” → a checkpoint Part and Script, if they do not already exist.

Only approved property names/types are writable; unsupported properties or ClassNames are rejected. **Existing script source is NEVER overwritten.** This version does not support MeshParts, custom uploaded assets, animations, Terrain or destructive edits.

Approved Scripts/LocalScripts start **disabled** for safety. ModuleScripts do not execute until required. The user should inspect generated code and test it in Studio before enabling scripts. Thus Apply stages the functionality; code is not automatically run.

## Setup and upgrades

1. Have an eligible adult manage OpenAI API access, billing, and the Cloudflare account. API charges are separate from ChatGPT Plus.
2. Deploy **the new `backend/worker.mjs`** in your existing Cloudflare Worker. Retain your secure existing `OPENAI_API_KEY` and `CLIENT_TOKEN` secrets. No new keys are needed.
3. Replace your local `%LOCALAPPDATA%\Roblox\Plugins\RobloxAIDeveloper.lua` with the plugin's **v0.7 code**; reload Roblox Studio.
4. In the plugin's **Connection & privacy settings**, enter the same HTTPS Worker URL. Load `CLIENT_TOKEN` into the session token box and press Enter. Token is not stored permanently.
5. If you want the AI to know what's already in the game, explicitly switch **Share game structure with AI: ON**. This permission persists as a plugin setting until switched off.
6. Type one request, press **Prepare**, review the list and any generated Luau, then press **Apply** only if the whole plan is appropriate.
7. Apply cannot publish the game or execute generated code automatically; use Explorer to inspect results and enable scripts deliberately after safe testing.

## Security and limitations

This is a single-operator private beta; the shared CLIENT_TOKEN is **not appropriate for a public plugin**. Never put it or OPENAI_API_KEY in a public Roblox plugin or GitHub repository. Public release requires proper user authentication, server rate limiting, quotas, per-user budgets, privacy disclosures and protections.

Game context is opt-in and limited. Because the snapshot can be truncated and never includes script source, the AI may miss an existing suitable object or propose unsuitable scripts. The plugin checks exact paths and class conflicts, but cannot establish semantic equivalence between differently named models or prove Luau safety. **The AI's code is untrusted.** Never blindly enable it.

## Tests

`node --test backend/worker.test.mjs` runs mocked tests (no API charges).
