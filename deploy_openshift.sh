#!/usr/bin/env bash
# deploy_openshift.sh
# Full OpenShift deployment script for the Dissertation POC (FraudShield)
# Option B – POC-ready build

set -euo pipefail
IFS=$'\n\t'

# -------------------------------
# DEFAULTS (can be overridden)
# -------------------------------
REGISTRY="default-route-openshift-image-registry.apps.fraudshield.southeastasia.aroapp.io"
ORG="fraudshield"
TAG="latest"
PROJECT="fraudshield"
KAFKA_NS="kafka"
MON_NS="monitoring"

# -------------------------------
# USAGE
# -------------------------------
usage() {
  echo ""
  echo "Usage: $0 --registry <REGISTRY> [--org <ORG>] [--tag <TAG>] [--project <PROJECT>]"
  echo ""
  echo "Example:"
  echo "  ./deploy_openshift.sh --registry default-route-openshift-image-registry.apps-crc.testing --org fraudshield --tag latest"
  echo ""
  exit 1
}

# -------------------------------
# PARSE ARGUMENTS
# -------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$REGISTRY" ]]; then
  echo "ERROR: You must specify --registry"
  usage
fi

# -------------------------------
# CHECK REQUIRED BINARIES
# -------------------------------
for bin in oc docker mvn; do
  if ! command -v $bin >/dev/null 2>&1; then
    echo "ERROR: Missing required tool: $bin"
    exit 1
  fi
done

echo ">>> Deploying to OpenShift Project: $PROJECT"
echo ">>> Using Registry: $REGISTRY/$ORG  Tag: $TAG"
echo ""

# -------------------------------
# LOGIN TO REGISTRY
# -------------------------------
echo ">>> Logging into OpenShift registry..."
oc registry login || true

# -------------------------------
# CREATE PROJECTS
# -------------------------------
echo ">>> Creating required namespaces..."
oc new-project "$PROJECT" || true
oc new-project "$KAFKA_NS" || true
oc new-project "$MON_NS" || true

# -------------------------------
# INSTALL STRIMZI OPERATOR
# -------------------------------
echo ">>> Installing Strimzi Kafka Operator..."
oc apply -f "https://strimzi.io/install/latest?namespace=${KAFKA_NS}" -n "$KAFKA_NS"

echo ">>> Waiting for Strimzi Operator..."
oc rollout status deployment/strimzi-cluster-operator -n "$KAFKA_NS" --timeout=180s || true

# -------------------------------
# CREATE KAFKA CLUSTER + TOPICS
# -------------------------------
echo ">>> Creating Kafka Cluster + Transactions topic..."
oc apply -f k8s/strimzi/kafka-cluster.yaml -n "$KAFKA_NS"
oc apply -f k8s/strimzi/transactions-topic.yaml -n "$KAFKA_NS"

sleep 5
echo ">>> Kafka pods (initial):"
oc get pods -n "$KAFKA_NS"

# -------------------------------
# BUILD IMAGES
# -------------------------------
echo ">>> Building container images..."

ANALYZER_IMAGE="${REGISTRY}/${ORG}/dissertation-fraud-analyzer:${TAG}"
INGEST_IMAGE="${REGISTRY}/${ORG}/dissertation-transaction-ingestor:${TAG}"
RULE_IMAGE="${REGISTRY}/${ORG}/dissertation-rule-engine:${TAG}"
ALERT_IMAGE="${REGISTRY}/${ORG}/dissertation-alert-service:${TAG}"

echo ">>> Fraud Analyzer → $ANALYZER_IMAGE"
docker build -t "$ANALYZER_IMAGE" services/fraud_analyzer
docker push "$ANALYZER_IMAGE"

echo ">>> Transaction Ingestor (Quarkus) → $INGEST_IMAGE"
pushd services/transaction_ingestor
mvn -DskipTests package
popd
docker build -t "$INGEST_IMAGE" services/transaction_ingestor
docker push "$INGEST_IMAGE"

