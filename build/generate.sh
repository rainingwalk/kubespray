#!/bin/bash
set -eo pipefail

CURRENT_DIR=$(cd $(dirname $0); pwd)
# TEMP_DIR="${CURRENT_DIR}/temp"
TEMP_DIR="/tmp"
REPO_ROOT_DIR="${CURRENT_DIR%/build}"

: ${IMAGE_ARCH:="amd64"}
: ${ANSIBLE_SYSTEM:="linux"}
: ${ANSIBLE_ARCHITECTURE:="x86_64"}
: ${DOWNLOAD_YML:="config/group_vars/all/download.yml"}

mkdir -p ${TEMP_DIR}

# ARCH used in convert {%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%} to {{arch}}
if [ "${IMAGE_ARCH}" != "amd64" ]; then ARCH="-${IMAGE_ARCH}"; fi

cat > ${TEMP_DIR}/generate.sh << EOF
arch=${ARCH}
image_arch=${IMAGE_ARCH}
download_url=https:/
ansible_system=${ANSIBLE_SYSTEM}
ansible_architecture=${ANSIBLE_ARCHITECTURE}
registry_project=library
registry_domain=localhost
EOF

# generate all component version by $DOWNLOAD_YML

grep '_version:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
| grep -v "^#" \
| sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> ${TEMP_DIR}/generate.sh
sed -i 's/kube_major_version=.*/kube_major_version=${kube_version%.*}/g' ${TEMP_DIR}/generate.sh
sed -i 's/crictl_version=.*/crictl_version=${kube_version%.*}.0/g' ${TEMP_DIR}/generate.sh

# generate all download files url
grep '_download_url:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
| grep -v "^#" \
| sed "s#{%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%}#{{arch}}#g" \
| sed 's/: /=/g;s/ //g;s/{{/${/g;s/}}/}/g;s/|lower//g;s/^.*_url=/echo /g' >> ${TEMP_DIR}/generate.sh

# generate all images list
grep -E '_repo:|_tag:|_name:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
| grep -v "^#" \
| sed "s#{%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%}#{{arch}}#g" \
| sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> ${TEMP_DIR}/generate.sh


grep '_image_name:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
| grep -v "^#" \
| cut -d ':' -f1 | sed 's/^/echo $/g' >> ${TEMP_DIR}/generate.sh


# # special handling for https://github.com/kubernetes-sigs/kubespray/pull/7570
# sed -i 's#^coredns_image_repo=.*#coredns_image_repo=${kube_image_repo}$(if printf "%s\\n%s\\n" v1.21 ${kube_version%.*} | sort --check=quiet --version-sort; then echo -n /coredns/coredns;else echo -n /coredns; fi)#' ${TEMP_DIR}/generate.sh
# sed -i 's#^coredns_image_tag=.*#coredns_image_tag=$(if printf "%s\\n%s\\n" v1.21 ${kube_version%.*} | sort --check=quiet --version-sort; then echo -n ${coredns_version};else echo -n ${coredns_version/v/}; fi)#' ${TEMP_DIR}/generate.sh

# # add kube-* images to images list
# KUBE_IMAGES="kube-apiserver kube-controller-manager kube-scheduler kube-proxy"
# echo "${KUBE_IMAGES}" | tr ' ' '\n' | xargs -L1 -I {} \
# echo 'echo ${kube_image_repo}/{}:${kube_version}' >> ${TEMP_DIR}/generate.sh

# print files.list and images.list
# bash ${TEMP_DIR}/generate.sh | grep 'https' | sort > ${TEMP_DIR}/files.list
# bash ${TEMP_DIR}/generate.sh | grep -v 'https' | sort > ${TEMP_DIR}/images.list
