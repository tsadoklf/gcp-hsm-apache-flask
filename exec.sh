#!/bin/bash
set -e

# Usage ./docker/build.sh [build|run]

function cleanup(){
    echo ""
    echo "Cleaning up ..."
    rm -rf ./log
    rm -rf ./ssl
}

IMAGE_NAME="my-flask-app"

COMMAND="$1"
case "$COMMAND" in
    "build")
        echo "Building Docker image ..."
        docker build -t $IMAGE_NAME -f docker/Dockerfile .
        ;;
    "run")
        cleanup

        docker compose -f docker-compose.yaml up --build 
        ;;
    "run-bg")
        docker compose -f docker-compose.yaml up --build -d
        ;;
    *)
        echo "Usage: $0 [build|run]"
        exit 1
        ;;
esac