#!/usr/bin/env bash

function isPong() {

    if [[ $(kubectl get po -n kube-system | grep monitor-agent | wc -l) -lt 2 ]]; then
        echo "No need to do for single machine "
        exit 1
    fi
    source=$(kubectl get po -n kube-system | grep monitor-agent | awk '{print $1}' | head -n 1)
    for element in $(kubectl get po -n kube-system -owide | grep monitor-agent | awk '{print $6}'); do
        kubectl exec -it $source -n kube-system -- ping -c 1 -W 2 $element
        if [[ $? -eq 1 ]]; then
            echo "$element is not connected"
            return 2
        fi
    done
    echo "calico network is connected"
    exit 0
}

function toCrossSubnet() {
    if [[ $(kubectl get ippools -o yaml | grep 'ipipMode' | wc -l) -gt 0 ]]; then

        echo "ippools, calico-config(cm), calico-node(ds) FelixConfiguration need to deal with"

        calicoctl get ippools -o yaml |sed 's/ipipMode.*/ipipMode: CrossSubnet/g' | sed 's/vxlanMode.*/vxlanMode: Never/g' | calicoctl apply -f -
        if [[ $? -eq 0 ]]; then
            if [[ $(calicoctl get FelixConfiguration -oyaml | grep 'ipipEnabled' | wc -l) -gt 0 ]]; then
                calicoctl get FelixConfiguration -oyaml | sed 's/ipipEnabled.*/ipipEnabled: true/' | calicoctl apply -f -
            fi
            sleep 1
            if [[ $(calicoctl get FelixConfiguration -oyaml | grep 'vxlanEnabled' | wc -l) -gt 0 ]]; then
                calicoctl get FelixConfiguration -oyaml | sed 's/vxlanEnabled.*/vxlanEnabled: false/' | calicoctl apply -f -
            fi
            if [[ $(kubectl get cm -n kube-system calico-config -oyaml | grep 'calico_backend' | wc -l) -gt 0 ]]; then
                kubectl get cm -n kube-system calico-config -oyaml | sed 's/calico_backend.*/calico_backend: bird/' | kubectl apply -f -
            fi
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_IPIP' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed 's/CALICO_IPV4POOL_VXLAN/CALICO_IPV4POOL_IPIP/' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_VXLAN' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/CALICO_IPV4POOL_VXLAN/{n;s/value.*/value: Never/;}' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_IPIP' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/CALICO_IPV4POOL_IPIP/{n;s/value.*/value: CrossSubnet/;}' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'bird-live' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/felix-live/a\            - -bird-live' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'bird-ready' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/felix-ready/a\            - -bird-ready' | kubectl apply -f -
            fi
            kubectl get po -n kube-system | grep calico-node | awk '{print "kubectl delete po -n kube-system "$1}' | bash

            echo "calico switched to CrossSubnet mode"
        fi
    fi
}

function toIPIP() {
    if [[ $(kubectl get ippools -o yaml | grep 'ipipMode' | wc -l) -gt 0 ]]; then

        echo "ippools, calico-config(cm), calico-node(ds) FelixConfiguration need to deal with"
        calicoctl get ippools -o yaml |sed 's/ipipMode.*/ipipMode: Always/g' | sed 's/vxlanMode.*/vxlanMode: Never/g' | calicoctl apply -f -
        if [[ $? -eq 0 ]]; then
            if [[ $(calicoctl get FelixConfiguration -oyaml | grep 'ipipEnabled' | wc -l) -gt 0 ]]; then
                calicoctl get FelixConfiguration -oyaml | sed 's/ipipEnabled.*/ipipEnabled: true/' | calicoctl apply -f -
            fi
            sleep 1
            if [[ $(calicoctl get FelixConfiguration -oyaml | grep 'vxlanEnabled' | wc -l) -gt 0 ]]; then
                calicoctl get FelixConfiguration -oyaml | sed 's/vxlanEnabled.*/vxlanEnabled: false/' | calicoctl apply -f -
            fi
            if [[ $(kubectl get cm -n kube-system calico-config -oyaml | grep 'calico_backend' | wc -l) -gt 0 ]]; then
                kubectl get cm -n kube-system calico-config -oyaml | sed 's/calico_backend.*/calico_backend: bird/' | kubectl apply -f -
            fi
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_IPIP' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed 's/CALICO_IPV4POOL_VXLAN/CALICO_IPV4POOL_IPIP/' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_VXLAN' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/CALICO_IPV4POOL_VXLAN/{n;s/value.*/value: Never/;}' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_IPIP' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/CALICO_IPV4POOL_IPIP/{n;s/value.*/value: Always/;}' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'bird-live' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/felix-live/a\            - -bird-live' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'bird-ready' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/felix-ready/a\            - -bird-ready' | kubectl apply -f -
            fi

            kubectl get po -n kube-system | grep calico-node | awk '{print "kubectl delete po -n kube-system "$1}' | bash

            echo "calico switched to IPIP mode"
        fi
    fi
}

