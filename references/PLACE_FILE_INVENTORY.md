# Observations from three uploaded Roblox .rbxl files

**Method:** Parsed Roblox binary place-file headers and LZ4 `INST` chunks to count instance classes (without executing scripts, loading games, or extracting private scripts/mesh bytes). Counts describe the place files as given, including Roblox service/default objects. They **do not** establish whether any content is safe, licensed, visually polished or functional.

| Uploaded place | Total instances | Selected measured instance classes |
|---|---:|---|
| `Goku-Character-Model-Free.rbxl` | 567 | Attachment **174**, ParticleEmitter **108**, Part **53**, Beam **40**, MeshPart **23**, Model **9**, Motor6D **24**, Weld **9** |
| `Low-Poly-Stud-Forest.rbxl` | 5,835 | Weld **2,900**, Part **2,766**, Attachment **22**, Model **6**, Animation **9**, LocalScript **1** |
| `1-School-Treasure-Collect-Coins.rbxl` | 9,012 | Part **3,189**, BlockMesh **1,878**, CylinderMesh **481**, Sound **468**, MeshPart **285**, Script **233**, ModuleScript **66**, LocalScript **15**, Model **104**, SurfaceGui **7**, ScreenGui **2**, Frame **7**, TextLabel **5**, TextButton **2** |

## Patterns these inventories support
- **Assembled environment modeling:** the forest example contains many separate Parts and Welds. This is evidence of part-based assembly, not a performance guarantee.
- **Mixed gameplay place composition:** the school/collection place has a large visual scene and several hundred code objects of various types along with UI and audio objects. We cannot infer code correctness from class counts alone.
- **Character effects structure:** the character place combines Attachments, ParticleEmitters, Beams, meshes and joints. This supports abstract VFX-assembly guidance; do not replicate any protected character.
- The screenshots, not these class counts, provide the evidence for UI colors, strokes, reflections, composition and visual style.

## How the live AI uses this
The Worker carries a compact, curated profile and chooses modeling or GUI guidance based on each **Prepare** request. It does not transfer, execute, resell, or reproduce any portion of the original place files. This is **reference-guided planning, not fine-tuning**.

## What the current plugin cannot do yet
It can generate primitive Part-based models, basic UI and supported scripts, but it cannot reconstruct uploaded mesh geometry, animate exported Blender rigs automatically, prove a source script is correct, or inspect another game's private contents from a Roblox URL.

## Recommended developer workflow for new original assets
1. Make and test original meshes in Blender.
2. Import suitable models into Roblox Studio and configure collision, appearance and any animations in Studio.
3. Save a Roblox model `.rbxm`/`.rbxmx` or provide a supported interchange model file if a new reference is needed.
4. A future developer-only ingestion pipeline will scan assets with permission and add validated patterns to the library; this does not happen automatically yet.
