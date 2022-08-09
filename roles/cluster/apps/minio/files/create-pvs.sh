
#! /bin/sh

#echo $1
#echo $2
#echo $3

NODES_LIST=$1 
NODES_LIST=${NODES_LIST:1:${#NODES_LIST}-2}
VOLUMES_COUNT=$2
CAPACITY_PER_COLUME=$3
pv_num_per_node=4

# Get 4 nodes at most
# NODES_NUM=`echo $NODES_LIST | awk -F',' '{print NF}'`

# #Caculate how many pvs per node
# if [[ $NODES_NUM -eq 1 || $NODES_NUM -eq 2 || $NODES_NUM -eq 4 ]]; then
# 	pv_num_per_node=$(($VOLUMES_COUNT / $NODES_NUM))
# elif [[ $NODES_NUM -eq 3 ]]; then
# 	pv_num_per_node=6
# else
#   pv_num_per_node=4   # Use 4 nodes at most
# fi

#echo $pv_num_per_node

#Create local pv
node_counter=0
for node in $NODES_LIST; do
  node_counter=$((node_counter+1))

  # Use 4 nodes at most
  if [[ $node_counter -eq 5 ]]; then
    break
  fi

	for i in $(seq 1 $pv_num_per_node); do
    trim_node_string=`echo "${node:1:${#node}-2}" | tr -d "'" `
    #echo $trim_node_string
		echo "
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-$trim_node_string-$i
  labels:
    managed-by: ansible
spec:
  capacity:
    storage: $CAPACITY_PER_COLUME
  accessModes:
  - ReadWriteOnce
  storageClassName: local-storage
  local:
    path: /data/minio/pv-$i
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $trim_node_string" | kubectl apply -f -
	done
done

# Create StorageClass
echo "
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: local-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer" | kubectl apply -f -













