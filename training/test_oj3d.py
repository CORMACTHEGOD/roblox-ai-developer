"""Small deterministic tests: no paid API and no downloading model weights."""
import unittest
import torch

from oj3d import SHAPES, make_model, distances, build_inputs


class GeometryTrainingTests(unittest.TestCase):
    def test_original_shape_families(self):
        self.assertEqual(SHAPES, ("sphere", "rounded_box", "torus"))
        points = torch.zeros(3, 3)
        category = torch.tensor([0, 1, 2])
        dims = torch.tensor([
            [0.60, 0.55, 0.55, 0.10],
            [0.60, 0.55, 0.55, 0.10],
            [0.50, 0.40, 0.40, 0.20],
        ])
        sdf = distances(points, category, dims)
        self.assertAlmostEqual(sdf[0].item(), -0.60, places=4)
        self.assertLess(sdf[1].item(), 0.0)  # box center lies inside
        self.assertGreater(sdf[2].item(), 0.0)  # torus center is a hole

    def test_trainable_neural_network(self):
        torch.manual_seed(10)
        net = make_model()
        xyz = torch.rand(8, 3) * 2 - 1
        categories = torch.randint(3, (8,))
        dims = torch.full((8, 4), 0.4)
        inputs = build_inputs(xyz, categories, dims)
        prediction = net(inputs)
        self.assertEqual(prediction.shape, (8, 1))
        target = distances(xyz, categories, dims).unsqueeze(1)
        loss = (prediction - target).square().mean()
        loss.backward()
        self.assertTrue(any(
            parameter.grad is not None
            and bool(parameter.grad.abs().sum() > 0)
            for parameter in net.parameters()
        ))


if __name__ == "__main__":
    unittest.main()
