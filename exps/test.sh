#!/bin/bash
set -x

# Cd into directory holding this script
cd "${BASH_SOURCE[0]%/*}"

# check LLM_MODEL is set
if [ -z "$LLM_MODEL" ]; then
    echo -e "LLM_MODEL is not set"
    exit 1
fi
echo -e "Using LLM model: $LLM_MODEL"

# check SSM_MODEL is set
if [ -z "$SSM_MODEL" ]; then
    echo -e "SSM_MODEL is not set"
    exit 1
fi
echo -e "Using SSM model: $SSM_MODEL"

# check DATASETS_FILE is set
if [ -z "$DATASETS_FILE" ]; then
    echo -e "DATASETS_FILE is not set"
    exit 1
fi
echo -e "Datasets: $DATASETS_FILE"

export OUTPUT_SWITCH=${OUTPUT_SWITCH:-ON}

export VLLM_SERVER_PORT=8001
export BASELINE_LATENCY_PER_TOKEN=${BASELINE_LATENCY_PER_TOKEN:-0.05}
export BASELINE_LATENCY_PER_TOKEN_MS=${BASELINE_LATENCY_PER_TOKEN_MS:-15}

export REQUEST_BATCH=${REQUEST_BATCH:-64}

###################################################
################# test switches ###################
###################################################

export ENABLE_SPECSCHEDULER_SPEC_INFER=${ENABLE_SPECSCHEDULER_SPEC_INFER:-OFF}
export ENABLE_SPECSCHEDULER_OLD_VERSION=${ENABLE_SPECSCHEDULER_OLD_VERSION:-OFF}
export ENABLE_VLLM_SERVER_BENCHMARK=${ENABLE_VLLM_SERVER_BENCHMARK:-OFF}
export ENABLE_VLLM_SPEC_INFER=${ENABLE_VLLM_SPEC_INFER:-OFF}
export ENABLE_VLLM_SARATHI_SERVE=${ENABLE_VLLM_SARATHI_SERVE:-OFF}



###############################################################################################
#################################### vLLM Benchmark ###########################################
###############################################################################################

if [ $ENABLE_VLLM_SERVER_BENCHMARK = "ON" ]; then
    # Create virtual environment if not already created
    VENV_DIR="../venv_vllm"
    [ ! -d "$VENV_DIR" ] && python3 -m venv $VENV_DIR

    # Activate virtual environment
    source $VENV_DIR/bin/activate

    # Function to check if a port is in use
    is_port_in_use() {
        nc -z localhost $1 >/dev/null 2>&1
        return $?
    }

    # Install vLLM if not already installed
    python -c "import vllm" &> /dev/null || pip3 install vllm xformers

    TENSOR_PARALLEL_SIZE=${TENSOR_PARALLEL_SIZE:-4}
    MAX_REQUESTS_PER_BATCH=${MAX_REQUESTS_PER_BATCH:-512}
    LOG_FILE="${VLLM_RESULT_FILENAME%.json}.log"

    # Start vLLM server with tensor and pipeline parallelism
    # cmd="nsys profile --stats=true --force-overwrite=true -o vllm_fp16 \
    cmd="vllm serve $LLM_MODEL --port $VLLM_SERVER_PORT --no-enable-prefix-caching --tensor-parallel-size $TENSOR_PARALLEL_SIZE --pipeline-parallel-size 1 --enable-chunked-prefill False --max-num-seqs $MAX_REQUESTS_PER_BATCH --dtype float16 --max-seq-len-to-capture 2048 --disable-log-requests"
    eval "$cmd"  > "$LOG_FILE" 2>&1 &
    VLLM_PID=$!

    # Wait for vLLM server to start
    for i in {1..60}; do
        if is_port_in_use $VLLM_SERVER_PORT; then
            echo "vLLM server started on port $VLLM_SERVER_PORT."
            break
        fi
        sleep 10
        if [ $i -eq 60 ]; then
            echo "Warning: vLLM server did not start within 300 seconds."
        fi
    done

    # Run benchmark and stop server
    python ../systems/vllm/benchmarks/benchmark_serving.py --input-file $DATASETS_FILE --backend vllm \
        --model $LLM_MODEL --save-result --result-filename $VLLM_RESULT_FILENAME --port $VLLM_SERVER_PORT --baseline-latency-per-token $BASELINE_LATENCY_PER_TOKEN

    # Ensure all vLLM server processes are terminated
    echo "Stopping all vLLM server processes"
    pkill -9 pt_main_thread
    pkill -9 vllm
    pkill -9 python
    sleep 2  # Give some time for the processes to terminate gracefully

    # Deactivate the virtual environment
    deactivate
