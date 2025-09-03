#!/bin/bash

# Cd into directory holding this script
cd "${BASH_SOURCE[0]%/*}"
REPO_DIR=$(pwd)/../../

export INPUT_DIR=$REPO_DIR/exps/fig11/
export OUTPUT_DIR=$REPO_DIR/results/fig11/llama/

export LLM_MODEL=meta-llama/llama-3.1-70b-instruct
export MODEL_NAME=llama-3.1-70b-instruct
export SSM_MODEL=meta-llama/llama-3.2-1b-instruct
export TENSOR_PARALLEL_SIZE=8
export VLLM_USE_V1=0

SLO_SCALE_MIN=${SLO_SCALE_MIN:-0.6}
SLO_SCALE_MAX=${SLO_SCALE_MAX:-1.6}
SLO_SCALE_STEP=${SLO_SCALE_STEP:-0.2}

ADASERVE=${ADASERVE:-OFF}
VLLM=${VLLM:-OFF}
VLLM_SPEC=${VLLM_SPEC:-OFF}
VLLM_SARATHI=${VLLM_SARATHI:-OFF}

OUTPUT_LENGTH=${OUTPUT_LENGTH:-128}
TEST_SCRIPT=${TEST_SCRIPT:-$REPO_DIR/exps/test.sh}

# ADASERVE
if [ "$ADASERVE" == "ON" ]; then
    for SLO_SCALE in $(seq $SLO_SCALE_MIN $SLO_SCALE_STEP $SLO_SCALE_MAX); do
        RESULT_DIR=${OUTPUT_DIR}/adaserve

        if [ ! -d "$RESULT_DIR" ]; then
            mkdir -p $RESULT_DIR
        fi

        export SPEC_INFER_OUTPUT_FILE=${RESULT_DIR}/slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.txt
        export SPEC_INFER_OUTPUT_LOG=${SPEC_INFER_OUTPUT_FILE%.txt}.log
        export DATASETS_FILE=$INPUT_DIR/emission_slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.json

        # If the output file already exists, skip the run
        if [ -f "$SPEC_INFER_OUTPUT_FILE" ]; then
            echo "Output file $SPEC_INFER_OUTPUT_FILE already exists. Skipping this run."
            continue
        fi

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
        ENABLE_SPECSCHEDULER_SPEC_INFER=ON $TEST_SCRIPT
    done
fi

# VLLM
if [ "$VLLM" == "ON" ]; then
    RESULT_DIR=${OUTPUT_DIR}/vllm

    if [ ! -d "$RESULT_DIR" ]; then
        mkdir -p $RESULT_DIR
    fi

    SLO_SCALE=1.0

    export VLLM_RESULT_FILENAME=$RESULT_DIR/slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.txt
    export DATASETS_FILE=$INPUT_DIR/emission_slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.json

    # If the output file already exists, skip the run
    if [ -f "$VLLM_RESULT_FILENAME" ]; then
        echo "Output file $VLLM_RESULT_FILENAME already exists. Skipping this run."
        continue
    fi

    ENABLE_VLLM_SERVER_BENCHMARK=ON $TEST_SCRIPT
fi

# VLLM SPEC
if [ "$VLLM_SPEC" == "ON" ]; then
    SLO_SCALE=1.0

    for NST in 4 6 8; do
        RESULT_DIR=${OUTPUT_DIR}/vllm_spec

        if [ ! -d "$RESULT_DIR" ]; then
            mkdir -p $RESULT_DIR
        fi

        export VLLM_RESULT_FILENAME=$RESULT_DIR/slo${SLO_SCALE}_nst${NST}_ol${OUTPUT_LENGTH}.txt
        export DATASETS_FILE=$INPUT_DIR/emission_slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.json

        # If the output file already exists, skip the run
        if [ -f "$VLLM_RESULT_FILENAME" ]; then
            echo "Output file $VLLM_RESULT_FILENAME already exists. Skipping this run."
            continue
        fi

        NUM_SPEC_TOKENS=${NST} \
        ENABLE_VLLM_SPEC_INFER=ON $TEST_SCRIPT
    done
fi

# VLLM SARATHI
if [ "$VLLM_SARATHI" == "ON" ]; then
    RESULT_DIR=${OUTPUT_DIR}/sarathi

    if [ ! -d "$RESULT_DIR" ]; then
        mkdir -p $RESULT_DIR
    fi

    SLO_SCALE=1.0

    export VLLM_RESULT_FILENAME=$RESULT_DIR/slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.txt
    export DATASETS_FILE=$INPUT_DIR/emission_slo${SLO_SCALE}_ol${OUTPUT_LENGTH}.json

    # If the output file already exists, skip the run
    if [ -f "$VLLM_RESULT_FILENAME" ]; then
        echo "Output file $VLLM_RESULT_FILENAME already exists. Skipping this run."
        continue
    fi

    ENABLE_VLLM_SARATHI_SERVE=ON $TEST_SCRIPT
fi