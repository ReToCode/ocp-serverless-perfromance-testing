#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/setup.sh"

header "Reconciliation delay test"

scenario=$1
file="$SERVING/test/performance/benchmarks/reconciliation-delay/reconciliation-delay.yaml"

cp -f "$(dirname "$0")/../scenarios/$scenario/reconciliation-delay.yaml" "$file"

run_job reconciliation-delay "$file"