fi

###############################################################################################
############################### vLLM spec_infer Benchmark #####################################
###############################################################################################

if [ $ENABLE_VLLM_SPEC_INFER = "ON" ]; then
    # Create virtual environment if not already created
    VENV_DIR="../venv_vllm"
    # VENV_DIR="../venv_vllm_spec"
    [ ! -d "$VENV_DIR" ] && python3 -m venv $VENV_DIR
    LOG_FILE="${VLLM_RESULT_FILENAME%.json}.log"

    # Activate virtual environment
    source $VENV_DIR/bin/activate

    # Function to check if a port is in use
    is_port_in_use() {
        nc -z localhost $1 >/dev/null 2>&1
        return $?
    }

    # Install vLLM if not already installed
    python -c "import vllm" &> /dev/null || pip3 install vllm xformers

    NUM_SPEC_TOKENS=${NUM_SPEC_TOKENS:-4}
    TENSOR_PARALLEL_SIZE=${TENSOR_PARALLEL_SIZE:-4}
    MAX_REQUESTS_PER_BATCH=${MAX_REQUESTS_PER_BATCH:-512}

    # Start vLLM server with tensor and pipeline parallelism
    cmd="vllm serve $LLM_MODEL --port $VLLM_SERVER_PORT \
    --no-enable-prefix-caching \
    --tensor-parallel-size $TENSOR_PARALLEL_SIZE \
    --pipeline-parallel-size 1 \
    --enable-chunked-prefill False \
    --dtype float16 \
    --max-num-seqs $MAX_REQUESTS_PER_BATCH \
    --speculative_config '{\"model\": \"$SSM_MODEL\", \"draft_tensor_parallel_size\": 1, \"num_speculative_tokens\": $NUM_SPEC_TOKENS}' \
    --disable-log-requests"
    # --enforce-eager"

    # cmd="vllm serve $LLM_MODEL --port $VLLM_SERVER_PORT --no-enable-prefix-caching --tensor-parallel-size 4 --pipeline-parallel-size 1 --enable-chunked-prefill False --dtype float16 \
    # --speculative-model $SSM_MODEL \
    # --num-speculative-tokens $NUM_SPEC_TOKENS \
    # --speculative-draft-tensor-parallel-size 1 \
    # --disable-log-requests \
    # --enforce-eager"

    # cmd="vllm serve $LLM_MODEL --port $VLLM_SERVER_PORT --tensor-parallel-size 4 --pipeline-parallel-size 1 --enable-chunked-prefill False --dtype float16 \
    # --speculative-model $SSM_MODEL \
    # --num-speculative-tokens $NUM_SPEC_TOKENS \
    # --speculative-draft-tensor-parallel-size 1 \
    # --disable-log-requests"
    eval "$cmd"  > "$LOG_FILE" 2>&1 &
    VLLM_PID=$!

    # Wait for vLLM server to start
    for i in {1..60}; do
        if is_port_in_use $VLLM_SERVER_PORT; then
            echo "vLLM server started on port $VLLM_SERVER_PORT."
            break
        fi
        sleep 10
        if [ $i -eq 60 ]; then
            echo "Warning: vLLM server did not start within 300 seconds."
        fi
    done

    # Run benchmark and stop server
    python ../systems/vllm/benchmarks/benchmark_serving.py --input-file $DATASETS_FILE --backend vllm \
        --model $LLM_MODEL --save-result --result-filename $VLLM_RESULT_FILENAME --port $VLLM_SERVER_PORT --baseline-latency-per-token $BASELINE_LATENCY_PER_TOKEN

    # Ensure all vLLM server processes are terminated
    echo "Stopping all vLLM server processes"
    pkill -9 pt_main_thread
    pkill -9 vllm
    pkill -9 python
    sleep 2  # Give some time for the processes to terminate gracefully

    # Deactivate the virtual environment
    deactivate
fi

###############################################################################################
############################### vLLM sarathi-serve Benchmark #####################################
###############################################################################################

