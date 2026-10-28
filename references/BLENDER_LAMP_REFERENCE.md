# Original Blender lamp — geometry reference for Orange Juice AI

**Source:** User-created `OrangeJUiceAI(1).fbx` / `OrangeJUiceAI.fbx`. The two uploaded FBX files are byte-identical. Only *descriptive modeling patterns* are documented here; the raw model is not uploaded to the public repository and does not become available to end users.

## Verified from the FBX binary (v7400)
- **Three mesh Geometry nodes:** `Cylinder.001`, `Cylinder.002`, and `Sphere`; three corresponding mesh Model objects; one Camera and one Light object.
- **Vertex-coordinate counts:** 1,473, 522, and 1,446 scalar coordinates respectively, representing **491, 174, and 482 mesh vertices (1,147 total)**.
- FBX binary has **no exported Material object** (this does not establish that no viewport shading or other Blender setup ever existed).
- Earlier model preview showed a **rounded/circular base with a tapered lamp stem**, an upper **cylindrical lampshade**, and a **small spherical accent**; the preview used false colors for visibility, not original surface materials.
- The exact scale, Roblox anchoring, collision settings, shadowing and in-game lamp light behavior were **not** established by this export alone.

## What Orange Juice AI should infer
1. **Construct complete objects from multiple coherent subcomponents.** For a lamp, identify base, stem, shade, light source and optional decorative accent rather than making one undifferentiated block.
2. **Silhouette first:** match the proportion of wide base, slim support and wider top; use intentional tapers and transitions.
3. **Structured hierarchy:** group the components in a Model and use readable names; ensure relative placement works before refining finish.
4. **Material and color are a separate design step.** Choose an original coherent palette and intentional material response; the reference FBX has no exported materials to copy.
5. **Gameplay needs are a distinct step:** a decorative lamp can be static; an interactive lamp may need a switch/prompt and code to toggle a *real* Roblox PointLight/SpotLight. Don't claim lighting works if the supported builder cannot yet add light instances.
6. **Avoid pretending to reconstruct FBX meshes.** The current plugin's model builder is limited to primitive Part/WedgePart-based approximations. Adding imported original MeshParts and lighting Classes is future work.

## Reference profile to apply to other props
The reusable lesson is the **coherent assembly approach**, not the exact lamp geometry: for furniture, signs, vending machines, kiosks and treasure chests, plan distinct structural/functional/decorative elements that make the silhouette recognizable. Inspect existing objects before proposing duplicates. Include working scripts or interactions only when the request actually needs them.

## Implementation in this branch
The Worker embeds a concise modeling-reference profile derived from this document. On `Prepare`, prompts about lamps/lighting and related props receive guidance to plan original coherent component groups, with an explicit note about geometry/lighting limitations. This is **prompt-based conditioning**, not neural fine-tuning and not a mesh importer.
