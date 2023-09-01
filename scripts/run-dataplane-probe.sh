#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
declare ns

source "$(dirname "$0")/setup.sh"

header "Dataplane probe: Setup"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-setup.yaml"
popd
kubectl wait --timeout=60s --for=condition=ready ksvc -n "$ns" --all
kubectl wait --timeout=60s --for=condition=available deploy -n "$ns" deployment


header "Dataplane probe: deployment"

run_job dataplane-probe-deployment "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-deployment.yaml"

# additional clean up
kubectl delete deploy deployment -n "$ns" --ignore-not-found=true
kubectl delete svc deployment -n "$ns" --ignore-not-found=true
kubectl wait --for=delete deploy/deployment --timeout=60s -n "$ns"
kubectl wait --for=delete svc/deployment --timeout=60s -n "$ns"


header "Dataplane probe: activator"

run_job dataplane-probe-activator "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-activator.yaml"

# additional clean up
kubectl delete ksvc activator -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/activator --timeout=60s -n "$ns"


header "Dataplane probe: queue proxy"

run_job dataplane-probe-queue "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-queue.yaml"

# additional clean up
kubectl delete ksvc queue-proxy -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/queue-proxy --timeout=60s -n "$ns"
