#!/bin/bash
set -e
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 REGISTRY ORG TAG"
  exit 1
fi
REGISTRY=$1
ORG=$2
TAG=$3

echo "Building fraud-analyzer..."
docker build -t ${REGISTRY}/${ORG}/dissertation-fraud-analyzer:${TAG} services/fraud_analyzer
echo "Pushing..."
docker push ${REGISTRY}/${ORG}/dissertation-fraud-analyzer:${TAG}

echo "Building transaction-ingestor..."
cd services/transaction_ingestor
mvn -DskipTests package
docker build -t ${REGISTRY}/${ORG}/dissertation-transaction-ingestor:${TAG} -f Dockerfile .
docker push ${REGISTRY}/${ORG}/dissertation-transaction-ingestor:${TAG}
cd -

echo "Building rule-engine..."
docker build -t ${REGISTRY}/${ORG}/dissertation-rule-engine:${TAG} services/rule_engine
docker push ${REGISTRY}/${ORG}/dissertation-rule-engine:${TAG}

echo "Building alert-service..."
docker build -t ${REGISTRY}/${ORG}/dissertation-alert-service:${TAG} services/alert_service
docker push ${REGISTRY}/${ORG}/dissertation-alert-service:${TAG}

echo "Done."