if [ $ENABLE_VLLM_SARATHI_SERVE = "ON" ]; then
    # Create virtual environment if not already created
    VENV_DIR="../venv_vllm"
    [ ! -d "$VENV_DIR" ] && python3 -m venv $VENV_DIR
    LOG_FILE="${VLLM_RESULT_FILENAME%.json}.log"

    # Activate virtual environment
    source $VENV_DIR/bin/activate

    # Function to check if a port is in use
    is_port_in_use() {
        nc -z localhost $1 >/dev/null 2>&1
        return $?
    }

    # Install vLLM if not already installed
    python -c "import vllm" &> /dev/null || pip3 install vllm xformers

    TENSOR_PARALLEL_SIZE=${TENSOR_PARALLEL_SIZE:-4}
    MAX_REQUESTS_PER_BATCH=${MAX_REQUESTS_PER_BATCH:-2048}
    MAX_NUM_BATCHED_TOKENS=${MAX_NUM_BATCHED_TOKENS:-2048}

    # Start vLLM server with tensor and pipeline parallelism
    cmd="vllm serve $LLM_MODEL --port $VLLM_SERVER_PORT --no-enable-prefix-caching --tensor-parallel-size $TENSOR_PARALLEL_SIZE --pipeline-parallel-size 1 --enable-chunked-prefill True --max-num-seqs $MAX_REQUESTS_PER_BATCH --dtype float16 --max-num-batched-tokens $MAX_NUM_BATCHED_TOKENS --max-seq-len-to-capture 2048 --disable-log-requests"
    eval "$cmd"  > "$LOG_FILE" 2>&1 &
    VLLM_PID=$!

    # Wait for vLLM server to start
    for i in {1..60}; do
        if is_port_in_use $VLLM_SERVER_PORT; then
            echo "vLLM server started on port $VLLM_SERVER_PORT."
            break
        fi
        sleep 10
        if [ $i -eq 60 ]; then
            echo "Warning: vLLM server did not start within 300 seconds."
        fi
    done

    # Run benchmark and stop server
    python ../systems/vllm/benchmarks/benchmark_serving.py --input-file $DATASETS_FILE --backend vllm \
        --model $LLM_MODEL --save-result --result-filename $VLLM_RESULT_FILENAME --port $VLLM_SERVER_PORT --baseline-latency-per-token $BASELINE_LATENCY_PER_TOKEN

    # Ensure all vLLM server processes are terminated
    echo "Stopping all vLLM server processes"
    pkill -9 pt_main_thread
    pkill -9 vllm
    pkill -9 python
    sleep 2  # Give some time for the processes to terminate gracefully

    # Deactivate the virtual environment
    deactivate
fi

###############################################################################################
############################ SpecScheduler spec_infer #########################################
###############################################################################################

