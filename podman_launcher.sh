#!/bin/bash

podname="retool"
publish_ip=$(ip route get 1 | awk '{print $NF;exit}')

# build containers
buildah bud -t retool:latest -f /opt/pusher/Dockerfile .

podman pod rm -f ${podname}
podman network create ${podname}
podman pod create --name ${podname} --hostname ${podname} -p ${publish_ip}:80:80 -p ${publish_ip}:443:443

podman run -d --name ${podname}-postgresql --hostname postgres --expose 5432 --pod ${podname} -v data:/var/lib/postgresql/data postgres:9.6.5
podman run -d --name ${podname}-user-postgres --hostname user-postgres --pod ${podname} -env-file=/opt/pusher/userData/userData.env -v user-data:/var/lib/postgresql/data --add-host postgres:127.0.0.1

podman run -d --name ${podname}-jobs-runner --hostname jobs-runner --pod ${podname} -env-file=/opt/pusher/docker.env -e SERVICE_TYPE=JOBS_RUNNER --add-host postgres:127.0.0.1 bash -c "chmod -R +x ./docker_scripts; sync; ./docker_scripts/wait-for-it.sh postgres:5432; ./docker_scripts/start_api.sh"
podman run -d --name ${podname}-db-connector --hostname db-connector --pod ${podname} -env-file=/opt/pusher/docker.env -e SERVICE_TYPE=DB_CONNECTOR_SERVICE --add-host postgres:127.0.0.1
