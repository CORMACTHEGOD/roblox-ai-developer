"""Orange Juice 3D Training Lab v0.1 — our own small neural 3D generator.

Original synthetic training data, genuine PyTorch training, and connected OBJ export.
This is NOT yet a text-to-3D model or a Tripo/Meshy replacement.

Commands:
  python oj3d.py train --steps 800 --device cpu
  python oj3d.py generate --shape rounded_box --output generated/first.obj
"""
import argparse
from pathlib import Path

import numpy as np
import torch
from torch import nn

SHAPES = ("sphere", "rounded_box", "torus")
INPUT_SIZE = 3 + len(SHAPES) + 4


def make_model() -> nn.Module:
    return nn.Sequential(
        nn.Linear(INPUT_SIZE, 96), nn.SiLU(),
        nn.Linear(96, 96), nn.SiLU(),
        nn.Linear(96, 96), nn.SiLU(),
        nn.Linear(96, 1),
    )


def distances(points: torch.Tensor, shape_ids: torch.Tensor,
              dims: torch.Tensor) -> torch.Tensor:
    """Exact original SDF targets. dims = half-width, half-height, half-depth,
    and bevel radius. Sphere uses dims[0] as radius; torus uses dims[0]
    as major radius and dims[3] as tube radius.
    """
    x, y, z = points.unbind(dim=1)
    sphere = points.norm(dim=1) - dims[:, 0]

    bevel = dims[:, 3]
    q = points.abs() - torch.clamp(dims[:, :3] - bevel[:, None], min=0.02)
    rounded_box = (torch.clamp(q, min=0).norm(dim=1)
                   + torch.clamp(q.amax(dim=1), max=0) - bevel)

    ring = torch.sqrt(x*x + z*z) - dims[:, 0]
    torus = torch.sqrt(ring*ring + y*y) - dims[:, 3]

    return torch.where(shape_ids == 0, sphere,
                       torch.where(shape_ids == 1, rounded_box, torus))


def build_inputs(points, shape_ids, dims):
    one_hot = torch.nn.functional.one_hot(
        shape_ids, num_classes=len(SHAPES)).to(points.dtype)
    return torch.cat([points, one_hot, dims], dim=1)


def random_training_batch(n, device):
    xyz = torch.rand(n, 3, device=device) * 2 - 1
    categories = torch.randint(len(SHAPES), (n,), device=device)
    dims = torch.empty(n, 4, device=device)
    dims[:, :3] = torch.rand(n, 3, device=device) * 0.40 + 0.35
    dims[:, 3] = torch.rand(n, device=device) * 0.12 + 0.06
    is_torus = categories == 2
    dims[is_torus, 3] = (
        torch.rand(int(is_torus.sum().item()), device=device) * 0.10 + 0.15)
    return xyz, categories, dims


