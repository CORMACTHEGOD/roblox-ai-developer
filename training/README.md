# Orange Juice 3D — our own AI training lab

This starts **real neural-network training from scratch**, not another prompt-based "training" update, and **doesn't use Tripo, Meshy, Roblox Assistant, OpenAI API, or Cloudflare**. We build and learn how the model works.

## What it does today

- Generates infinite **original synthetic 3D geometry** with mathematical signed distance functions (SDFs).
- Trains a tiny **PyTorch network with randomly initialized weights** to predict the distance from a 3D point to a shape's surface.
- Learns three variable-dimension shape *families*: **spheres, rounded boxes, and toruses**.
- Converts the resulting continuous learned 3D surface into a connected triangle `.obj` file with marching cubes.
- Saves the trained model in a `.pt` checkpoint. No paid API keys.

**What it does NOT do yet:** create arbitrary 3D models from English text, generate high-quality chests/animals/vehicles, color or texture meshes, or replace a production text-to-3D service. This is a real educational geometry-model baseline; the larger AI is a later project.

## Install on your Windows laptop

Install Python from [python.org](https://www.python.org/downloads/) and enable **Add Python to PATH**. Download this folder from the repository. In PowerShell opened in `training`:

```powershell
py -m pip install -r requirements.txt
```

With Intel Iris Xe, use **CPU** mode. You don't need a powerful GPU to run this first experiment.

## Train the neural network yourself

```powershell
py oj3d.py train --steps 800 --device cpu
```

You'll see a training step and **SDF loss** printed about ten times. The loss measures how wrong the model's distance predictions are; lower is generally better. The model saves weights to `checkpoints/oj3d_model.pt`.

If the first run is too slow, try `--steps 150`. To improve shape fidelity later, run `--steps 1500` (starting from random weights again).

## Generate a real mesh from the trained weights

```powershell
py oj3d.py generate --shape rounded_box --output generated/my_first_model.obj
```

Try other shapes:

```powershell
py oj3d.py generate --shape sphere --width 0.65 --output generated/sphere.obj
py oj3d.py generate --shape torus --width 0.5 --roundness 0.20 --output generated/torus.obj
```

These are *mesh faces and vertices* in OBJ files, not collections of overlapping Roblox Parts. Open the OBJ using **Blender → File → Import → Wavefront (.obj)** or Studio's **3D Importer**.

## Confirmed local experiment

We trained the same small model for 800 steps on CPU and exported the three shape families at a 48-point resolution. Basic tests with `trimesh` found all three meshes to have one connected component and be watertight. This **does not** prove polished visual quality or guarantee reliable results for every setting.

## Learning roadmap

1. **This lab:** datasets, signed distance fields, neural weights, training loops, triangle mesh generation.
2. Build lots of **original** procedural treasure chests, lamps, stylized props and other shape variations. Keep train/test objects separate to measure generalization.
3. Train a generative model that can propose new shapes, not just reproduce a specific class of simple geometries.
4. Add safe, legally sourced **text/image conditioning** for prompts, plus accurate mesh generation and optimization.
5. Add **materials, colors, textures/UVs** and evaluate visual quality in Blender/Roblox Studio.
6. Integrate an inference service with **Orange Juice AI → Prepare → Preview → Apply** with real mesh files. Secure user sessions and model usage quotas when publishing.

**Cost reality:** The API endpoints and keys *we create* can be free. Training and hosting serious 3D models still consumes GPU time/electricity. The goal is to learn first and scale responsibly, not promise that a Tripo-quality service is free or easy.

**Data and rights:** Train on your own models or properly licensed material. Do not assume that free downloads or Roblox assets are licensed for AI training/republication.

The separate `mesh-editor/` experimental Studio editing project remains independent. This ML lab doesn't require that plugin.
