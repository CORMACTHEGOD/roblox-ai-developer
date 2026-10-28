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


## Developer reference knowledge v1 — automatic, no user upload steps

The `/v1/prepare` Worker now automatically selects a small, **curated developer-maintained design profile** based on the requested feature:

- **UI core:** layered borders and intentionally selective shadows, UICorner/UIStroke, color cohesion, reflected highlights, optional controlled stud patterns, readable text, functional controls.
- **Shop:** big offer cards, bright buy buttons, currency context and working close behavior.
- **Rebirth:** current-versus-next progression, resource requirements, vivid reward bars and actual server checks.
- **Index:** category filters, genuine ownership/progress views.
- **Admin:** visually polished but permission-aware controls with server-side checks.
- **Models:** modular Part-based assembly, deliberate grouping and necessary scripts, based on broad structural patterns in developer-supplied Roblox places.

These summaries were **manually extracted from three provided UI screenshots, three uploaded .rbxl file inventories, and one user-created original Blender lamp FBX**. The underlying images, models and scripts are **not** uploaded into the public repository. See `references/STYLE_SYSTEM_V1.md` and `references/PLACE_FILE_INVENTORY.md` for evidence and limits.

Additional external-file research adds **original stylized accessory**, **organic animal**, and **performance-aware vehicle** modeling guidance. Measured structural facts from `.fbx`/`.obj` uploads are documented in `references/EXTERNAL_3D_REFERENCE_PATTERNS.md`; **raw third-party meshes, materials and animation files are not distributed** because reuse permissions are unverified. The current primitive-only builder does not promise to recreate an imported mesh, rig, car physics, or animation. VFX and further UI analysis remain deferred.

The original Blender lamp reference adds **silhouette-first multi-piece prop modeling** guidance and allows a proposed **PointLight or SpotLight** inside a Part, with bounded Brightness/Range and full approval; no arbitrary imported Blender mesh geometry is reconstructed. See `references/BLENDER_LAMP_REFERENCE.md` for the verified mesh inventory and limitations.

The Studio plugin additionally supports **UIGradient** (ColorSequence/NumberSequence through limited string encodings), stronger text outlines, uncluttered shine panels and Roblox stud surface properties, allowing these visual rules to generate more than plain static white UI. This does **not** automatically inspect new visual files or permanently train the underlying model. Users have no special reference setup; the developer embeds and updates the profiles in Cloudflare.

Newly generated scripts are still inserted **disabled** and must be inspected/approved as before. No third-party copyrighted assets should be copied.

## Public Roblox trend and game-link research (experimental)

The v0.8 research preview extends the **same Prepare/Apply experience**; it does not add extra main actions or give AI permission to make changes automatically.

- Paste up to **four** Roblox experience links under the plugin's collapsed **Connection & privacy settings**, or include `https://www.roblox.com/games/<placeId>/...` in your natural-language request.
- Optional **Research public Roblox Top Trending** toggle queries Roblox's publicly available Top Trending chart on Prepare; it is **OFF by default**.
- The Cloudflare Worker extracts numeric place IDs only. It then calls only fixed, Roblox-owned public endpoints to resolve IDs and retrieve public game metadata: title, description, genre, concurrent players, visits, favorites and update date. The chart lookup uses Roblox's public Explore API, which is not a stable contract and can be unavailable.
- The game-research summaries are included as **untrusted data** in the planning request to OpenAI. The AI is instructed to identify patterns actually supported by those sources and use them for *original* designs rather than copying someone's work.
- The full review preview includes the researched game titles, public links, available popularity numbers, and a reminder that public metadata **does not expose in-game UIs, scripts or model internals**.
- If public data or charts are unavailable, research quietly degrades and the normal Prepare flow remains usable. Do **not** treat failed/empty chart requests as confirmation of what is trending.
- No Roblox cookies, private account tokens or arbitrary URL requests are needed. Links are never fetched directly; only fixed Roblox public API origins can be called by the research code.
- Trend research can add network latency and a small amount of OpenAI input-token usage when available. OpenAI API billing is separate from ChatGPT Plus.

**Limitations:** This does **not** yet analyze actual gameplay screenshots or user-uploaded `.rbxm`/`.rbxmx` models. Those require a separate, consented media/file pipeline. Game icons and descriptions are not proof of internal code or UI appearance. The pattern-research feature is a working first step toward a reusable visual/model reference library, not actual model fine-tuning.

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
