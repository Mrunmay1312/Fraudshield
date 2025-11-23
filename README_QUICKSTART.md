# Quickstart (POC)

1. Unzip the project:
   unzip dissertation_poc.zip -d dissertation_poc
   cd dissertation_poc

2. Build and push images (replace REGISTRY/ORG/TAG):
   export REGISTRY=ghcr.io
   export ORG=yourorg
   export TAG=latest
   ./scripts/build_and_push_local.sh ${REGISTRY} ${ORG} ${TAG}

3. Install Strimzi (operator) then apply Kafka CRs:
   kubectl create ns kafka || true
   kubectl apply -f k8s/strimzi/  -n kafka

4. Create namespaces and apply manifests:
   kubectl create ns fraudshield || true
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/*.yaml -n fraudshield

5. Deploy monitoring:
   kubectl apply -f monitoring/ -n monitoring

6. Run Kubeflow pipeline by uploading kubeflow/pipelines/fraud_pipeline.yaml in Kubeflow UI.

Notes:
- Edit image names in k8s/*.yaml to match your registry before applying.
- Tekton pipeline in cicd/tekton can be used in-cluster to build and deploy images.
