# Orange Juice AI: real 3D modeling engine and one-click public plugin

**Status:** Architecture decision / next engineering milestone, NOT an implemented feature.
**Reason:** v0.8/v0.9 currently construct 3D objects by planning `Model`, `Part`, `WedgePart`, and selected properties via `Instance.new`. The class allowlist has no `MeshPart` or `EditableMesh` creation pipeline. Reference prompting alone cannot implement mesh topology, bevels, welds, genuine curved surfaces or guarantee seam-free geometry. Reports of gaps, overlapping pieces and blocky treasure chests are consistent with that technical constraint.

## Decision

1. **Do not build an independent Blender clone yet.** First test Roblox's native real-mesh facilities from *Studio plugin context* against actual eligibility/permissions and creator quotas. Current Roblox docs describe `GenerationService:GenerateModelAsync` for original multipart meshes and `AssetService:CreateEditableMesh` plus `EditableMesh:AddVertex/AddTriangle/SetPosition` for procedural geometry.
2. **Give Orange Juice AI a selectable modeling backend internally**, not an extra user-facing setting:
   - `parts` for simple block-styled level geometry.
   - `generated_mesh` for props if `GenerationService:GenerateModelAsync` can be invoked legally and reliably from plugin Studio edit context. Optional `SchemaDefinition.Groups` should name components like chest body/lid/metal trim instead of producing independent floating Parts.
   - `procedural_mesh` if needed: create owned `EditableMesh` geometry from validated parametric recipes such as beveled box, lathed lamp, arch, cylinder, rounded chest, and mesh surfaces, then display in a MeshPart through AssetService. Start with a simple beveled box, then lid/hinge alignment.
   - `imported_mesh` later for originals or permissioned models. Never invent asset IDs or scrape proprietary game meshes.
3. **Retain Prepare → full preview → Apply**. A costly mesh generation may require a staged preview operation with an explicit approval/confirm for cloud generations. All emitted outputs go into a temporary preview container before Apply; cleanup on Cancel. No unreviewed source code execution or destructive overwrites.
4. **Build quality checks**: verify model bounds/centering; part and triangle budgets; valid topology and normals; collisions, seams and unwanted overlap; continuity of named attachment points; expected hierarchy; scripts referencing actual generated objects. Use viewport screenshots and manual inspections to evaluate visuals rather than concluding quality from a JSON plan alone.
5. **Only after real-mesh paths are tested**, decide whether a separate `Orange Juice Mesh Editor` plugin is justified. A full Blender-like edge/face editor (selection, extrusion, bevel, edge loops, knife, UV mapping, undo, gizmos) is a substantial *separate engineering project*. Roblox EditableMesh exposes low-level geometry APIs, **not** premade Blender editing tools; operations must be implemented and tested, and editing existing meshes is subject to ownership/permissions.

## Evidence and caveats

Roblox official docs (verify at development time):
- https://create.roblox.com/docs/reference/engine/classes/GenerationService/GenerateModelAsync
- https://create.roblox.com/docs/parts/model-generation
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- https://create.roblox.com/docs/reference/engine/classes/AssetService

Roblox APIs can fail due to availability, rate limits, account permissions, content moderation, performance or assets lacking edit permission. **Studio-plugin access, asset persistence, creator eligibility, generated-mesh cost/quotas and publishing must be tested** before any release claim. High-fidelity generation cannot be guaranteed for every model.

## Test milestones

### M1 — real-mesh feasibility spike (priority next)
Create a minimal, **private development test plugin**, not a Creator Store publication.
- Probe `GenerationService:GenerateModelAsync` inside Studio plugin edit context using `pcall`. Request a small original decorative treasure chest with named `body`, `lid`, `trim` group schema and bounded triangle count. Make **no live user game change without approval**.
- Test permissions, output type and hierarchy, generated materials/texture quality, bounding box, preview placement and Studio save/reopen persistence, and any required workflow/quotas.
- If unavailable, test a locally constructed bevelled chest via `EditableMesh` from a bounded geometry recipe, then convert to MeshPart and validate save/reopen.
- Keep any paid or quota-consuming test to the developer's approved budget; use no model-generation network calls in mock tests.

### M2 — integrate modeling with Orange Juice Prepare
- Extend structured plan schema to describe a **model job** (engine, prompt, dimensions, subcomponent names, limits), not just `Instance.new` action lists.
- Preview and verify real geometry before Apply. Support retries/edits of the model independently of GUI and script steps while preserving transaction safety.
- AI should automatically select geometry vs Parts based on the request, with graceful fallback and clear explanation if no real-mesh engine is permitted.

### M3 — model quality benchmark
Run the same three requests on legacy Parts and the improved engine: (1) treasure chest with hinged-looking lid and beveled edges, (2) lamp with a continuous silhouette, (3) low-poly stylized vehicle.
Review: recognizable silhouette, seam count, overlaps/gaps, bevel quality, assembly alignment, triangle budget, consistency, time to generate, and successful saving in Studio. Keep screenshots and pass/fail notes.

### M4 — optional separate mesh editor (ONLY if truly needed)
If M2/M3 remain unsatisfactory and a dedicated manual or AI-controlled topology editor materially fixes them, extract a shared modeling core with a second user-facing mesh-editor plugin. Start with vertex/edge/face selection and translate, then extrude and bevel; edge loops and knife cuts follow after topology operations and undo are reliable. Publishing a second plugin is a later decision, not a prerequisite for finishing Orange Juice AI.

## Public user experience — no Cloudflare setup or Lua editing

- Publish **Orange Juice AI as a normal Roblox Studio plugin on Creator Store**. The installed plugin contains its executable Luau internally; users never open or paste the `.lua` file.
- Build the developer's hosted backend (Cloudflare Worker or another operator-owned service) into plugin configuration **at build time**. End users never see or supply a Worker URL, `CLIENT_TOKEN`, or `OPENAI_API_KEY`.
- Replace the private-beta shared CLIENT_TOKEN with approved **per-user session authentication**, server-side authorization, rate limiting, API spend caps and model quotas. Never embed a shared server secret in distributed plugin code; anything embedded in a published plugin can be extracted.
- A user might sign in once or link an account for subscription access; otherwise their flow should be **type request → Prepare → review → Apply**.
- Cloudflare/OpenAI remain managed by the developer/eligible account operator and are **not** bundled as access credentials in the plugin. ChatGPT Plus is separate from OpenAI API billing.
- Confirm creator account age/identity and third-party account/billing requirements through authorized adult management; don't bypass eligibility checks.
- Provide budget controls, opt-in game-context privacy, storage/retention policy, error reporting and simple update/release process.

## Scope and honesty
Reference images and FBX data are valuable for style and structure but **do not change 3D topology capabilities**. This milestone targets the *modeling engine*, not more simulated "training". Working UI and scripts from earlier versions are retained. A proof-of-concept is needed before promising Blender-level quality or fixed launch dates.
