# AdaServe-Artifact-Evaluation
This is the artifact evaluation repo for AdaServe.

## Getting Started Instructions

### Hardware setup

#### Using the Provided Machine

In the artifact evaluation, we will provide you a machine with the following characteristics:
- 8 NVIDIA A100-SXM4-40GB GPUs
- CUDA 12.4
- Docker support with NVIDIA container runtime
- 512GB+ disk memory

The access to this machine will be granted after the kick-the-tires period.

Please note that due to the availability issues, we cannot provide you a machine with the setup used in our evaluation on the paper, which has the following characteristics:
- 4 NVIDIA A100-SXM4-80GB GPUs
- CUDA 12.4
- Docker support with NVIDIA container runtime
- 1.1TB+ RAM
- 512GB+ disk memory

#### Using Your Own Machine
Please spin up a machine with the following characteristics:
- 8 NVIDIA A100-SXM4-40GB GPUs
- CUDA 12.4
- Docker support with NVIDIA container runtime
- 512GB+ RAM
- 512GB+ disk memory

If you are using AWS, please create a `p4de.24xlarge` instance with the `Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04)` AMI.

Once you have started the machine, please connect to the machine via SSH. 

### Preparation
To start, please download the code with 

```bash
git clone --recursive https://github.com/zikun-li/AdaServe-Artifact-Evaluation.git
```

Then, follow the steps below to build a Docker container where you will be able to run all experiments.

1. Run `./docker/build_container.sh` to build the container
2. Run `./docker/start_container.sh` to start the container. It will continue running in the background until stopped. NOTE: The host directory `/opt/dlami/nvme/models` will be mounted into the container to avoid weights duplication in our machine. Feel free to change it to any directory you like in your own host machine.
3. Run `./docker/setup_flexllm.sh` to install all the required libraries and download the Huggingface models in the container. When prompted, please provide your huggingface token to access the following models: `meta-llama/Llama-3.1-70B-Instruct`, `Qwen/Qwen2.5-32B-Instruct`. If you do not have a token, we can provide one.
4. Run `./docker/attach_to_container.sh` to open a new terminal connected to the container. You can run this multiple times if you'd like to connect multiple terminal windows.

### Teardown
The teardown step is important to ensure that the next reviewer has access to a clean environment for their evaluation.

- Run `./docker/cleanup_containers.sh` after you are done to stop and destroy the container and all docker images/data.
- From the host machine, delete the `AdaServe-Artifact-Evaluation` repo and any other files you have created/downloaded

## Running the Experiments

Here are step-by-step instructions for reproducing the evaluation results in the paper. 

Please note that, due to the difference machine setups mentioned in Due to the difference in machine setups mentioned in the second section, the evaluation results will be different from what shown in the paper. However, the evaluation results should follow similar trend with what we've shown in the paper and support the same claims.

### Figure 8 and 9

Use the following commands to run the experiments for Figure 8 and 9. To run the evaluation for LLaMA-3.1-70B-Instruct:

```bash
ADASERVE=ON RPS_MIN=2.6 RPS_MAX=4.8 ./exps/fig8,9/run_llama_rps.sh
```

To run the evaluation for Qwen2.5-32B-Instruct:

```bash
ADASERVE=ON RPS_MIN=2.4 RPS_MAX=4.2 ./exps/fig8,9/run_qwen_rps.sh
```

`RPS_MIN` and `RPS_MAX` can be adjusted to cover different RPS ranges. The minimal RPS is 2.6 and the maximal RPS is 4.8 for LLaMA-3.1-70B-Instruct on our evaluation. The minimal RPS is 2.4 and the maximal RPS is 4.2 for Qwen2.5-32B-Instruct on our evaluation. The minimal step size is set to 0.2.


The results are saved in `results/fig8,9/llama/adaserve/`. 

### Figure 10

Use the following commands to run the experiments for Figure 10. To run the evaluation for LLaMA-3.1-70B-Instruct:

```bash
ADASERVE=ON PROP_MIN=0.2 PROP_MAX=0.9 ./exps/fig10/run_llama_prop.sh
```

To run the evaluation for Qwen2.5-32B-Instruct:

```bash
ADASERVE=ON PROP_MIN=0.2 PROP_MAX=0.9 ./exps/fig10/run_qwen_prop.sh
``` 

`PROP_MIN` and `PROP_MAX` can be adjusted to cover different proportion ranges. The minimal proportion is 0.1 and the maximal proportion is 0.9 for both LLaMA-3.1-70B-Instruct and Qwen2.5-32B-Instruct on our evaluation. The minimal step size is 0.1.

The results are saved in `results/fig10/llama/adaserve/`.

### Figure 11

Use the following commands to run the experiments for Figure 11. To run the evaluation for LLaMA-3.1-70B-Instruct:

```bash
ADASERVE=ON SLO_SCALE_MIN=0.6 SLO_SCALE_MAX=1.6 OUTPUT_LENGTH=256 ./exps/fig11/run_llama_slo.sh
```

To run the evaluation for Qwen2.5-32B-Instruct:

```bash
ADASERVE=ON SLO_SCALE_MIN=0.6 SLO_SCALE_MAX=1.6 OUTPUT_LENGTH=256 ./exps/fig11/run_qwen_slo.sh
```

`SLO_SCALE_MIN` and `SLO_SCALE_MAX` can be adjusted to cover different SLO ranges. The minimal SLO scale is 0.6 and the maximal SLO scale is 1.6 for both LLaMA-3.1-70B-Instruct and Qwen2.5-32B-Instruct on our evaluation. The minimal step size is 0.2.

The results are saved in `results/fig11/llama/adaserve/`.

### Figure 12

The data for Figure 12 is collected during the experiments for Figure 8 and 9. You can find the data in `results/fig8,9/llama/adaserve/` and `results/fig8,9/qwen/adaserve/`. The number is reported in the line starting with `mean_generated_tokens_per_step` at the end of the files.

### Figure 14   

Use the following commands to run the experiments for Figure 14. To run the evaluation for LLaMA-3.1-70B-Instruct:

```bash
ADASERVE=ON ./exps/fig14/run_llama_fluc.sh
```

To run the evaluation for Qwen2.5-32B-Instruct:

```bash
ADASERVE=ON ./exps/fig14/run_qwen_fluc.sh
```

The results are saved in `results/fig14/llama/adaserve/` and `results/fig14/qwen/adaserve/`.

### Figure 15

Use the following commands to run the experiments for Figure 15. To run the evaluation for LLaMA-3.1-70B-Instruct:

```bash
LLAMA_OVERHEAD=ON ./exps/fig15/run_overhead_breakdown.sh
```

To run the evaluation for Qwen2.5-32B-Instruct:

```bash
QWEN_OVERHEAD=ON ./exps/fig15/run_overhead_breakdown.sh
```

The results are saved in `results/fig15/llama/` and `results/fig15/qwen/`.
