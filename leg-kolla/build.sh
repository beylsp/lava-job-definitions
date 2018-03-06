#!/bin/bash
# build dependencies on Debian:
# git build-essential virtualenv python-dev libffi-dev libssl-dev

kolla_branch=${BRANCH}
kolla_ldc=${DEVCLOUD}
kolla_options=

if [ -z "${kolla_branch}" ]; then
    kolla_branch=master
    kolla_tag=rocky-$(date +"%Y%m%d") # use YYYYMMDD for tags
else
    if [ -z "${kolla_ldc}" ]; then
        kolla_tag=queens-$(date +"%Y%m%d") # use YYYYMMDD for tags
    else
        kolla_tag=ldc-queens-$(date +"%Y%m%d") # use YYYYMMDD for tags
        kolla_options="--template-override ./Linaro-overlay/linaro-override.j2 --docker-dir ./Linaro-overlay/docker/"
    fi
fi

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

rm -rf ${WORKSPACE}/*

git clone --depth 1 --branch ${kolla_branch} https://git.openstack.org/openstack/kolla

if [ -n ${kolla_ldc} ]; then
    git clone --depth 1 https://git.linaro.org/leg/sdi/kolla/ldc-overlay.git Linaro-overlay
fi

virtualenv --python=/usr/bin/python2 venv-for-kolla
. venv-for-kolla/bin/activate

cd kolla

pip install -r requirements.txt

mkdir -p logs/debian-source

kolla_namespace=linaro
./tools/build.py --base debian \
                 --format none \
                 ${kolla_options} \
                 --logs-dir logs/debian-source \
                 --pull \
                 --push \
                 --retries 0 \
                 --tag ${kolla_tag} \
                 --type source \
                 --namespace ${kolla_namespace} || true

docker images | grep ${kolla_tag} | sort

# remove all images as they are pushed to hub.docker.com and won't be used
# do in a loop as we remove in random order and some have children images
for run in 1 2 3 4 5
do
    docker images | grep ${kolla_tag} | awk '{print $3}' | xargs docker rmi -f 2>&1 >/dev/null || true
done
