#!/usr/bin/env bash
set -eo pipefail

TYPE=$1
NODES=$2

KUBE_ROOT="$(cd "$(dirname "$0")" && pwd)"

: ${TYPE:=deploy-cluster}
: ${ANSIBLE_FORKS:=10}
: ${BECOME_USER:=root}
: ${ANSIBLE_LOG_FORMAT:=yaml}
: ${INVENTORY:=${KUBE_ROOT}/config/inventory}
: ${ENV_FILE:=${KUBE_ROOT}/config/env.yml}
: ${INSTALL_STEPS_FILE:=${KUBE_ROOT}/config/.steps}

source ${ENV_FILE}
export ANSIBLE_STDOUT_CALLBACK=${ANSIBLE_LOG_FORMAT}
export ANSIBLE_ARGS="-f ${ANSIBLE_FORKS} --become --become-user=${BECOME_USER} -i ${INVENTORY} -e @${ENV_FILE}"
timestamps=$(date +%Y%m%d-%H%M%S)
steps=('01-bootstrap'
       '02-cluster-etcd'
       '03-cluster-kubernetes'
       '04-cluster-apps'
       '05-custom-apps'
       '06-apps-patches'
)

# Set logging colors
NORMAL_COL=$(tput sgr0)
RED_COL=$(tput setaf 1)
WHITE_COL=$(tput setaf 7)
GREEN_COL=$(tput setaf 76)
YELLOW_COL=$(tput setaf 202)

debuglog(){ printf "${WHITE_COL}%s${NORMAL_COL}\n" "$@"; }
infolog(){ printf "${GREEN_COL}✔ %s${NORMAL_COL}\n" "$@"; }
warnlog(){ printf "${YELLOW_COL}➜ %s${NORMAL_COL}\n" "$@"; }
errorlog(){ printf "${RED_COL}✖ %s${NORMAL_COL}\n" "$@"; }

if [[ ! -f ${INVENTORY} ]]; then
  errorlog "${INVENTORY} file is missing, please check the inventory file is exists"
  exit 1
fi

check_nodename(){
  if [[ ${NODES} ]]; then
    for node in ${NODES/,/ }; do
      if ! grep ${node} ${INVENTORY}; then
        warnlog "Not found ${node} in ${INVENTORY} please check $NODES is correct"
        exit 1
      fi
    done
  fi
}

render_inventory(){

    if [ "${skip_render_config}" != "true" ]; then
        [ -f $CONFIG_FILE ] && mv $CONFIG_FILE "${CONFIG_FILE%/*}/.${CONFIG_FILE##*/}.$timestamps"
        python $current_dir/inventory/inventoryinit.py $hosts
    fi
}

deploy_cluster(){
    # touch breakpoint file
    if [ ! -f $steps_file ]; then
        touch $steps_file
        for step in ${steps[@]}; do
            echo "$step=true" >>$steps_file
        done
    fi

    # run playbook step by step
    total=${#steps[@]}
    for index in ${!steps[@]}; do
        count=$((index + 1))
        step=${steps[$index]}
        if [ $(grep -c "$step=true" $steps_file) -ne '0' -a $(grep -c "$step=successed" $steps_file) -eq '0' ]; then
            echo "($count/$total) Starting setup $step..."
            [ "$DEBUG" == "true" ] && ANSIBLE_ARGS="${ANSIBLE_ARGS} -vvv"
            infolog "######  start deploy ${step}  ######"
            ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/playbooks/${step}.yml       
            if [ $? -eq 0 ] && (! tac ansible.log | grep '< PLAY RECAP >' -m 1 -B1000 | grep -E "[ ][ ]*failed=[^0][ ][ ]*" >/dev/null); then
                sed -i "s/$step=true/$step=successed/g" $steps_file
                infolog "######  ${step} successfully installed  ######"
            else
                errorlog "######  ${step} installation failed  ######"
                exit 1
            fi
        elif [ $(grep -c "$step=successed" $steps_file) -ne '0' ]; then
            warnlog "###### ($count/$total) $step already installed, skipping... ######"
        fi
    done
}

main(){
  case $TYPE in
    deploy-cluster)
      infolog "######  start deploy kubernetes cluster  ######"
      deploy_cluster
      infolog "######  kubernetes cluster successfully installed  ######"
      ;;
    remove-cluster)
      infolog "######  start remove kubernetes cluster  ######"
      if ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/reset.yml >/dev/stdout 2>/dev/stderr; then
        rm -f ${INSTALL_STEP_FILE}
        infolog "######  kubernetes cluster successfully removed ######"
      fi
      ;;
    add-node)
      check_nodename
      infolog "######  start add worker to kubernetes cluster  ######"
      ansible-playbook ${ANSIBLE_ARGS} --limit="${NODES}" ${KUBE_ROOT}/playbooks/98-scale-nodes.yml >/dev/stdout 2>/dev/stderr
      ;;ef
    remove-node)
      check_nodename
      infolog "######  start remove worker from kubernetes cluster  ######"
      ansible-playbook ${ANSIBLE_ARGS} -e node="${NODES}" -e reset_nodes=true ${KUBE_ROOT}/remove-node.yml >/dev/stdout 2>/dev/stderr
      ;;
    *)
      errorlog "unknow [TYPE] parameter: ${TYPE}"
      ;;
  esac
}

main "$@"
