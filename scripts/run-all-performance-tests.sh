#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

declare ns

source "$(dirname "$0")/setup.sh"

###############################################################################################
header "Real traffic test"

run_job real-traffic-test "${SERVING}/test/performance/benchmarks/real-traffic-test/real-traffic-test.yaml"
sleep 100 # wait a bit for the cleanup to be done

##############################################################################################
header "Dataplane probe: Setup"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-setup.yaml"
popd
kubectl wait --timeout=60s --for=condition=ready ksvc -n "$ns" --all
kubectl wait --timeout=60s --for=condition=available deploy -n "$ns" deployment

#############################################################################################
header "Dataplane probe: deployment"

run_job dataplane-probe-deployment "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-deployment.yaml"

# additional clean up
kubectl delete deploy deployment -n "$ns" --ignore-not-found=true
kubectl delete svc deployment -n "$ns" --ignore-not-found=true
kubectl wait --for=delete deploy/deployment --timeout=60s -n "$ns"
kubectl wait --for=delete svc/deployment --timeout=60s -n "$ns"

#############################################################################################
header "Dataplane probe: activator"

run_job dataplane-probe-activator "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-activator.yaml"

# additional clean up
kubectl delete ksvc activator -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/activator --timeout=60s -n "$ns"

##############################################################################################
header "Dataplane probe: queue proxy"

run_job dataplane-probe-queue "${SERVING}/test/performance/benchmarks/dataplane-probe/dataplane-probe-queue.yaml"

# additional clean up
kubectl delete ksvc queue-proxy -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/queue-proxy --timeout=60s -n "$ns"

##############################################################################################
header "Reconciliation delay test"

run_job reconciliation-delay "${SERVING}/test/performance/benchmarks/reconciliation-delay/reconciliation-delay.yaml"
##############################################################################################
header "Scale from Zero test"

run_job scale-from-zero-1 "${SERVING}/test/performance/benchmarks/scale-from-zero/scale-from-zero-1.yaml"
kubectl delete ksvc -n "$ns" --all --wait --now
sleep 5 # wait a bit for the cleanup to be done

run_job scale-from-zero-5 "${SERVING}/test/performance/benchmarks/scale-from-zero/scale-from-zero-5.yaml"
kubectl delete ksvc -n "$ns" --all --wait --now
sleep 25 # wait a bit for the cleanup to be done

run_job scale-from-zero-25 "${SERVING}/test/performance/benchmarks/scale-from-zero/scale-from-zero-25.yaml"
kubectl delete ksvc -n "$ns" --all --wait --now
sleep 50 # wait a bit for the cleanup to be done

run_job scale-from-zero-100 "${SERVING}/test/performance/benchmarks/scale-from-zero/scale-from-zero-100.yaml"
kubectl delete ksvc -n "$ns" --all --wait --now
sleep 100 # wait a bit for the cleanup to be done

###############################################################################################
header "Load test: Setup"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/load-test/load-test-setup.yaml"
popd
kubectl wait --timeout=60s --for=condition=ready ksvc -n "$ns" --all

################################################################################################
header "Load test: zero"

run_job load-test-zero "${SERVING}/test/performance/benchmarks/load-test/load-test-0-direct.yaml"

 additional clean up
kubectl delete ksvc load-test-zero -n "$ns"  --ignore-not-found=true
kubectl wait --for=delete ksvc/load-test-zero --timeout=60s -n "$ns"

#################################################################################################
header "Load test: always direct"

run_job load-test-always "${SERVING}/test/performance/benchmarks/load-test/load-test-always-direct.yaml"

# additional clean up
kubectl delete ksvc load-test-always -n "$ns"  --ignore-not-found=true
kubectl wait --for=delete ksvc/load-test-always --timeout=60s -n "$ns"

################################################################################################
header "Load test: 200 direct"

run_job load-test-200 "${SERVING}/test/performance/benchmarks/load-test/load-test-200-direct.yaml"

# additional clean up
kubectl delete ksvc load-test-200 -n "$ns"  --ignore-not-found=true
kubectl wait --for=delete ksvc/load-test-200 --timeout=60s -n "$ns"
###############################################################################################
header "Rollout probe: activator direct"

pushd "$SERVING"
ko apply --sbom=none -Bf "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-setup-activator-direct.yaml"
popd
kubectl wait --timeout=800s --for=condition=ready ksvc -n "$ns" --all

run_job rollout-probe-activator-direct "${SERVING}/test/performance/benchmarks/rollout-probe/rollout-probe-activator-direct.yaml"

# additional clean up
kubectl delete ksvc activator-with-cc -n "$ns" --ignore-not-found=true
kubectl wait --for=delete ksvc/activator-with-cc --timeout=60s -n "$ns"

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

success
