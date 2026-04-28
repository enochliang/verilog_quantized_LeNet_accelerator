# README
This is the repository of project in the course (VLSI_System_Design - CS5120, 2022 Spring, NTHU)

## Model Architecture
=================================================================
Layer (type:depth-idx)                   Param #
=================================================================
LeNet                                    --
├─Sequential: 1-1                        --
│    └─Conv2d: 2-1                       150
│    └─ReLU: 2-2                         --
├─Sequential: 1-2                        --
│    └─MaxPool2d: 2-3                    --
├─Sequential: 1-3                        --
│    └─Conv2d: 2-4                       2,400
│    └─ReLU: 2-5                         --
├─Sequential: 1-4                        --
│    └─MaxPool2d: 2-6                    --
├─Sequential: 1-5                        --
│    └─Conv2d: 2-7                       48,000
│    └─ReLU: 2-8                         --
├─Sequential: 1-6                        --
│    └─Linear: 2-9                       10,080
│    └─ReLU: 2-10                        --
├─Sequential: 1-7                        --
│    └─Linear: 2-11                      840
=================================================================
Total params: 61,470
Trainable params: 61,470
Non-trainable params: 0
=================================================================

![LeNet Model Architecture](99_images/lenet5_architecture.png)
