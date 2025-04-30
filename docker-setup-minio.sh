#!/bin/bash

setup_minio() {
    echo "Creating dir for minio volume mapping"
    mkdir -p /tmp/minio-test/0
    rm -rf /tmp/minio-test/0/*

    echo "Starting MinIO"
    envsubst < docker-compose-minio.yaml > docker-compose-minio_gen.yaml
    docker compose -p minio -f docker-compose-minio_gen.yaml up -d
}

setup_minio
check_error $?
