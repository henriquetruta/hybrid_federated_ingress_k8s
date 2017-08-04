for node in $(kubectl get nodes --context=aws -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=aws label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/region=us-east-2
  kubectl --context=aws label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=us-east-2a
done


for node in $(kubectl get nodes --context=azure -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=azure label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/region=us-west-1 --overwrite
  kubectl --context=azure label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=us-west-1a --overwrite
done

for node in $(kubectl get nodes --context=local -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=local label nodes ${node}  failure-domain.beta.kubernetes.io/region=europe-west-1
  kubectl --context=local label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=europe-west-1b
done

failure-domain.beta.kubernetes.io/region=us-west-1
failure-domain.beta.kubernetes.io/zone=us-west-1a

failure-domain.beta.kubernetes.io/region=europe-west-1
failure-domain.beta.kubernetes.io/zone=europe-west-1b



kubectl --context aws delete \
    rc/default-http-backend \
    rc/nginx-ingress-controller \
    svc/default-http-backend
kubectl --context azure delete \
    rc/default-http-backend \
    rc/nginx-ingress-controller \
    svc/default-http-backend
kubectl --context local delete \
    rc/default-http-backend \
    rc/nginx-ingress-controller \
    svc/default-http-backend

kubectl get deploy --context=gke -n kube-system l7-default-backend -o yaml > deploy_l7_default_backend.yaml
kubectl get svc --context=gke -n kube-system default-http-backend -o yaml > svc_default_http_backend.yaml
kubectl get cm --context=gke -n kube-system ingress-uid -o yaml > cm_ingress_uid.yaml

  # Replace by new ones taken from GKE
kubectl --context aws create -f deploy_l7_default_backend.yaml,svc_default_http_backend.yaml,cm_ingress_uid.yaml
kubectl --context azure create -f deploy_l7_default_backend.yaml,svc_default_http_backend.yaml,cm_ingress_uid.yaml
kubectl --context local create -f deploy_l7_default_backend.yaml,svc_default_http_backend.yaml,cm_ingress_uid.yaml