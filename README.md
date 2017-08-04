# Hybrid Federated Ingress on Kubernetes

Setting up a Hybrid Federated Ingress on Kubernetes

### Assumptions

This tutorial assumes you have:

* Access to your Google cloud via `gcloud`
* AWS Credentials (aws\_access\_key\_id and aws\_secret\_access\_key)
* `kubefed` and `kubectl` installed (I used version 1.6.4)

### Define your zone in your DNS provider

Godaddy + Digital ocean

### Create google cluster and zone

```bash
# Creating a zone
gcloud dns managed-zones create fed \
  --description "Kubernetes federation testing" \
  --dns-name henriquetruta.com
# Spin up a GKE cluster
gcloud container clusters create gke \
  --zone=us-east1-b \
  --scopes "cloud-platform,storage-ro,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite" \
  --num-nodes=2
```

### Create AWS cluster

* Install conjure-up
* Run it
* Select kubernetes canonical, put password, deploy and wait

### Create Azure Cluster

* Setup your azure credentials and the `az` CLI tool
* Create the cluster with the following commands:

```bash
az group create --name k8s --location eastus
az acs create --orchestrator-type=kubernetes --resource-group k8s --name=azure --agent-count 1
```

### Get your credentials

#### AWS

```bash
juju scp kubernetes-master/0:/home/ubuntu/config ./config-aws
```

This command will download the file `config-aws` with your AWS credentials.

#### GKE

Go into your Dashboard, in the Container Engine page click in `Connect` on
your cluster. Then, copy the first command. It should look like:

```bash
# Gets the credentials and copies them to ~/.kube/config
gcloud container clusters get-credentials gke --zone us-east1-b --project fed

```

#### Azure

```bash
# Gets the credentials in similar way to gcloud
az acs kubernetes get-credentials --resource-group=k8s --name=azure
```

#### Merge them all

Then, merge them in your local kubeconfig file, having contexts called just
`gke`, `azure` and `aws`.

### Label your nodes

If you have contexts called just `gke`, `aws` and `azure`, you can run the `labeling.sh` file.

```bash
source labeling.sh
```

```bash
for node in $(kubectl get nodes --context=aws -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=aws label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/region=eu-west-2
  kubectl --context=aws label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=eu-west-2a
done

for node in $(kubectl get nodes --context=gke -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=gke label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/region=us-east1
  kubectl --context=gke label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=us-east1
done
```

### Making sure clusters share the same GLBC

```bash
# Delete old ones
kubectl --context aws delete \
    rc/default-http-backend \
    rc/nginx-ingress-controller \
    svc/default-http-backend

# Take the ones currently used in GKE and save them
kubectl get deploy --context=gke -n kube-system l7-default-backend -o yaml > deploy_l7_default_backend.yaml
kubectl get svc --context=gke -n kube-system default-http-backend -o yaml > svc_default_http_backend.yaml
kubectl get cm --context=gke -n kube-system ingress-uid -o yaml > cm_ingress_uid.yaml

  # Replace by new ones taken from GKE
kubectl --context aws create -f deploy_l7_default_backend.yaml
kubectl --context aws create -f svc_default_http_backend.yaml
kubectl --context aws create -f cm_ingress_uid.yaml
```

## Initializing the Federation

Now, you can create the federation by using `kubefed init` command.
This Federation will be hosted by our cluster called `gke`, using `google-clouddns` as DNS provider,
and will use your previously registered domain (fed.henriquetruta.com in my case). To create it, just run:

```bash
kubectl config use-context gke
kubefed init fed --host-cluster-context=gke --dns-zone-name="henriquetruta.com." --dns-provider=google-clouddns
```

Wait a few seconds, and if you're lucky enough (I know you are), your federation control plane is deployed and
your API server is running. Now, you should join clusters to the Federation.

```bash
$ kubectl config use-context fed
Switched to context "fed".

# add GKE cluster itself
kubefed join gke --host-cluster-context=gke
cluster "gke" created

# create a clusterrolebinding for aws cluster
kubectl --context=gke create clusterrolebinding federation-controller-manager:fed-aws-gke  \
--serviceaccount=federation-system:aws-gke --clusterrole=federation-controller-manager:fed-gke-gke 

kubectl create clusterrolebinding permissive-binding \
  --clusterrole=cluster-admin \
  --user=admin \
  --user=kubelet \
  --user=kubeconfig \
  --user=client \
  --group=system:serviceaccounts

# add AWS
kubefed join aws --host-cluster-context=gke
cluster "aws" created

```

## Creating the DNS configmap

```bash
kubectl create -f cm_dns.yaml --context=fed
```

Now, you can run a Federated Application.

## References

[1] [Experimenting with Cross Cloud Kubernetes Cluster Federation](https://medium.com/google-cloud/experimenting-with-cross-cloud-kubernetes-cluster-federation-dfa99f913d54)

[2] [Cluster Federation and Global Load Balancing on Kubernetes and Google Cloud — Part 1](https://medium.com/google-cloud/planet-scale-microservices-with-cluster-federation-and-global-load-balancing-on-kubernetes-and-a8e7ef5efa5e)
