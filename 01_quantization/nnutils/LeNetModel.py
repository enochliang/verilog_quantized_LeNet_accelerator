import torch
import torch.nn as nn
from collections import OrderedDict


class LeNet(nn.Module):
    def __init__(self):
        super(LeNet, self).__init__()

        self.c1 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(1, 6, 5, bias=False)),
            ('relu', nn.ReLU()),
        ]))

        self.s2 = nn.Sequential(OrderedDict([
            ('pool', nn.MaxPool2d(kernel_size=(2, 2), stride=2))
        ]))

        self.c3 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(6, 16, 5, bias=False)),
            ('relu', nn.ReLU())
        ]))

        self.s4 = nn.Sequential(OrderedDict([
            ('pool', nn.MaxPool2d(kernel_size=(2, 2), stride=2))
        ]))

        self.c5 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 120, 5, bias=False)),
            ('relu', nn.ReLU())
        ]))

        self.f6 = nn.Sequential(OrderedDict([
            ('fc', nn.Linear(120, 84, bias=False)),
            ('relu', nn.ReLU())
        ]))

        self.output = nn.Sequential(OrderedDict([
            ('fc', nn.Linear(84, 10, bias=False)),
        ]))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.c1(x)
        x = self.s2(x)
        x = self.c3(x)
        x = self.s4(x)
        x = self.c5(x)
        x = torch.flatten(x, 1)
        x = self.f6(x)
        x = self.output(x)
        return x


class LeNet_with_bias(LeNet):
    def __init__(self):
        super(LeNet_with_bias, self).__init__()

        self.output = nn.Sequential(OrderedDict([
            ('fc', nn.Linear(84, 10, bias=True)),
        ]))
