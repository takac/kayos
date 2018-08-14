# Node Killer

A script to run on your GKE cluster that will select a node at random from the
GKE cluster and delete that node. Typically the instance groups that comprise
a GKE cluster are managed instances groups, this means that a deleted node will
be automatically recreated. See [GCP Instance Groups - Managed Instance
Groups](https://cloud.google.com/compute/docs/instance-groups/#managed_instance_groups)
for more info.

### Architecture

Bash & YAML!

Node killer leverages the `google/cloud-sdk` image which contains the `gcloud`
and `kubectl` bins. Rather than building a new docker image the script is
mounted into the container through a configmap. This reduces the burden on
hosting your own docker images or trusting someone else's.

Node killer is deployed as a Kubernetes `job`, meaning it will run once to
completion. It requires a GCP service account to read and delete the required
resources. The service account key is mounted into the container in a json
file.

### Install

To run on your cluster you will need to create a service account that has
privileges to read and write to compute resources and read GKE. This only needs
to be run once.

```
export PROJECT_ID="$(gcloud config get-value project -q)"
export GOOGLE_APPLICATION_CREDENTIALS=$PWD/node-killer-svc-acc.json
export SVC_ACCOUNT=node-killer-svc-acc

gcloud iam service-accounts create node-killer-svc-acc
gcloud iam service-accounts keys create node-killer-svc-acc.json \
    --iam-account node-killer-svc-acc@$PROJECT_ID.iam.gserviceaccount.com
# TODO Reduce privileges!
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${SVC_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/owner
```
Create a Kubernetes `secret` from the json svc account.

```
kubectl create secret generic node-killer-svc-acc-key \
    --from-file=key.json=$GOOGLE_APPLICATION_CREDENTIALS
```

Deploy node killer as a job to the cluster.

```
kubectl create configmap node-killer.sh --from-file=node-killer.sh
kubectl apply -f job.yml
```

Delete node killer job and the config map:
```
kubectl delete job node-killer
kubectl delete configmap node-killer.sh
```
