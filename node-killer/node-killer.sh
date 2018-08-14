#!/bin/bash
set -eu

PROJECT_NAME=${1:-$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")}
CLUSTER_NAME=${2:-$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/cluster-name" -H "Metadata-Flavor: Google")}

echo "$(date): Welcome to Node killer! Target Project: $PROJECT_NAME, Cluster: $CLUSTER_NAME"

CLUSTER_ZONE=$(gcloud --format 'value(zone)' container clusters list \
                --filter 'name='$CLUSTER_NAME)

# .basename() doesn't work
INSTANCE_GROUPS=($(basename $(gcloud --format 'value(instanceGroupUrls)' container clusters describe -z $CLUSTER_ZONE $CLUSTER_NAME )))

ALL_INSTANCES=()
ALL_ZONE_INSTANCES=()

for INSTANCE_GROUP in "${INSTANCE_GROUPS[@]}"; do
    INSTANCE_GROUP_ZONE=$(gcloud --format 'value(zone.basename())' compute instance-groups list --filter 'name='$INSTANCE_GROUP)
    echo "Instance group $INSTANCE_GROUP in $INSTANCE_GROUP_ZONE"
    INSTANCES=($(gcloud --format 'value(NAME)' compute instance-groups list-instances \
                 --zone $INSTANCE_GROUP_ZONE $INSTANCE_GROUP))
    for INSTANCE in "${INSTANCES[@]}"; do
        echo "   Instance $INSTANCE"
        # INSTANCE_ZONE=$(basename -a $(gcloud --format 'value(zone)' compute instance-groups list \
        #                                 --filter 'name='$INSTANCE_GROUP))
        ALL_INSTANCES+=($INSTANCE)
        # TODO is it always INSTANCE_GROUP_ZONE ??
        ALL_ZONE_INSTANCES+=($INSTANCE_GROUP_ZONE)
    done
done

echo
echo "All instances:"
for i in ${!ALL_INSTANCES[@]}; do
    echo "$i ${ALL_INSTANCES[$i]} ${ALL_ZONE_INSTANCES[$i]}"
done

# Roll Dice
ROLL=$(( ($RANDOM % ${#ALL_INSTANCES[@]}) ))
NODE="${ALL_INSTANCES[${ROLL}]}"
NODE_ZONE="${ALL_ZONE_INSTANCES[${ROLL}]}"

echo
echo "Chosen Node: $NODE in $NODE_ZONE"
echo
gcloud container clusters get-credentials --zone $CLUSTER_ZONE $CLUSTER_NAME
echo
echo "Pods that will be terminated:"
kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE -o wide
echo

secs=10
echo "Sleep $secs before delete; opportunity to stop delete."
while [[ $secs > 0 ]]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done

echo
echo "$(date): Time to die."

echo gcloud compute instances delete --zone $NODE_ZONE $NODE
gcloud compute instances delete -q --zone $NODE_ZONE $NODE

for i in {1..10}; do
    echo "$(date): Cluster check"
    kubectl get nodes
    echo
    kubectl get --all-namespaces pods -o wide
    echo
    sleep 20
done
