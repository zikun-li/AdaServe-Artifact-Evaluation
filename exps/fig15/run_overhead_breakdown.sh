#!/bin/bash

# Cd into directory holding this script
cd "${BASH_SOURCE[0]%/*}"
REPO_DIR=$(pwd)/../../

export INPUT_DIR=$REPO_DIR/exps/fig15/
export OUTPUT_DIR=$REPO_DIR/results/fig15/llama/
export LLM_MODEL=meta-llama/llama-3.1-70b-instruct
export MODEL_NAME=llama-3.1-70b-instruct
export SSM_MODEL=meta-llama/llama-3.2-1b-instruct
export TENSOR_PARALLEL_SIZE=8
export BASELINE_LATENCY_PER_TOKEN_MS=30
export BASELINE_LATENCY_PER_TOKEN=0.030

OUTPUT_LENGTH=${OUTPUT_LENGTH:-128}
TEST_SCRIPT=${TEST_SCRIPT:-$REPO_DIR/exps/test.sh}

ADASERVE_OVERHEAD=${ADASERVE_OVERHEAD:-OFF}
QWEN_OVERHEAD=${QWEN_OVERHEAD:-OFF}

# ADASERVE OVERHEAD BREAKDOWN - LLAMA
if [ "$ADASERVE_OVERHEAD" == "ON" ]; then
    RESULT_DIR=${OUTPUT_DIR}/adaserve_overhead

    if [ ! -d "$RESULT_DIR" ]; then
        mkdir -p $RESULT_DIR
    fi

    export SPEC_INFER_OUTPUT_FILE=${RESULT_DIR}/rps3.6_ol128.txt
    export SPEC_INFER_OUTPUT_LOG=${SPEC_INFER_OUTPUT_FILE%.txt}.log
    export DATASETS_FILE=$INPUT_DIR/emission_rps3.6_ol128.json

    # If the output file already exists, skip the run
    if [ -f "$SPEC_INFER_OUTPUT_FILE" ]; then
        echo "Output file $SPEC_INFER_OUTPUT_FILE already exists. Skipping this run."
    else
        MAX_OUTPUT_LENGTH=$OUTPUT_LENGTH
        MAX_REQUESTS_PER_BATCH=96
        MAX_TOKENS_PER_SSM_SPEC_BATCH=96
        MAX_TREE_DEPTH=8
        MAX_TREE_WIDTH=3
        MIN_TREE_DEPTH=4
        CHUNK_SIZE=1024
        SPEC_BATCH_SIZE=512

        MAX_OUTPUT_LENGTH=$MAX_OUTPUT_LENGTH \
        MAX_TOKENS_PER_SSM_SPEC_BATCH=$MAX_TOKENS_PER_SSM_SPEC_BATCH \
        MAX_TOKENS_PER_SSM_BATCH=$MAX_TOKENS_PER_SSM_BATCH \
        MAX_TREE_DEPTH=$MAX_TREE_DEPTH \
        MAX_TREE_WIDTH=$MAX_TREE_WIDTH \
        MIN_TREE_DEPTH=$MIN_TREE_DEPTH \
        MAX_REQUESTS_PER_BATCH=$MAX_REQUESTS_PER_BATCH \
        CHUNK_SIZE=$CHUNK_SIZE \
        SPEC_BATCH_SIZE=$SPEC_BATCH_SIZE \
        ENABLE_SPECSCHEDULER_SPEC_INFER_OVERHEAD_BREAKDOWN=ON $TEST_SCRIPT
    fi
fi

# ADASERVE OVERHEAD BREAKDOWN - QWEN
if [ "$QWEN_OVERHEAD" == "ON" ]; then
    # Save LLaMA config
    LLAMA_OUTPUT_DIR=$OUTPUT_DIR
    
    # Set Qwen config
    export OUTPUT_DIR=$REPO_DIR/results/fig15/qwen/
    export LLM_MODEL=Qwen/Qwen2.5-32B-instruct
    export MODEL_NAME=Qwen/Qwen2.5-32B-instruct
    export SSM_MODEL=Qwen/Qwen2.5-0.5B-instruct
    export TENSOR_PARALLEL_SIZE=4
    export BASELINE_LATENCY_PER_TOKEN_MS=28
    export BASELINE_LATENCY_PER_TOKEN=0.028
    
    RESULT_DIR=${OUTPUT_DIR}/adaserve_overhead

    if [ ! -d "$RESULT_DIR" ]; then
        mkdir -p $RESULT_DIR
    fi

    export SPEC_INFER_OUTPUT_FILE=${RESULT_DIR}/rps3.6_ol128.txt
    export SPEC_INFER_OUTPUT_LOG=${SPEC_INFER_OUTPUT_FILE%.txt}.log
    export DATASETS_FILE=$INPUT_DIR/emission_rps3.6_ol128.json

    # If the output file already exists, skip the run
    if [ -f "$SPEC_INFER_OUTPUT_FILE" ]; then
        echo "Output file $SPEC_INFER_OUTPUT_FILE already exists. Skipping this run."
    else
        MAX_OUTPUT_LENGTH=$OUTPUT_LENGTH
        MAX_REQUESTS_PER_BATCH=80
        MAX_TOKENS_PER_SSM_SPEC_BATCH=80
        MAX_TREE_DEPTH=5
        MAX_TREE_WIDTH=3
        MIN_TREE_DEPTH=3
        CHUNK_SIZE=1024
        SPEC_BATCH_SIZE=256

        MAX_OUTPUT_LENGTH=$MAX_OUTPUT_LENGTH \
        MAX_TOKENS_PER_SSM_SPEC_BATCH=$MAX_TOKENS_PER_SSM_SPEC_BATCH \
        MAX_TOKENS_PER_SSM_BATCH=$MAX_TOKENS_PER_SSM_BATCH \
        MAX_TREE_DEPTH=$MAX_TREE_DEPTH \
        MAX_TREE_WIDTH=$MAX_TREE_WIDTH \
        MIN_TREE_DEPTH=$MIN_TREE_DEPTH \
        MAX_REQUESTS_PER_BATCH=$MAX_REQUESTS_PER_BATCH \
        CHUNK_SIZE=$CHUNK_SIZE \
        SPEC_BATCH_SIZE=$SPEC_BATCH_SIZE \
        ENABLE_SPECSCHEDULER_SPEC_INFER_OVERHEAD_BREAKDOWN=ON $TEST_SCRIPT
    fi
    
    # Restore LLaMA config
    export OUTPUT_DIR=$LLAMA_OUTPUT_DIR
fi