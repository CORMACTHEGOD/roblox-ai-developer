# Orange Juice Mesh Editor — standalone Studio plugin

**Decision (2026-10-27):** The goal is **our own simplified Blender-like mesh editor directly in Roblox Studio**. It should NOT run Blender, call Roblox Assistant or use default Parts as the edited geometry. Orange Juice AI can later invoke the same core geometry operations automatically. The editor should eventually be publishable **as its own Creator Store plugin**, without any Cloudflare/OpenAI setup.

## Target tools, in user priority order

| Tool | Expected behavior | Current status |
|---|---|---|
| Object Mode | Select and transform the entire editable mesh object | First local prototype |
| Edit Mode | Modify geometry without moving whole object | First local prototype |
| Vertex Select | Select visible vertex points in 3D and move/rotate/scale them | First local prototype |
| Edge Select | Select a geometric edge, transform its endpoint vertices | First local prototype |
| Face Select | Select a face, transform its corner vertices | First local prototype |
| Move, Scale, Rotate | Keyboard/gizmo-style transforms, numeric controls and snapping | First prototype uses simple buttons; viewport gizmos later |
| Loop Cut | Split a continuous ring of adjacent quads with matching vertices | Topology milestone 2 |
| Bevel | Replace selected edges with chamfer/round strips, adjustable segments | Topology milestone 3 |
| Knife | Cut across the surface with user-selected points; split intersected faces | Topology milestone 4 |
| Colors/materials | Face-level or per-vertex colors and material picker | Later as requested |
| Textures/UV | Apply images, UV map/unwrapping and paint | Later as requested |

## Rendering architecture

1. Keep an `EditableMesh` created with `AssetService:CreateEditableMesh()` as the **source of truth**.
2. Show it in Workspace by `AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))`; **no ordinary Parts are assembled as a fake mesh**.
3. Maintain independent selected IDs (vertex/edge/face) and derive edges from the face-to-vertex topology.
4. Use plugin mouse, camera projection and transient adornments to select geometry; keep selection adornments excluded from saved output.
5. Transform selected vertices through `EditableMesh:SetPosition`. Object Mode uses MeshPart transformations.
6. Topology operations must preserve shared-vertex connectivity and face winding, remove discarded faces, repair normals/UVs, guard against degenerate or non-manifold results, respect triangle/size budgets and support undo.
7. For editing an imported existing MeshPart: request permission and use `CreateEditableMeshAsync(meshPart.MeshContent,{FixedSize=false})` **only for owned or explicitly shared meshes**. Avoid copying third-party asset topology without permission.
8. Save/export is an **explicit future milestone**. Reopening a place and mesh durability must be tested, not assumed. Roblox also exposes AssetService APIs for creating persistent mesh assets, but publishing assets without informed user confirmation is unacceptable.
9. Treat Studio API restrictions/permissions as hard errors; don't claim that a mesh saved or uploaded when it hasn't.

Official docs:
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- https://create.roblox.com/docs/reference/engine/classes/AssetService
- https://create.roblox.com/docs/reference/engine/classes/Plugin

## First benchmark and visual quality acceptance

A **single connected beveled cube** that cannot be confused with six intersecting Parts:
- The same 8 original corner vertices belong to adjacent faces.
- Vertex/edge/face selection highlights the intended topology, not arbitrary Parts.
- Move/rotate/scale selected vertices while other vertices remain unchanged.
- The future bevel must create real new vertices and faces along the edge.
- Close/open the file and verify mesh durability **before promising publishing**.
- Validate in Studio with manual tests; automated Luau syntax alone does not prove the plugin operates.

## User workflow

User installs **Orange Juice Mesh Editor** from Creator Store as a standalone tool once published; edits mesh manually like a small version of Blender. No website, account, API key or cloud model is required for manual editing.

Later **Orange Juice AI**'s backend can prepare a structured topology recipe using this *shared mesh engine*, then its own plugin executes the actions after preview and user approval. Ordinary Orange Juice AI users will not need a second plugin installation. The optional companion editor can be independently published for creators who want manual modeling.

## Scope limits

- Blender-level full topology tools are difficult: initial prototype is only a foundation, not a completed alternative to Blender.
- Existing mesh editing is subject to ownership/permission checks.
- Mesh vertex and geometry limits, collision recalculation, rendering, persistence and publishing have specific Roblox constraints; they must be verified in actual Studio tests.
- No dependency on a hosted server for standalone manual modeling.
