#! /usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}/.."

docker exec -it adaserve /bin/bash
