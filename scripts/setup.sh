#!/usr/bin/env bash

declare SERVING
if [[ -z "${SERVING}" ]]; then
  echo "env variable 'SERVING' not specified!"
  exit 1
fi

source "$SERVING/test/e2e-common.sh"

set -o errexit
set -o nounset
set -o pipefail

declare JOB_NAME
declare BUILD_ID
declare ARTIFACTS

ns="default"

function run_job() {
  local name=$1
  local file=$2

  # cleanup from old runs
  kubectl delete job "$name" -n "$ns" --ignore-not-found=true

  # start the load test and get the logs
  pushd "$SERVING"
  sed "s|@SYSTEM_NAMESPACE@|$SYSTEM_NAMESPACE|g" "$file" | sed "s|@KO_DOCKER_REPO@|$KO_DOCKER_REPO|g" | ko apply --sbom=none -Bf -
  popd

  sleep 5

  # Follow logs to wait for job termination
  kubectl wait --for=condition=ready -n "$ns" pod --selector=job-name="$name" --timeout=-1s
  kubectl logs -n "$ns" -f "job.batch/$name"

  # Dump logs to a file to upload it as CI job artifact
  kubectl logs -n "$ns" "job.batch/$name" >"$ARTIFACTS/$name.log"

  # clean up
  kubectl delete "job/$name" -n "$ns" --ignore-not-found=true
  kubectl wait --for=delete "job/$name" --timeout=60s -n "$ns"
}

export JOB_NAME="local"
export BUILD_ID="local"

if [[ -z "${INFLUX_URL}" ]]; then
  echo "env variable 'INFLUX_URL' not specified!"
  exit 1
fi
if [[ -z "${INFLUX_TOKEN}" ]]; then
  echo "env variable 'INFLUX_TOKEN' not specified!"
  exit 1
fi

echo "Running load test with BUILD_ID: ${BUILD_ID}, JOB_NAME: ${JOB_NAME}, reporting results to: ${INFLUX_URL}"

###############################################################################################
header "Preparing cluster config"

kubectl delete secret performance-test-config -n "$ns" --ignore-not-found=true
kubectl create secret generic performance-test-config -n "$ns" \
  --from-literal=influxurl="${INFLUX_URL}" \
  --from-literal=influxtoken="${INFLUX_TOKEN}" \
  --from-literal=jobname="${JOB_NAME}" \
  --from-literal=buildid="${BUILD_ID}"

echo ">> Upload the test images"
pushd "$SERVING"
ko resolve --sbom=none -RBf test/test_images/autoscale > /dev/null
ko resolve --sbom=none -RBf test/test_images/helloworld > /dev/null
ko resolve --sbom=none -RBf test/test_images/slowstart > /dev/null
popd

