#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
declare ns

source "$(dirname "$0")/setup.sh"

# Customization
minscale=$1
maxscale=$2
export minscale=$minscale
export maxscale=$maxscale
envsubst < "$(dirname "$0")/../scenarios/customizations/rollout-probe-setup-activator-direct-lin.yaml" > "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-setup-activator-direct-lin.yaml"
envsubst < "$(dirname "$0")/../scenarios/customizations/rollout-probe-setup-queue-proxy-direct.yaml" > "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-setup-queue-proxy-direct.yaml"

# Running the tests

#################################################################################################
header "Rollout probe: activator direct lin"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-setup-activator-direct-lin.yaml"
popd
kubectl wait --timeout=800s --for=condition=ready ksvc -n "$ns" --all

run_job rollout-probe-activator-direct-lin "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-activator-direct-lin.yaml"

# additional clean up
kubectl delete ksvc activator-with-cc-lin -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/activator-with-cc-lin --timeout=60s -n "$ns"

##################################################################################################
header "Rollout probe: queue-proxy direct"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-setup-queue-proxy-direct.yaml"
popd
kubectl wait --timeout=800s --for=condition=ready ksvc -n "$ns" --all

run_job rollout-probe-queue-direct "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-queue-proxy-direct.yaml"

# additional clean up
kubectl delete ksvc queue-proxy-with-cc -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/queue-proxy-with-cc --timeout=60s -n "$ns"