# TODO: i/o format
if [ $ENABLE_SPECSCHEDULER_SPEC_INFER = "ON" ]; then
    # Set MAX_TREE_DEPTH based on model name prefix
    if [[ "$LLM_MODEL" == Qwen/Qwen2.5-32B-instruct ]]; then
        ZSIZE=100000
        MAX_TREE_DEPTH=${MAX_TREE_DEPTH:-9}
        MIN_TREE_DEPTH=${MIN_TREE_DEPTH:-2}
        SSM_LATENCY_MS=35
        LLM_LATENCY_MS=35
        MAX_TREE_WIDTH=${MAX_TREE_WIDTH:-6}
        BATCH_SIZE_TO_LATENCY_MS=${BATCH_SIZE_TO_LATENCY_MS:-"9 0 0.0 128 48.0 256 66.0 384 84.0 512 104.0 640 124.0 768 144.0 896 164.0 1024 188.0"}
    elif [[ "$LLM_MODEL" == meta-llama/llama-3.1-70b-instruct ]]; then
        ZSIZE=150000
        MAX_TREE_DEPTH=${MAX_TREE_DEPTH:-10}
        SSM_LATENCY_MS=70
        LLM_LATENCY_MS=70
        MIN_TREE_DEPTH=${MIN_TREE_DEPTH:-4}
        MAX_TREE_WIDTH=${MAX_TREE_WIDTH:-10}
        BATCH_SIZE_TO_LATENCY_MS=${BATCH_SIZE_TO_LATENCY_MS:-"9 0 0.0 128 55.0 256 85.0 384 105.0 512 125.0 640 145.0 768 165.0 896 185.0 1024 205.0"}
    elif [[ "$LLM_MODEL" == meta-llama/Llama-2-7b-chat-hf ]]; then
        MAX_TREE_DEPTH=6
        SSM_LATENCY_MS=15
        LLM_LATENCY_MS=15
        MAX_TREE_WIDTH=6
        MAX_TOKENS_PER_BATCH=192
    else
        echo -e "\e[31mUnknown model prefix. Exiting.\e[0m"
        exit 1
    fi

    TENSOR_PARALLEL_SIZE=${TENSOR_PARALLEL_SIZE:-4}
    MAX_REQUESTS_PER_BATCH=${MAX_REQUESTS_PER_BATCH:-96}
    MAX_TOKENS_PER_BATCH=${MAX_TOKENS_PER_BATCH:-1024}
    MAX_TOKENS_PER_SSM_SPEC_BATCH=${MAX_TOKENS_PER_SSM_SPEC_BATCH:-192}
    MAX_OUTPUT_LENGTH=${MAX_OUTPUT_LENGTH:-128}
    CHUNK_SIZE=${CHUNK_SIZE:-1024}
    SPEC_BATCH_SIZE=${SPEC_BATCH_SIZE:-512}
    CHUNKED_PREFILL_BUFFER_SIZE=${CHUNKED_PREFILL_BUFFER_SIZE:-128}



    echo -e "Running SpecScheduler spec_infer..."
    export Command="../systems/SpecScheduler/build/inference/spec_infer/spec_infer \
    -ll:gpu $TENSOR_PARALLEL_SIZE -ll:cpu 8 -ll:fsize 70000 -ll:zsize $ZSIZE -ll:csize 55000 -ll:util 8 \
    --fusion $USE_FULL_PRECISION -cache-folder /models/ -llm-model $LLM_MODEL -ssm-model $SSM_MODEL \
    -trace $DATASETS_FILE \
    -output-file $SPEC_INFER_OUTPUT_LOG \
    -tensor-parallelism-degree $TENSOR_PARALLEL_SIZE \
    --max-sequence-length 2048 --max-output-length $MAX_OUTPUT_LENGTH \
    --max-requests-per-batch $MAX_REQUESTS_PER_BATCH \
    --max-tokens-per-batch $MAX_TOKENS_PER_BATCH \
    --chunked-prefill \
    --chunk-size $CHUNK_SIZE \
    --spec-batch-size $SPEC_BATCH_SIZE \
    --chunked-prefill-buffer-size $CHUNKED_PREFILL_BUFFER_SIZE \
    --batch-size-2-latency-ms $BATCH_SIZE_TO_LATENCY_MS \
    --max-tree-depth $MAX_TREE_DEPTH \
    --max-tree-width $MAX_TREE_WIDTH \
    --min-tree-depth $MIN_TREE_DEPTH \
    --baseline-latency-ms $BASELINE_LATENCY_PER_TOKEN_MS \
    --ssm-spec-latency-ms $SSM_LATENCY_MS \
    --max-tokens-per-ssm-batch $MAX_TOKENS_PER_BATCH \
    --max-tokens-per-ssm-spec-batch $MAX_TOKENS_PER_SSM_SPEC_BATCH"
    

    if [ -n "$SPEC_INFER_OUTPUT_FILE" ]; then
        exec 3>&1 4>&2
        exec > $SPEC_INFER_OUTPUT_FILE 2>&1
    fi
    bash -c "$Command"
    if [ -n "$SPEC_INFER_OUTPUT_FILE" ]; then
        exec 1>&3 2>&4
        exec 3>&- 4>&-
    fi
    echo $Command
fi

###############################################################################################
############################ SpecScheduler old_version ########################################
###############################################################################################

# TODO: i/o format
if [ $ENABLE_SPECSCHEDULER_OLD_VERSION = "ON" ]; then
    echo -e "Running SpecScheduler old_version..."
    # nsys profile --stats=true --force-overwrite=true -o batch_64 \
    export Command="../systems/SpecInfer/build/inference/spec_infer/spec_infer \
    -ll:gpu 4 -ll:cpu 8 -ll:fsize 70000 -ll:zsize 150000 -ll:csize 60000 -ll:util 8 \
    --fusion $USE_FULL_PRECISION -cache-folder /models/ -llm-model $LLM_MODEL -ssm-model $SSM_MODEL \
    -trace $DATASETS_FILE -output-file $PWD/$OUTPUT_DIR/${MODEL_NAME}-${TORCH_DTYPE}-SpecScheduler_oldversion.txt \
    -tensor-parallelism-degree 4 --max-sequence-length 2048 --max-output-length $MAX_OUTPUT_LENGTH \
    --spec-infer-old-version --max-requests-per-batch 48 --max-tokens-per-batch 1024 --max-tokens-per-ssm-batch 192 \
    --max-tree-depth 8 --max-tree-width 3 \
    --baseline-latency-ms $BASELINE_LATENCY_PER_TOKEN_MS --ssm-spec-latency-ms 30 --llm-verify-latency-ms 70"
    if [ -n "$OLD_VERSION_OUTPUT_FILE" ]; then
        exec 3>&1 4>&2
        exec > $OLD_VERSION_OUTPUT_FILE 2>&1
    fi
    bash -c "$Command"
    if [ -n "$OLD_VERSION_OUTPUT_FILE" ]; then
        exec 1>&3 2>&4
        exec 3>&- 4>&-
    fi
    echo $Command
fi
