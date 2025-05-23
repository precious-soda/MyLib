#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-only

print_usage() {
    echo "Usage: docker-setup.sh"
    exit 1
}

check_error() {
    if [ $1 -ne 0 ]; then
        echo "Failed $2"
        echo "Exiting..."
        exit 1
    fi
}

setup_system() {
if ! command -v docker &> /dev/null
then
	echo "Docker is not found please install"
	exit 1
fi
}

setup_init() {
echo "Cleaning previously started containers..."

./docker-tear-down.sh

export $(grep -v '^#' .env | xargs -d '\n')

echo "Docker pruning"
docker system prune -f
docker volume prune -f

echo "Creating dir for minio volume mapping"

mkdir -p /tmp/minio-test
mkdir -p /tmp/minio-test/0
rm -rf /tmp/minio-test/0/*

ln config/telegraf/oam-telegraf.conf config/telegraf/custom/oam-telegraf.conf

}

setup_keycloak() {
./config/keycloak/certs/gen-certs.sh
echo "Starting containers for: keycloak"
envsubst  '$KEYCLOAK_IMAGE,$OPA_IMAGE,$BUNDLE_IMAGE,$IDENTITYDB_IMAGE,$HTTP_DOMAIN' < docker-compose-security.yaml > docker-compose-security_gen.yaml
docker compose -p security -f docker-compose-security_gen.yaml up -d
}

populate_keycloak(){
# Create realm in keycloak
. scripts/populate_keycloak.sh

create_realms nonrtric-realm
while [ $? -ne 0 ]; do
    create_realms nonrtric-realm
done

# Create client for admin calls
cid="console-setup"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

echo ""

cid="console-setup"
__get_admin_token
TOKEN=$(get_client_token nonrtric-realm $cid)

cid="kafka-producer-pm-xml2json"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export XML2JSON_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="pm-producer-json2kafka"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export JSON2KAFKA_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="dfc"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export DFC_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="nrt-pm-log"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export PMLOG_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="pm-rapp"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export PMRAPP_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

}

setup_common() {
echo "Starting containers for gateway"
envsubst  < docker-compose-common.yaml > docker-compose-common_gen.yaml
docker compose -p gateway -f docker-compose-common_gen.yaml up -d
}

setup_logging() {
echo "Starting containers for Logging"
envsubst  < docker-compose-logging.yaml > docker-compose-logging_gen.yaml
docker compose -p logging -f docker-compose-logging_gen.yaml up -d
}

setup_kafka() {
echo "Starting containers for: kafka, zookeeper, kafka client, minio"
envsubst  < docker-compose-msgbus.yaml > docker-compose-msgbus_gen.yaml
docker compose -p msgbus -f docker-compose-msgbus_gen.yaml up -d
}

create_docker_networks() {
echo "Creating Docker Netowrks: $DNETWORKS"
for net in $DNETWORKS; do
    docker network inspect $net 2> /dev/null 1> /dev/null
    if [ $? -ne 0 ]; then
        docker network create $net
    else
        echo "  Network: $net exits"
    fi
done
}

create_topics() {
echo "Creating topics: $TOPICS, may take a while ..."
for t in $TOPICS; do
    retcode=1
    rt=43200000
    echo "Creating topic $t with retention $(($rt/1000)) seconds"
    while [ $retcode -ne 0 ]; do
        docker exec -it common-kafka-1-1 ./bin/kafka-topics.sh \
		--create --topic $t --config retention.ms=$rt  --bootstrap-server kafka:9092
        retcode=$?
    done
done
}

setup_controller_collector() {
echo "Starting containers for: SDN Controller and VES Collector"
envsubst  < docker-compose-concol.yaml > docker-compose-concol_gen.yaml
docker compose -p sdn -f docker-compose-concol_gen.yaml up -d
}

setup_dfc() {
echo "Starting dfc"
chmod 666 config/dfc/token-cache/jwt.txt
envsubst < docker-compose-dfc.yaml > docker-compose-dfc_gen.yaml
docker compose -p dfc -f docker-compose-dfc_gen.yaml up -d
}

setup_producers() {
echo "Starting producers"
chmod 666 config/pmpr/token-cache/jwt.txt
envsubst < docker-compose-producers.yaml > docker-compose-producers_gen.yaml
docker compose -p producers -f docker-compose-producers_gen.yaml up -d
}


setup_influx() {
data_dir=./config/influxdb2/data
mkdir -p $data_dir
touch ./config/influxdb2/token.txt
envsubst < docker-compose-influxdb.yaml > docker-compose-influxdb_gen.yaml
docker compose -p influx -f docker-compose-influxdb_gen.yaml up -d
}

setup_pmlog() {
chmod 666 config/pmlog/token-cache/jwt.txt
envsubst < docker-compose-pmlog.yaml > docker-compose-pmlog_gen.yaml
docker compose -p logger -f docker-compose-pmlog_gen.yaml up -d
}

setup_metbucket() {
echo "Setup Infrastructure metrics bucket"
envsubst < docker-compose-metbucket.yaml > docker-compose-metbucket_gen.yaml
docker compose -p influxbucket -f docker-compose-metbucket_gen.yaml up -d
}

setup_telegraf() {
echo "Setup Telegraf for Infra Metrics"
envsubst < docker-compose-telegraf.yaml > docker-compose-telegraf_gen.yaml
docker compose -p telegraf -f docker-compose-telegraf_gen.yaml up -d
}

setup_grafana() {
echo "Setup Grafana for Performance Metrics"
envsubst < docker-compose-grafana.yaml > docker-compose-grafana_gen.yaml
docker compose -p grafana -f docker-compose-grafana_gen.yaml up -d
}

setup_nonrtric_basic() {
echo "Setup Non-RT-RIC Basic"
envsubst < docker-compose-nonrtric-v1.yaml > docker-compose-nonrtric-v1_gen.yaml
docker compose -p nonrtric -f docker-compose-nonrtric-v1_gen.yaml up -d
}

setup_pmrapp() {
echo "PM rapp"
envsubst < docker-compose-pmrapp.yaml > docker-compose-pmrapp_gen.yaml
docker compose -p pmrapp -f docker-compose-pmrapp_gen.yaml up -d
}

## MAIN #####
export KAFKA_NUM_PARTITIONS=10
export TOPICS="file-ready collected-file json-file-ready-kp json-file-ready-kpadp pmreports"
export DNETWORKS="smo oam dmz"

setup_system

setup_init

create_docker_networks
check_error $?

setup_common
check_error $?

setup_logging
check_error $?

setup_keycloak
check_error $?

# Wait for keycloak to start
echo 'Waiting for keycloak to be ready'
until [ $(curl -s -w '%{http_code}' -o /dev/null 'http://localhost:8462') -eq 200 ];
do
	echo -n '.'
	sleep 2
done
echo ""

populate_keycloak

setup_kafka
check_error $?

create_topics

setup_dfc
check_error $?

setup_producers
check_error $?

scripts/clean-shared-volume.sh

. scripts/get_influxdb2_token.sh

setup_influx
check_error $?

# Wait for influxdb2 to start
echo 'Waiting for influxdb2 to be ready'
until [ $(curl -s -w '%{http_code}' -o /dev/null 'http://localhost:8086/health') -eq 200 ];
do
        echo -n '.'
        sleep 1
done
echo ""

export INFLUXDB2_INSTANCE=influxdb2

INFLUXDB2_TOKEN=$(get_influxdb2_token $INFLUXDB2_INSTANCE)
echo $INFLUXDB2_TOKEN
echo $INFLUXDB2_TOKEN > ./config/influxdb2/token.txt
export INFLUXDB2_TOKEN

setup_pmlog
check_error $?

setup_controller_collector
check_error $?

setup_metbucket
check_error $?

sleep 2

setup_telegraf
check_error $?

setup_grafana
check_error $?

setup_controller_collector
check_error $?

setup_nonrtric_basic
check_error $?

setup_pmrapp
check_error $?
