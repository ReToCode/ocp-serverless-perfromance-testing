# OpenShift Serverless Performance Testing

## Setup

### Environment
```bash
export KO_DOCKER_REPO=quay.io/rlehmann
export SYSTEM_NAMESPACE=knative-serving
export KO_DEFAULTPLATFORMS=linux/amd64
export SERVING=/Users/rlehmann/code/knative/serving
```

### Influx DB
```bash
kubectl create ns influx
oc apply -f ./yaml/ocp-hack.yaml
helm upgrade --install -n influx local-influx --set persistence.enabled=false,ingress.enabled=true,ingress.hostname=influx.apps.rlehmann-ocp.serverless.devcluster.openshift.com influxdata/influxdb2
export INFLUX_URL=http://influx.apps.rlehmann-ocp.serverless.devcluster.openshift.com
echo $(kubectl get secret local-influx-influxdb2-auth -o "jsonpath={.data['admin-token']}" --namespace influx | base64 --decode)
echo $(kubectl get secret local-influx-influxdb2-auth -o "jsonpath={.data['admin-password']}" --namespace influx | base64 --decode)
export INFLUX_TOKEN=$(kubectl get secret local-influx-influxdb2-auth -o "jsonpath={.data['admin-token']}" --namespace influx | base64 --decode)
$SERVING/test/performance/visualization/setup-influx-db.sh
```

### Backing up InfluxDB
Only relevant on demand (if you want to save the data):
```bash
export INFLUX_URL=http://influx.apps.rlehmann-ocp.serverless.devcluster.openshift.com
influx backup --host=$INFLUX_URL backup
```

### Grafana
```bash
# Setup grafana
oc apply -f yaml/grafana-subscription.yaml
oc apply -f yaml/grafana.yaml
echo $(kubectl get secret grafana-admin-credentials -o "jsonpath={.data['GF_SECURITY_ADMIN_PASSWORD']}" --namespace influx | base64 --decode)
```

Using influxDB as a datasource for Grafana
* Navigate to Grafana UI and log in using the user from above (e.g. https://grafana-route-influx.apps.rlehmann-ocp.serverless.devcluster.openshift.com/)
* Create a new datasource for InfluxDB
* Select the flux query language
* Server-URL: http://local-influx-influxdb2.influx:80
* Organization: Knativetest
* Bucket: knative-serving
* Token: <your influx-db token>


## Manually creating Knative Services
```bash
kubectl create ns knative-performance
for i in {1..1000}
do
   kn service create "hello-go-$i" --image=gcr.io/knative-samples/helloworld-go -n knative-performance &
done
```

## Running the tests in the scenarios

### Cluster setup: small

```bash
# Scale machines
for name in $(oc get machineset -n openshift-machine-api -o name); do oc scale $name -n openshift-machine-api --replicas=2; done

# Set resource scenario
## TODO
oc apply -f scenarios/knative-serving-minimal.yaml

# hack to stop HPA from interfering - this is optional (depending on tests)
oc scale deploy -n openshift-serverless knative-operator-webhook --replicas=0
oc -n knative-serving patch hpa activator --patch '{"spec":{"minReplicas":1, "maxReplicas": 1}}'
oc -n knative-serving patch hpa webhook --patch '{"spec":{"minReplicas":1, "maxReplicas": 1}}'
```

**Running the tests: small**

TODO


### Cluster setup: Limits
This scenario is just to find the limits of the system.

```bash
# Scale machines
for name in $(oc get machineset -n openshift-machine-api -o name); do oc scale $name -n openshift-machine-api --replicas=4; done
oc wait --for=jsonpath={.status.availableReplicas}=4 machineset --all -n openshift-machine-api --timeout=-1s

# Set resource scenario
oc apply -f scenarios/knative-serving-limits.yaml

# hack to stop HPA from interfering - this is optional (depending on tests)
oc scale deploy -n openshift-serverless knative-operator-webhook --replicas=0
oc -n knative-serving patch hpa activator --patch '{"spec":{"minReplicas":10, "maxReplicas": 10}}'
oc -n knative-serving patch hpa webhook --patch '{"spec":{"minReplicas":2, "maxReplicas": 2}}'

# optional patch for reconciliation-delay
oc patch cm config-autoscaler -n knative-serving -p '{"data": {"allow-zero-initial-scale": "true"}}'

# optional if we have issues here
oc scale deploy -n knative-serving-ingress 3scale-kourier-gateway --replicas=20
```

**Running the tests: limits**
Running the tests needs some tweaks, because one calling pod is not enough:

```bash
# for local debugging only
export ARTIFACTS=$PWD/logs
name= xxx; stern -n default --selector=job-name="$name" | tee "$ARTIFACTS/stern-$name.log"
```

```bash
# Environment
export KO_DOCKER_REPO=quay.io/rlehmann
export SYSTEM_NAMESPACE=knative-serving
export KO_DEFAULTPLATFORMS=linux/amd64
export SERVING=/Users/rlehmann/code/knative/serving
export INFLUX_URL=http://local-influx-influxdb2.influx:80
export ARTIFACTS=$PWD/logs

# You can run the tests individually
./scripts/run-reconciliation-delay.sh "1000ms"  # frequency (default=5s)

./scripts/run-load-test.sh 5 # parallelism (default=1)

./scripts/run-rollout-probe.sh 200 250 # min-replicas, max-replicas (defaults: 100, 150)

./scripts/run-dataplane-probe.sh 15 # parallelism (default=1)

./scripts/run-real-traffic-test.sh
```
