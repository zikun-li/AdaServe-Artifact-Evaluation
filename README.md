# AdaServe-Artifact-Evaluation
The artifact evaluation repo for AdaServe.

## Getting Started Instructions

### Hardware setup
To begin, please spin up a machine with the following characteristics:
- 8 NVIDIA A100-SXM4-40GB GPUs
- CUDA 12.4
- Docker support with NVIDIA container runtime
- 512GB+ disk memory

If you are using AWS, please create a `p4de.24xlarge` instance with the `Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04)` AMI. If you do not have access to such a machine, let us know and we will start a machine for you.

Once you have started the machine (or we started one for you), please connect to the machine via SSH. 

### Preparation
To start, please download the code with `git clone --recursive https://github.com/zikun-li/AdaServe-Artifact-Evaluation.git`. Then, follow the steps below to build a Docker container where you will be able to run all experiments.

1. Run `./docker/build_container.sh` to build the container
2. Run `./docker/start_container.sh` to start the container. It will continue running in the background until stopped.
3. Run `./docker/setup_flexllm.sh` to install all the required libraries and download the Huggingface models in the container. When prompted, please provide your huggingface token to access the following models: `meta-llama/Llama-3.1-70B-Instruct`, `Qwen/Qwen2.5-32B-Instruct`. If you do not have a token, we can provide one.
4. Run `./docker/attach_to_container.sh` to open a new terminal connected to the container. You can run this multiple times if you'd like to connect multiple terminal windows.

### Teardown
The teardown step is important to ensure that the next reviewer has access to a clean environment for their evaluation.

- Run `./docker/cleanup_containers.sh` after you are done to stop and destroy the container and all docker images/data.
- From the host machine, delete the `AdaServe-Artifact-Evaluation` repo and any other files you have created/downloaded