def train(args):
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    torch.set_num_threads(min(4, torch.get_num_threads()))
    device = torch.device(
        "cuda" if args.device == "auto" and torch.cuda.is_available()
        else "cpu" if args.device == "auto" else args.device)
    model = make_model().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    print(f"Training original 3D network on {device}; "
          f"{sum(p.numel() for p in model.parameters()):,} parameters")
    for step in range(1, args.steps + 1):
        xyz, categories, dims = random_training_batch(args.batch_size, device)
        target = distances(xyz, categories, dims).clamp(
            -0.50, 0.50).unsqueeze(1)
        predicted = model(build_inputs(xyz, categories, dims))
        weights = 1 + 3 * (target.abs() < 0.12).float()
        loss = ((predicted - target).abs() * weights).mean()
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step == 1 or step % max(1, args.steps // 10) == 0 or step == args.steps:
            print(f"step {step:>5}/{args.steps}  SDF loss={loss.item():.4f}")

    path = Path(args.checkpoint)
    path.parent.mkdir(parents=True, exist_ok=True)
    torch.save({
        "state_dict": model.cpu().state_dict(), "steps": args.steps,
        "shapes": SHAPES, "seed": args.seed,
    }, path)
    print(f"Saved trained weights: {path}")


def generate(args):
    try:
        from skimage.measure import marching_cubes
    except ImportError as exc:
        raise SystemExit("Install scikit-image with pip first") from exc
    path = Path(args.checkpoint)
    if not path.is_file():
        raise SystemExit(f"Missing weights at {path}: run 'python oj3d.py train' first")
    record = torch.load(path, map_location="cpu", weights_only=True)
    model = make_model()
    model.load_state_dict(record["state_dict"])
    model.eval()

    count = args.resolution
    coords = np.linspace(-1.0, 1.0, count, dtype=np.float32)
    xx, yy, zz = np.meshgrid(coords, coords, coords, indexing="ij")
    xyz = np.stack([xx.ravel(), yy.ravel(), zz.ravel()], axis=1)
    dims = torch.tensor([[
        args.width, args.height, args.depth, args.roundness
    ]], dtype=torch.float32)
    shape_id = SHAPES.index(args.shape)
    field = np.empty(len(xyz), dtype=np.float32)

    with torch.no_grad():
        for first in range(0, len(xyz), 8192):
            xyz_batch = torch.from_numpy(xyz[first:first+8192])
            ids = torch.full((len(xyz_batch),), shape_id, dtype=torch.long)
            inputs = build_inputs(xyz_batch, ids, dims.expand(len(xyz_batch), -1))
            field[first:first+len(xyz_batch)] = (
                model(inputs).squeeze(1).numpy())

    volume = field.reshape(count, count, count)
    if not float(volume.min()) < 0 < float(volume.max()):
        raise SystemExit(
            "No learned closed surface yet. Train longer, e.g. --steps 1500.")
    vertices, faces, _, _ = marching_cubes(
        volume, level=0.0, spacing=(2/(count-1),)*3)
    vertices -= 1.0

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as stream:
        stream.write("# Generated by our trained neural 3D SDF model\n")
        for x, y, z in vertices:
            stream.write(f"v {x:.6f} {y:.6f} {z:.6f}\n")
        for a, b, c in faces:
            stream.write(f"f {a+1} {b+1} {c+1}\n")
    print(f"Exported {output}: {len(vertices):,} vertices, "
          f"{len(faces):,} triangles")


def main():
    parser = argparse.ArgumentParser(
        description="Orange Juice 3D — train our own 3D shape network")
    cmds = parser.add_subparsers(dest="command", required=True)
    training = cmds.add_parser("train")
    training.add_argument("--steps", type=int, default=800)
    training.add_argument("--batch-size", type=int, default=768)
    training.add_argument("--seed", type=int, default=42)
    training.add_argument("--device", choices=("auto", "cpu", "cuda"), default="auto")
    training.add_argument("--lr", type=float, default=0.002)
    training.add_argument("--checkpoint", default="checkpoints/oj3d_model.pt")
    training.set_defaults(run=train)

    creation = cmds.add_parser("generate")
    creation.add_argument("--shape", choices=SHAPES, default="rounded_box")
    creation.add_argument("--checkpoint", default="checkpoints/oj3d_model.pt")
    creation.add_argument("--output", default="generated/orange_shape.obj")
    creation.add_argument("--width", type=float, default=0.63)
    creation.add_argument("--height", type=float, default=0.53)
    creation.add_argument("--depth", type=float, default=0.58)
    creation.add_argument("--roundness", type=float, default=0.14)
    creation.add_argument("--resolution", type=int, default=48)
    creation.set_defaults(run=generate)

    args = parser.parse_args()
    if args.command == "train":
        if args.steps < 1 or args.batch_size < 1:
            parser.error("steps and batch size must be positive")
    else:
        if not 24 <= args.resolution <= 160:
            parser.error("resolution must be 24–160")
        if not (0.05 <= args.width <= 0.9
                and 0.05 <= args.height <= 0.9
                and 0.05 <= args.depth <= 0.9):
            parser.error("dimensions must be between 0.05 and 0.9")
        if not 0.02 <= args.roundness <= 0.30:
            parser.error("roundness must be between 0.02 and 0.30")
    args.run(args)


if __name__ == "__main__":
    main()
