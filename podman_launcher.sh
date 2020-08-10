#!/bin/bash

podname="retool"
publish_ip=$(ip route get 1 | awk '{print $NF;exit}')

# build containers
buildah bud -t retool:latest -f /opt/retool/Dockerfile .

podman pod rm -f ${podname}
podman network create ${podname}
podman pod create --name ${podname} --hostname ${podname} -p ${publish_ip}:80:80 -p ${publish_ip}:443:443

podman run -d --name ${podname}-postgresql --hostname postgres --expose 5432 --pod ${podname} -v data:/var/lib/postgresql/data postgres:9.6.5
podman run -d --name ${podname}-user-postgres --hostname user-postgres --pod ${podname} -env-file=/opt/pusher/userData/userData.env -v user-data:/var/lib/postgresql/data --add-host postgres:127.0.0.1
podman run -d --name ${podname}-jobs-runner --hostname jobs-runner --pod ${podname} -env-file=/opt/pusher/docker.env -e SERVICE_TYPE=JOBS_RUNNER --add-host postgres:127.0.0.1 retool:latest bash -c "chmod -R +x ./docker_scripts; sync; ./docker_scripts/wait-for-it.sh postgres:5432; ./docker_scripts/start_api.sh"
podman run -d --name ${podname}-db-connector --hostname db-connector --pod ${podname} -env-file=/opt/pusher/docker.env -e SERVICE_TYPE=DB_CONNECTOR_SERVICE --add-host postgres:127.0.0.1 retool:latest
podman run -d --name ${podname}-https-portal --hostname https-portal --pod ${podname} --expose 80 --expose 443 -env-file=/opt/pusher/docker.env -e STAGE=local --add-host api:127.0.0.1 retool:latest
podman run -d --name ${podname}-db-ssh-connector --hostname db-ssh-connector --pod ${podname} -env-file=/opt/pusher/docker.env -e SERVICE_TYPE=DB_SSH_CONNECTOR_SERVICE -v ssh:/retool_backend/autogen_ssh_keys -v /opt/pusher/keys:/retool_backend/keys retool:latest
podman run -d --name ${podname}-api --hostname api --pod ${podname} -env-file=/opt/pusher/docker.env -e SERVICE_TYPE=MAIN_BACKEND -e DB_CONNECTOR_HOST=http://db-connector -e DB_CONNECTOR_PORT=3002 -e DB_SSH_CONNECTOR_HOST=http://db-ssh-connector -e DB_SSH_CONNECTOR_PORT=3002 --add-host postgres:127.0.0.1 --add-host db-connector:127.0.0.1 --add-host db-ssh-connector:127.0.0.1 --expose 3000 -v ssh:/retool_backend/autogen_ssh_keys -v /opt/pusher/keys:/retool_backend/keys retool:latest bash -c "./docker_scripts/wait-for-it.sh postgres:5432; ./docker_scripts/start_api.sh"
