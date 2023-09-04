#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
declare ns

source "$(dirname "$0")/setup.sh"

# Customization
parallelism=$1
export parallelism=$parallelism
envsubst < "$(dirname "$0")/../scenarios/customizations/load-test-0-direct.yaml" > "${SERVING}/test/performance/benchmarks/load-test/load-test-0-direct.yaml"
envsubst < "$(dirname "$0")/../scenarios/customizations/load-test-200-direct.yaml" > "${SERVING}/test/performance/benchmarks/load-test/load-test-200-direct.yaml"
envsubst < "$(dirname "$0")/../scenarios/customizations/load-test-always-direct.yaml" > "${SERVING}/test/performance/benchmarks/load-test/load-test-always-direct.yaml"

# Running the tests

################################################################################################
header "Load test: Setup"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/load-test/load-test-setup.yaml"
popd
kubectl wait --timeout=60s --for=condition=ready ksvc -n "$ns" --all

#################################################################################################
header "Load test: zero"

run_job load-test-zero "${SERVING}/test/performance/benchmarks/load-test/load-test-0-direct.yaml"

# additional clean up
kubectl delete ksvc load-test-zero -n "$ns"  --ignore-not-found=true
kubectl wait --for=delete ksvc/load-test-zero --timeout=60s -n "$ns"

##################################################################################################
header "Load test: always direct"

run_job load-test-always "${SERVING}/test/performance/benchmarks/load-test/load-test-always-direct.yaml"

# additional clean up
kubectl delete ksvc load-test-always -n "$ns"  --ignore-not-found=true
kubectl wait --for=delete ksvc/load-test-always --timeout=60s -n "$ns"

#################################################################################################
header "Load test: 200 direct"

run_job load-test-200 "${SERVING}/test/performance/benchmarks/load-test/load-test-200-direct.yaml"

# additional clean up
kubectl delete ksvc load-test-200 -n "$ns"  --ignore-not-found=true
kubectl wait --for=delete ksvc/load-test-200 --timeout=60s -n "$ns"
