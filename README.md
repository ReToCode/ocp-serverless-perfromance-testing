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
$SERVING/test/performance/influx/setup-influx-db.sh
```

### Grafana
```bash
# Setup grafana
oc apply -f yaml/grafana-subscription.yaml
oc apply -f yaml/grafana.yaml
echo $(kubectl get secret grafana-admin-credentials -o "jsonpath={.data['GF_SECURITY_ADMIN_PASSWORD']}" --namespace influx | base64 --decode)

# https://grafana-route-influx.apps.rlehmann-ocp.serverless.devcluster.openshift.com/
# Configure influx as DB with flux language: http://local-influx-influxdb2.influx:80
```


### Cluster setup
```bash
# Scale machines
for name in $(oc get machineset -n openshift-machine-api -o name); do oc scale $name -n openshift-machine-api --replicas=2; done

# Optional (depending on tests)
oc scale deploy -n openshift-serverless knative-operator-webhook --replicas=0
# Optional (depending on tests)
oc -n knative-serving patch hpa activator --patch '{"spec":{"minReplicas":2, "maxReplicas": 20}}'
```

## Running the tests

```bash
export INFLUX_URL=http://local-influx-influxdb2.influx:80
export ARTIFACTS=$PWD/logs
$SERVING/test/performance/performance-tests-mako.sh
```

## Backing up the InfluxDB
```bash
export INFLUX_URL=http://influx.apps.rlehmann-ocp.serverless.devcluster.openshift.com
influx backup --host=$INFLUX_URL backup
```
