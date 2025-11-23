#!/usr/bin/env bash
# deploy_openshift_dockerhub.sh
# OpenShift deployment script for Dissertation POC (FraudShield) using Docker Hub

set -euo pipefail
IFS=$'\n\t'

# -------------------------------
# DEFAULTS (can be overridden)
# -------------------------------
DOCKERHUB_USER="mrunmay1312"        # your Docker Hub username
TAG="latest"
PROJECT="fraudshield"
KAFKA_NS="kafka"
MON_NS="monitoring"
PRIVATE_IMAGES=false     # set true if Docker Hub images are private

# -------------------------------
# USAGE
# -------------------------------
usage() {
  echo ""
  echo "Usage: $0 --dockerhub-user <USER> [--tag <TAG>] [--project <PROJECT>] [--private]"
  echo ""
  echo "Options:"
  echo "  --private     Images are private on Docker Hub (creates secret in OpenShift)"
  echo ""
  echo "Example:"
  echo "  ./deploy_openshift_dockerhub.sh --dockerhub-user myuser --tag latest --private"
  echo ""
  exit 1
}

# -------------------------------
# PARSE ARGUMENTS
# -------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dockerhub-user) DOCKERHUB_USER="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --private) PRIVATE_IMAGES=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$DOCKERHUB_USER" ]]; then
  echo "ERROR: You must specify --dockerhub-user"
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
echo ">>> Using Docker Hub user: $DOCKERHUB_USER  Tag: $TAG"
echo ""

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
oc rollout status deployment/strimzi-cluster-operator -n "$KAFKA_NS" --timeout=180s || true

# -------------------------------
# CREATE KAFKA CLUSTER + TOPICS
# -------------------------------
echo ">>> Creating Kafka Cluster + Transactions topic..."
oc apply -f k8s/strimzi/fraudshield-cluster.yaml -n "$KAFKA_NS"
oc apply -f k8s/strimzi/transactions-topic.yaml -n "$KAFKA_NS"
oc apply -f k8s/strimzi/fraudshield-brokers-nodepool.yaml -n "$KAFKA_NS"

sleep 5
oc get pods -n "$KAFKA_NS"

# -------------------------------
# BUILD AND PUSH DOCKER HUB IMAGES
# -------------------------------
echo ">>> Building container images..."

ANALYZER_IMAGE="${DOCKERHUB_USER}/dissertation-fraud-analyzer:${TAG}"
INGEST_IMAGE="${DOCKERHUB_USER}/dissertation-transaction-ingestor:${TAG}"
RULE_IMAGE="${DOCKERHUB_USER}/dissertation-rule-engine:${TAG}"
ALERT_IMAGE="${DOCKERHUB_USER}/dissertation-alert-service:${TAG}"

echo ">>> Fraud Analyzer → $ANALYZER_IMAGE"
docker build -t "$ANALYZER_IMAGE" services/fraud_analyzer
docker push "$ANALYZER_IMAGE"

echo ">>> Transaction Ingestor (Quarkus) → $INGEST_IMAGE"
pushd services/transaction_ingestor
mvn clean package -Dquarkus.package.type=fast-jar
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
# CREATE SECRET FOR PRIVATE IMAGES
# -------------------------------
if [ "$PRIVATE_IMAGES" = true ]; then
  echo ">>> Creating Docker Hub pull secret for OpenShift..."
  oc create secret docker-registry dockerhub-secret \
    --docker-username="$DOCKERHUB_USER" \
    --docker-password="$(read -s -p "Docker Hub password or token: " PASS; echo $PASS)" \
    --docker-email="you@example.com" \
    -n "$PROJECT" || true
  oc secrets link default dockerhub-secret --for=pull -n "$PROJECT"
fi

# -------------------------------
# PATCH YAML WITH IMAGE NAMES
# -------------------------------
echo ">>> Patching deployment YAMLs with Docker Hub image names..."

sed -i "s|REPLACE_IMAGE|${ANALYZER_IMAGE}|g" k8s/fraud-analyzer-deploy.yaml
sed -i "s|REPLACE_IMAGE|${INGEST_IMAGE}|g" k8s/transaction-ingestor-deploy.yaml
sed -i "s|REPLACE_IMAGE|${RULE_IMAGE}|g" k8s/rule-engine-deploy.yaml
sed -i "s|REPLACE_IMAGE|${ALERT_IMAGE}|g" k8s/alert-deploy.yaml

# -------------------------------
# DEPLOY MICROSERVICES
# -------------------------------
echo ">>> Deploying microservices to OpenShift..."
oc apply -n "$PROJECT" -f k8s/fraud-analyzer-deploy.yaml
oc apply -n "$PROJECT" -f k8s/transaction-ingestor-deploy.yaml
oc apply -n "$PROJECT" -f k8s/rule-engine-deploy.yaml
oc apply -n "$PROJECT" -f k8s/alert-deploy.yaml
oc apply -n "$PROJECT" -f k8s/fraud-analyzer-service.yaml
oc apply -n "$PROJECT" -f k8s/transaction-ingestor-service.yaml
oc apply -n "$PROJECT" -f k8s/rule-engine-service.yaml
oc apply -n "$PROJECT" -f k8s/alert-service.yaml
sleep 10
oc get pods -n "$PROJECT"

# -------------------------------
# EXPOSE SERVICES
# -------------------------------
echo ">>> Creating OpenShift Routes..."
oc expose service fraud-analyzer -n "$PROJECT" || true
oc expose service transaction-ingestor -n "$PROJECT" || true
oc expose service rule-engine -n "$PROJECT" || true
oc expose service alert-service -n "$PROJECT" || true

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
oc get routes -n "$PROJECT"
oc get routes -n "$MON_NS" | grep grafana || true
oc get routes -n "$MON_NS" | grep jaeger || true
echo ""
echo "Next: Upload Kubeflow pipeline and test end-to-end flow."