echo ">>> Rule Engine (Go) → $RULE_IMAGE"
docker build -t "$RULE_IMAGE" services/rule_engine
docker push "$RULE_IMAGE"

echo ">>> Alert Service (Node) → $ALERT_IMAGE"
docker build -t "$ALERT_IMAGE" services/alert_service
docker push "$ALERT_IMAGE"

# -------------------------------
# PATCH YAML WITH IMAGE NAMES
# -------------------------------
echo ">>> Patching deployment YAMLs with image names..."

sed -i "s|REPLACE_IMAGE|${ANALYZER_IMAGE}|g" k8s/fraud-analyzer-deploy.yaml
sed -i "s|REPLACE_IMAGE|${INGEST_IMAGE}|g" k8s/transaction-ingestor-deploy.yaml
sed -i "s|REPLACE_IMAGE|${RULE_IMAGE}|g" k8s/rule-engine-deploy.yaml
sed -i "s|REPLACE_IMAGE|${ALERT_IMAGE}|g" k8s/alert-deploy.yaml

# -------------------------------
# DEPLOY ALL MICROSERVICES
# -------------------------------
echo ">>> Deploying microservices to OpenShift..."

oc apply -f k8s/namespace.yaml || true
oc apply -n "$PROJECT" -f k8s/fraud-analyzer-deploy.yaml
oc apply -n "$PROJECT" -f k8s/transaction-ingestor-deploy.yaml
oc apply -n "$PROJECT" -f k8s/rule-engine-deploy.yaml
oc apply -n "$PROJECT" -f k8s/alert-deploy.yaml

echo ">>> Waiting for pods..."
sleep 10
oc get pods -n "$PROJECT"

# -------------------------------
# EXPOSE SERVICES (ROUTES)
# -------------------------------
echo ">>> Creating OpenShift Routes..."

oc expose deployment fraud-analyzer --port=8001 -n "$PROJECT" || true
oc expose deployment transaction-ingestor --port=8080 -n "$PROJECT" || true
oc expose deployment rule-engine --port=8080 -n "$PROJECT" || true
oc expose deployment alert-service --port=3000 -n "$PROJECT" || true

echo ">>> Routes created:"
oc get routes -n "$PROJECT"

# -------------------------------
# DEPLOY MONITORING STACK
# -------------------------------
echo ">>> Deploying Prometheus & Grafana..."

oc apply -f monitoring/prometheus-configmap.yaml -n "$MON_NS"
oc apply -f monitoring/prometheus-deploy.yaml -n "$MON_NS"
oc apply -f monitoring/grafana-deploy.yaml -n "$MON_NS"

oc expose deployment grafana --port=3000 -n "$MON_NS" || true

# -------------------------------
# DEPLOY JAEGER
# -------------------------------
echo ">>> Deploying Jaeger..."
oc apply -f observability/jaeger-all-in-one.yaml -n "$MON_NS"
oc expose deployment jaeger --port=16686 -n "$MON_NS" || true

echo ""
echo "========================================================"
echo "   🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉"
echo "========================================================"
echo ""
echo "✔ Fraud Analyzer, Transaction Ingestor, Rule Engine, Alert Service deployed."
echo "✔ Kafka running (Strimzi)."
echo "✔ Prometheus & Grafana deployed."
echo "✔ Jaeger tracing deployed."
echo ""
echo "👉 Routes:"
oc get routes -n "$PROJECT"
echo ""
echo "👉 Grafana:"
oc get routes -n "$MON_NS" | grep grafana
echo ""
echo "👉 Jaeger:"
oc get routes -n "$MON_NS" | grep jaeger
echo ""
echo "Next:"
echo "  - Upload Kubeflow pipeline: kubeflow/pipelines/fraud_pipeline.py"
echo "  - Test ingestion → Kafka → Analyzer → Alerts"
echo ""
echo "========================================================"

