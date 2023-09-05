#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
declare ns

source "$(dirname "$0")/setup.sh"

# Running the tests

################################################################################################
header "Real traffic test"

run_job real-traffic-test "${SERVING}/test/performance/benchmarks/real-traffic-test/real-traffic-test.yaml"
