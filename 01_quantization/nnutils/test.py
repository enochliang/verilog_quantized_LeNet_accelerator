import torch
import torch.nn as nn
from torch.utils.data import DataLoader
import torch.optim as optim


def test(model: nn.Module, dataloader: DataLoader, max_samples=None, device=torch.device('cpu')) -> float:
    correct = 0
    total = 0
    n_inferences = 0

    with torch.no_grad():
        for data in dataloader:

            images, labels = data[0].to(device), data[1].to(device)

            outputs = model(images)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

            if max_samples:
                n_inferences += images.shape[0]
                if n_inferences > max_samples:
                    break

    return 100 * correct / total
