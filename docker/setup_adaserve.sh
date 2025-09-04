#! /usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}/.."

read -sp "Enter your Hugging Face token: " HF_TOKEN
echo
export HF_TOKEN

docker exec -it -e HF_TOKEN adaserve /bin/bash -c '
set -x
set -e

# Clone the codebase inside the container.
git clone --recursive https://github.com/zikun-li/AdaServe-Artifact-Evaluation.git
cd AdaServe-Artifact-Evaluation

# Build AdaServe.
pushd adaserve
pip install cmake==3.27.7
rustup install 1.82.0 && rustup default 1.82.0
mkdir -p build
cd build
../config/config.linux
make -j
popd

# Install th Python packages and download the huggingface models.
cd ..
git clone https://github.com/flexflow/flexflow-serve.git download_model && cd download_model
git checkout flexllm-aec
git submodule update --init --recursive
pip install flash_attn==2.7.4.post1
huggingface-cli login --token $HF_TOKEN
mkdir -p build
cd build
../config/config.linux
make -j
source ./set_python_envs.sh
cd ..
mkdir -p /models
python inference/utils/download_hf_model.py --half-precision-only meta-llama/llama-3.1-70b-instruct meta-llama/llama-3.2-1b-instruct Qwen/Qwen2.5-32B-instruct Qwen/Qwen2.5-0.5B-instruct --cache-folder /models
'
