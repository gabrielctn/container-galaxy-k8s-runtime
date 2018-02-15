#!/bin/bash
set -e

DOCKER_REPO=${CONTAINER_REGISTRY+/:-}
DOCKER_USER=${CONTAINER_USER:-pcm32}

ANSIBLE_REPO=pcm32/ansible-galaxy-extras
ANSIBLE_RELEASE=3f934a1e9c39c7d03278538bb9ea0ca196976f45

TAG=v17.09_cerebellin
#NO_CACHE="--no-cache"

if [[ ! -z ${CONTAINER_TAG_PREFIX+x} ]];
then
	if [[ ! -z ${BUILD_NUMBER+x} ]]; 
	then
            TAG=${CONTAINER_TAG_PREFIX}.${BUILD_NUMBER}
        fi
fi


if [ -n $ANSIBLE_REPO ]
    then
       echo "Making custom galaxy-base-pheno:$TAG from $ANSIBLE_REPO at $ANSIBLE_RELEASE"
       docker build $NO_CACHE --build-arg ANSIBLE_REPO=$ANSIBLE_REPO --build-arg ANSIBLE_RELEASE=$ANSIBLE_RELEASE -t $DOCKER_REPO$DOCKER_USER/galaxy-base-pheno:$TAG docker-galaxy-stable/compose/galaxy-base/
       docker push $DOCKER_REPO$DOCKER_USER/galaxy-base-pheno:$TAG
fi

GALAXY_RELEASE=9a445ed999c1b168690e953d62038e79316f59d2
GALAXY_REPO=phnmnl/galaxy

if [ -n $GALAXY_REPO ]
    then
       echo "Making custom galaxy-init-pheno:$TAG from $GALAXY_REPO at $GALAXY_RELEASE"
       DOCKERFILE_INIT_1=Dockerfile
       if [ -n $ANSIBLE_REPO ]
          then
              sed s+quay.io/bgruening/galaxy-base:dev+$DOCKER_REPO$DOCKER_USER/galaxy-base-pheno:$TAG+ docker-galaxy-stable/compose/galaxy-init/Dockerfile > docker-galaxy-stable/compose/galaxy-init/Dockerfile_init
	      FROM=`grep ^FROM ../docker-galaxy-stable/compose/galaxy-init/Dockerfile_init | awk '{ print $2 }'`
	      echo "Using FROM $FROM for galaxy init"
	      DOCKERFILE_INIT_1=Dockerfile_init
       fi
       docker build $NO_CACHE --build-arg GALAXY_REPO=$GALAXY_REPO --build-arg GALAXY_RELEASE=$GALAXY_RELEASE --build-arg ISATOOLS_LITE_INSTALL=True -t $DOCKER_REPO$DOCKER_USER/galaxy-init-pheno:$TAG -f docker-galaxy-stable/compose/galaxy-init/$DOCKERFILE_INIT_1 docker-galaxy-stable/compose/galaxy-init/
       docker push $DOCKER_REPO$DOCKER_USER/galaxy-init-pheno:$TAG
fi

DOCKERFILE_INIT_FLAVOUR=Dockerfile_init
if [ -n $GALAXY_REPO ]
then
	echo "Making custom galaxy-init-pheno-flavoured:$TAG starting from galaxy-init-pheno:$TAG"
	sed s+pcm32/galaxy-init-pheno$+$DOCKER_REPO$DOCKER_USER/galaxy-init-pheno:$TAG+ Dockerfile_init > Dockerfile_init_tagged
	DOCKERFILE_INIT_FLAVOUR=Dockerfile_init_tagged
fi
docker build $NO_CACHE -t $DOCKER_REPO$DOCKER_USER/galaxy-init-pheno-flavoured:$TAG -f $DOCKERFILE_INIT_FLAVOUR .
docker push $DOCKER_REPO$DOCKER_USER/galaxy-init-pheno-flavoured:$TAG


DOCKERFILE_WEB=Dockerfile
if [ -n $GALAXY_REPO ]
then
	echo "Making custom galaxy-web-k8s:$TAG from $GALAXY_REPO at $GALAXY_RELEASE"
	sed s+quay.io/bgruening/galaxy-base:dev+$DOCKER_REPO$DOCKER_USER/galaxy-base-pheno:$TAG+ docker-galaxy-stable/compose/galaxy-web/Dockerfile > docker-galaxy-stable/compose/galaxy-web/Dockerfile_web
	DOCKERFILE_WEB=Dockerfile_web
fi
docker build --build-arg GALAXY_ANSIBLE_TAGS=supervisor,startup,scripts,nginx,k8,k8s -t $DOCKER_REPO$DOCKER_USER/galaxy-web-k8s:$TAG -f docker-galaxy-stable/compose/galaxy-web/$DOCKERFILE_WEB docker-galaxy-stable/compose/galaxy-web/
docker push $DOCKER_REPO$DOCKER_USER/galaxy-web-k8s:$TAG

echo "Relevant containers:"
echo "Web:          $DOCKER_REPO$DOCKER_USER/galaxy-web-k8s:$TAG"
echo "Init Flavour: $DOCKER_REPO$DOCKER_USER/galaxy-init-pheno-flavoured:$TAG"