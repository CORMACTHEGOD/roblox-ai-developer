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
| Move, Scale, Rotate | **Native Roblox Studio Move (2), Scale (3), Rotate (4)** | **v0.2 experimental native gizmo bridge** |
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
5. **Native Studio gizmo integration (v0.2 experimental):**
   - Object Mode selects the actual MeshPart; Studio's normal Move, Scale and Rotate tools transform the whole object.
   - Edit Mode enters **Pick Geometry** with plugin mouse, then selects one vertex/edge/face.
   - The plugin temporarily selects an invisible anchored **control pivot Part** (not part of the user's model), and activates the requested **native Studio ribbon tool** via `Plugin:SelectRibbonTool`.
   - Listening to the pivot's `CFrame` and `Size` lets the plugin map native translate/rotation/scale edits to the selected `EditableMesh` vertex IDs with `SetPosition`. All selected faces share mesh vertex IDs, so connected surfaces follow.
   - Click **Pick Geometry** to choose another point/edge/face. A single vertex's scale/rotation about itself has no visible effect; use Move for a single vertex.
   - Temporary pivot is removed on exit from Edit Mode, closing the editor or plugin unload. It is `Archivable = false` and must not be shipped as model geometry.
   - Selection-bridge and edit history may behave differently across Studio dragger versions; live Studio validation remains mandatory.
6. Topology operations must preserve shared-vertex connectivity and face winding, remove discarded faces, repair normals/UVs, guard against degenerate or non-manifold results, respect triangle/size budgets and support undo.
7. For editing an imported existing MeshPart: request permission and use `CreateEditableMeshAsync(meshPart.MeshContent,{FixedSize=false})` **only for owned or explicitly shared meshes**. Avoid copying third-party asset topology without permission.
8. Save/export is an **explicit future milestone**. Reopening a place and mesh durability must be tested, not assumed. Roblox also exposes AssetService APIs for creating persistent mesh assets, but publishing assets without informed user confirmation is unacceptable.
9. Treat Studio API restrictions/permissions as hard errors; don't claim that a mesh saved or uploaded when it hasn't.

Official docs:
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- https://create.roblox.com/docs/reference/engine/classes/AssetService
- https://create.roblox.com/docs/reference/engine/classes/Plugin

## First benchmark and visual quality acceptance

A **single connected cube** (bevel is still a future tool) that cannot be confused with six intersecting Parts:
- The same 8 original corner vertices belong to **12 adjacent triangles** (no quad-only beta feature needed).
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

## v0.2 manual Studio test (important)

Install the **full updated** `mesh-editor/OrangeJuiceMeshEditor.lua` as `%LOCALAPPDATA%\\Roblox\\Plugins\\OrangeJuiceMeshEditor.lua` and restart Studio. This is a replacement of the earlier prototype, **not** the separate Orange Juice AI plugin.

1. Create a fresh test baseplate. Open **Plugins → OJ Mesh**.
2. Click **Create Editable Cube**. A single orange `MeshPart` should appear. If not, use the panel's **Diagnostics** line (it now reports each creation stage) and Studio **Output** to identify the issue.
3. **Object Mode**: use Studio toolbar's normal Move, Scale, Rotate tools (or shortcuts **2**, **3**, **4**) on the complete mesh.
4. **Edit Mode → Vertex → Pick Geometry**: click a corner; the native Studio Move gizmo should appear near it. Drag the arrows and check that only the selected corner moves.
5. Switch to **Edge → Pick Geometry**, select an edge, drag Studio Rotate or Scale; the two endpoint vertices should transform, with neighboring triangles still connected.
6. Switch to **Face → Pick Geometry**, select a triangle, drag the Studio gizmo; only that face's selected vertex IDs should transform.
7. Switch back to **Object Mode**, verify the temporary control pivot disappears and the regular gizmo moves the entire MeshPart.
8. Click **Undo Last Edit** to test the plugin-local undo of mesh geometry. **Ctrl+Z** belongs to Studio history and isn't guaranteed to be synchronized with the plugin's private EditableMesh undo yet.

**If nothing happens:** confirm which UI stage appears in the panel; the prototype **has not been tested in a live Roblox Studio instance by automated CI**. The API may also require permissions to create editable meshes.

### v0.2 technical caveats

- The temporary proxy is a real Roblox Part only for **the native transform handles**. It must never become user model geometry or be left behind in published places.
- The proxy bridge initially supports **one chosen point, edge or triangle**. No multi-selection or keyboard transform hotkeys inside the plugin itself. Switch to the Studio ribbon tools (or shortcuts) after selecting geometry.
- Rotating/scaling a single vertex around its own center is a no-op; moving it works.
- `EditableMesh` visuals update when changing vertex positions, but its collision hull **does not** update until collision is rebuilt; that is future work.
- Pivot transform/selection sync, model persistence, undo after drag and selecting faces under unusual camera angles must be verified manually.
