# External 3D reference inspection — prop, animal and vehicle modeling

**Source and permission:** These four uploaded files were downloaded from third-party websites by the developer. Their creators' asset licenses have **not** been verified. Inspect only to derive **general design and organization principles**, not to redistribute their meshes, textures, logos, animation data or other copyrighted content. The original files are **not** copied into GitHub or the public Orange Juice AI plugin. This report is an inventory, not an endorsement of their quality or safety.

## Verified file facts

| Local uploaded file | Format | Measured structural information | Suitable conceptual reference |
|---|---|---|---|
| `low_poly_pirate_sword.fbx` | Binary FBX v7400, 75,740 bytes | **4** mesh geometry objects / **4** mesh-model nodes; **877** geometric vertices; **1** material and **1** texture entry; no FBX animation nodes detected | Stylized accessory/handheld prop *composition*: clearly separated silhouettes and subassemblies rather than detailed combat designs |
| `Horse.fbx` | Binary FBX v7400, 485,964 bytes | **1** mesh with **1,004** vertices; **75** Model nodes including a **Horse-Rig** root and many `LimbNode` bones; **54** Deformer nodes; **1** AnimationStack, **1** AnimationLayer, **486** AnimationCurve and **162** AnimationCurveNode entries | Organic silhouette, symmetrical leg/ear structure, object-vs-rig separation and animation-aware character modeling |
| `Lamborghini+Revuelto.fbx` | Binary FBX v7400, 38,628,179 bytes | **504** mesh Geometry nodes, **517** Model nodes, **444,749** vertices across meshes, **49** material nodes and **29** texture nodes. No FBX AnimationStack objects detected | Complex hard-surface prop assembly, material grouping, named subcomponents, import-size awareness and the importance of lowering geometry budgets for Roblox |
| `glock+17.obj` | Text OBJ, 4,976,681 bytes | **9** named OBJ groups, **44,323** vertex lines, **24,071** face lines and per-group material references. The OBJ points to a separate MTL file, not included in this upload | Only generic file-inventory/import-size lessons; **not** a reconstruction or modeling reference for realistic weapons |

FBX PolygonVertexIndex array lengths count index entries, **not** necessarily triangular face counts. These numbers come from FBX binary node/array inspection and OBJ line counts. They do **not** prove that the models render correctly in Roblox Studio, that textures are present or licensed, or that imported rigs and animations work.

## Principles to teach Orange Juice AI

**A. Stylized accessories and handheld game props (non-weapon-specific):** Recognizable primary silhouette, distinct handle/connector/decorative pieces, coherent material sections, moderate object count, readable design at small size. Use entirely original shapes and permitted assets.

**B. Animals and organic characters:** Start with recognizable silhouette and overall proportions; keep left/right limbs readable, name components predictably, plan if a separate rig is needed, and do not claim an animation works merely because an FBX contains curves or bones. Character rigging/animation generation is a later feature.

**C. Cars and hard-surface vehicles:** Separate conceptual systems (main body, glass, wheels, trim and lights). Use consistent material families, part naming and logical grouping. Heavy references are **style/organization** examples only: an input with 444,749 vertices is not an appropriate default geometry budget for every Roblox game. Design light simplified equivalents first; use optimized licensed meshes only after adding actual asset import support.

**D. Performance-aware modular design:** Choose a reasonable primitive count for the object being built, avoid invisible decorative details, prioritize clear silhouette and readable material separation, and make reusable object hierarchies. Do not invent Roblox mesh asset IDs or claim that Part-based plans can reproduce exact FBX triangles.

**E. Boundaries:** Third-party files must not become downloadable assets in the plugin without verified distribution rights. Public Roblox game links do not grant access to private mesh, UI or script data. Weapon-specific mechanisms and detailed realistic weapon modeling are outside this reference library.

## Current v0.9 implementation

The Cloudflare Worker selects a compact subset of these *conceptual modeling rules* when a user requests animals, stylized props or vehicles. End users still only use **Prepare → Review → Apply**. No raw FBX/OBJ bytes are sent to OpenAI or the plugin.

The current Studio plugin creates **basic Part/Model and supported Script/UI classes**, not arbitrary 3D meshes or fully functional skinned/animated rigs. For a rigged animal, it should plan a limited static approximation or accurately disclose that a mesh and rig import is needed rather than claiming to have created a complete animation.

## Deferred work

- VFX emitters, trails and beams
- Rig and animation import/editing
- More developer-maintained UI screenshots and style studies
- Licensed asset catalog and user-friendly mesh import/mapping
