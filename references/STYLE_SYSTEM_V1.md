# Orange Juice AI — curated design reference system, v1

## Purpose
Developer-maintained reference profile for **original**, production-oriented Roblox Studio builds. This is retrieval/prompt-guidance knowledge, **not a newly trained or fine-tuned model**. End users need only enter their requests and approve proposals. Reference inputs were user-provided UI screenshots and Roblox .rbxl place files; the raw files and other people's scripts/assets must **not** be republished in this public repository.

## Evidence: three UI screenshots (visual inspection)
1. **Blue ribbon Shop**: sky-blue ribbon title bar with layered stripe accents; large rounded white main panel outlined in darker cyan; tall orange and pink featured offers; bright lime-green purchase buttons; outlined type; diagonal/translucent light streaks; blue vertical navigation blocks on left.
2. **Red/purple Shop**: saturated red title bar with embossed/stud-style repeating background and raised close tile; featured purple mystery-item panel with illustrated rewards and rarity callouts; thick colored borders; compact orange/blue/green product cards; colored buy buttons; glossy highlight shapes.
3. **Black/purple Rebirth**: purple stud-textured title bar, dark textured backdrop, two-column before/after progression sections; bright green/yellow/red gain-and-cost bars; conspicuous blue progress meter and colored bottom action buttons; black separators and contrasting borders.

## Derived original style tokens
- **Structure**: consistent content grid; prominent title strip; clear top-right exit; spacing aligned to a visual rhythm; intentionally weighted primary CTA.
- **Stroke and depth**: coherent 2-layer depth effect (dark outer frame, lighter inner edge). Depth/shadow should concentrate on title bar, interactive cards, and primary buttons. Avoid random strokes on every little element.
- **Shine**: subtle translucent diagonal highlights or inner-top-edge bars, only on focal cards/buttons.
- **Studs**: optional repeating stud-grid treatment for headers or background, not on every layer; ensure readability.
- **Typography**: bold high-contrast headers; readable compact labels; outlined or shadowed numerals where needed.
- **Palette**: strong complementary accent colors over a deep navy/purple or contrasting clean panel; neon green/yellow buttons, with sufficient text contrast. Pure-white unstyled frames are discouraged.
- **Roblox implementation**: appropriate ScreenGui, frames, nested labels and buttons, UICorner, UIStroke, UIGradient where supported, appropriately sized padding/layout controls, dedicated LocalScript for actual interactions. A static Buy button is **not** a working shop.
- **Originality**: extract broad design principles only. Do not replicate full interface composition, particular game logos, proprietary textures/illustrations, or exact screenshots. Any necessary images should be custom or licensed.

## UI-type guidance
| Type | Expected structure | Functional checks |
|---|---|---|
| Shop | Title + exit, currencies, featured items, product cards, readable prices and buy buttons | Close works; buy buttons have honest supported purchase behavior (no invented purchases or balances) |
| Rebirth | Current/next reward comparison, resource requirements, progress meter, rebirth and skip buttons | Buttons check real server-side requirements and do not promise free rewards |
| Index | Filter/categories, rarity/completion collection grid, progress summary | Entries reflect actual available game data; navigation works |
| Admin panel | Permission-aware commands organized by tabs/cards, logs or confirmations for risky actions | Server enforces authorization; no client-only "admin" trust |
| Inventory | Equipped/owned state, categories, item cards, equip actions | Owned/equipped state validated server-side |
| Settings | Grouped toggles/sliders, high-contrast active states | Controls actually change stored or local settings |

## Original 3D patterns extracted at a high level
- **Low-Poly-Stud-Forest.rbxl** contains thousands of Parts and Welds: a representative dense assembled-part environment. It supports studying systematic repetition, grouping and assembly, *not* a blanket claim that every part is expertly optimized.
- **1-School-Treasure-Collect-Coins.rbxl** contains large numbers of building Parts, BlockMeshes, CylinderMeshes, scripts, sounds and some GUI objects: a representative multi-system place. We have **not** verified every script's quality, safety or gameplay behavior.
- **Goku-Character-Model-Free.rbxl** contains Attachments, ParticleEmitters, Beams, MeshParts and joint types: a character/VFX structure example, *not* a license to reproduce an identifiable character or copied mesh.
- Blender-designed future props can supplement these patterns when authors supply originals and export Roblox-compatible meshes. The current Orange Juice plugin can create primitive Part-based models but **cannot** synthesize arbitrary mesh geometry from this library.

## Apply/approval requirements
1. **Prepare** checks the open Explorer tree locally (within sampling limits) and builds an exact plan of missing objects and scripts.
2. Preview shows every new/updated path, property, and full generated source. User chooses Apply.
3. New scripts remain disabled until manually reviewed and enabled.
4. Never claim the references prove current Roblox popularity or expose private code. Roblox public links are metadata signals, not screenshots of actual gameplay.

## Next upgrade (not yet implemented)
With appropriate consent and storage controls, add developer-managed visual understanding of uploaded PNG/JPEG screenshots and permitted Roblox model files, keep a source-aware artifact index and allow designers to update style traits without editing the Worker source. Current version instead uses **curated extracted patterns in the Worker**.