function toVXLAN() {

    if [[ $(calicoctl get ippools -o yaml | grep 'vxlanMode' | wc -l) -gt 0 ]]; then
        echo "ippools, calico-config(cm), calico-node(ds) FelixConfiguration need to deal with"
        calicoctl get ippools -o yaml | sed 's/ipipMode.*/ipipMode: Never/g' | sed 's/vxlanMode: Never/vxlanMode: Always/g' | calicoctl apply -f -
        if [[ $? -eq 0 ]]; then
            if [[ $(calicoctl get FelixConfiguration -oyaml | grep 'ipipEnabled' | wc -l) -gt 0 ]]; then
                calicoctl get FelixConfiguration -oyaml | sed 's/ipipEnabled.*/ipipEnabled: false/' | calicoctl apply -f -
            fi
            sleep 1
            if [[ $(calicoctl get FelixConfiguration -oyaml | grep 'vxlanEnabled' | wc -l) -gt 0 ]]; then
                calicoctl get FelixConfiguration -oyaml | sed 's/vxlanEnabled.*/vxlanEnabled: true/' | calicoctl apply -f -
            fi
            if [[ $(kubectl get cm -n kube-system calico-config -oyaml | grep 'calico_backend' | wc -l) -gt 0 ]]; then
                kubectl get cm -n kube-system calico-config -oyaml | sed 's/calico_backend.*/calico_backend: vxlan/' | kubectl apply -f -
            fi
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_VXLAN' | wc -l) -eq 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed 's/CALICO_IPV4POOL_IPIP/CALICO_IPV4POOL_VXLAN/' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_VXLAN' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/CALICO_IPV4POOL_VXLAN/{n;s/value.*/value: Always/;}' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'CALICO_IPV4POOL_IPIP' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/CALICO_IPV4POOL_IPIP/{n;s/value.*/value: Never/;}' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'bird-live' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/bird-live/d' | kubectl apply -f -
            fi
            sleep 1
            if [[ $(kubectl get ds -n kube-system calico-node -o yaml | grep 'bird-ready' | wc -l) -gt 0 ]]; then
                kubectl get ds -n kube-system calico-node -o yaml | sed '/bird-ready/d' | kubectl apply -f -
            fi

            kubectl get po -n kube-system | grep calico-node | awk '{print "kubectl delete po -n kube-system "$1}' | bash
            echo "calico switched to VXLAN mode"
        fi
    fi
}

function main() {

    if [[ "${1,,}" == "ipip" ]]; then
        toIPIP
        sleep 60
        isPong
        exit
    fi
    if [[ "${1,,}" == "vxlan" ]]; then
        toVXLAN
        sleep 60
        isPong
        exit
    fi
    if [[ "${1,,}" == "crosssubnet" ]]; then
        toCrossSubnet
        sleep 60
        isPong
        exit
    fi
    isPong
    if [[ $? -ge 1 ]]; then
        toCrossSubnet
        sleep 60
        isPong
    fi
    if [[ $? -ge 1 ]]; then
        toIPIP
        sleep 60
        isPong
    fi
    sleep 60
    isPong
    if [[ $? -ge 1 ]]; then
        toVXLAN
        sleep 60
        isPong
    fi
}

main $@