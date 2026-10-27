# Orange Juice AI: real-mesh modeling and public distribution

**Current decision, 2026-10-27:** User chose to build a **separate, simplified Blender-style editor directly in Roblox Studio**, using native `EditableMesh`, rather than depending on Roblox Assistant's models or requiring a Blender server. See [mesh-editor/README.md](../mesh-editor/README.md) for the precise manual modeling tool scope.

## Why the existing builder isn't sufficient

Orange Juice AI v0.8 and v0.9 currently create ordinary `Part` and `WedgePart` instances with size, position and rotation. More reference prompts can improve proportions and style, **but cannot supply genuinely new connected topology, rounded bevels, selectable mesh faces or quality guarantees**. That explains why an auto-generated Parts-only treasure chest may have gaps, overlaps or blocky edges.

**The mesh engine is independent of the AI model.** The standalone editor will establish and test verified geometric operations (selection, transforms, loop cuts, bevels and face cuts). Later, Orange Juice AI can issue validated modeling instructions to the **same geometry engine** using its Prepare → Preview → Apply workflow. Users installing Orange Juice AI will not need a separate manual-editor plugin.

## Implementation decision and progress

- **Standalone Orange Juice Mesh Editor:** initial local prototype in `mesh-editor/OrangeJuiceMeshEditor.lua`. It makes one `MeshPart` from an `EditableMesh`, with a connected six-face cube and temporary vertex handles. Object/Edit Mode, vertex/edge/face selection, local movement, scale and rotation, and a basic local transform undo are being prototyped.
- **Topology operations next:** robust loop cuts, bevels, and knife-style face cutting require custom geometry algorithms and comprehensive undo; they are **not implemented** in v0.1. Color/texture/UV editing is intentionally later.
- **Studio execution needs testing:** Lua syntax checks alone do not establish that selection, transforms, collision refresh, undo, reopening a place, or asset publication work correctly. No claim of Blender-quality output or release readiness.
- **No forced Roblox model AI usage:** `GenerationService` is not required for our modeling pipeline. It can remain an optional future experiment if useful, but the user chose our own mesh editor as the foundation.

## Quality milestones

1. **M0 — Studio feasibility:** confirm `AssetService:CreateEditableMesh` + `CreateMeshPartAsync` produce a visible, editable cube in the Studio plugin context, and verify selection/transform input and output.
2. **M1 — Continuous geometry:** implement loop cut for valid quad loops; bevel selected edges into actual new connected surfaces; implement face cuts with correct intersecting topology. Test real vertices and faces, not intersecting Roblox Parts.
3. **M2 — Editing experience:** add viewport gizmos, multi-selection, snapping and reliable undo/redo. Implement color, material and texture editing later.
4. **M3 — Model benchmark:** create a one-piece beveled chest body and a separately movable lid; verify edge quality, face connectivity, normals, alignment, triangle budget and save/reopen behavior. Also benchmark a lamp and simple original vehicle.
5. **M4 — Orange Juice integration:** add a model-job schema to AI Prepare. Share a geometry engine without requiring a second installed plugin, preview the resulting geometry, seek explicit Apply approval, and keep scripts disabled pending code review.
6. **M5 — Independent publishing:** publish the manual mesh editor as its own optional Creator Store plugin **only after Studio testing**, and Orange Juice AI as a separate end-user plugin. Verify eligibility, permissions, licensing and creator policies before publishing.

Roblox official APIs:
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- https://create.roblox.com/docs/reference/engine/classes/AssetService
- https://create.roblox.com/docs/reference/engine/classes/Plugin

## Zero-setup Orange Juice AI public release

Regular users **must not need Cloudflare Worker setup, access to a Lua source file, an OpenAI key, or another plugin**:

1. Install Orange Juice AI from Roblox Creator Store.
2. Authenticate if an account is required for usage plans.
3. Type their request → Prepare → review → Apply.

The developer maintains the backend and integrates the Lua plugin code into the published Creator Store package. Private beta's shared `CLIENT_TOKEN` **must not** be shipped to all users; it must be replaced with per-user sessions, server-side authorization, rate limits, usage budgets, abuse protections and a privacy policy. A shared backend secret in a Studio plugin is extractable, and **ChatGPT Plus does not include OpenAI API credit**.

Any required account, payment or ID eligibility checks must be managed through authorized adult oversight and official procedures. Never bypass platform age or authorization requirements.

**Rule for this project:** improvement to the geometry engine is the priority over adding more reference text pretending to retrain the model. Preserve all existing Orange Juice AI GUI/script functionality while developing mesh support separately.
