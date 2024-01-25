#!/bin/bash
set -e

function usage(){
    echo "Usage: $0 <up|up-bg|down|dn|logs|logs-apache|logs-flask-app|logs-flask|logs-app>"
    exit 1
}

function cleanup(){
    echo ""
    echo "Cleaning up ..."

    # copy .log directory files to .log.bak if exists
    [ -d .log ] && cp -r .log .log.bak
    rm -rf .log
    # rm -rf ./ssl
}

COMMAND="$1"
case "$COMMAND" in
    "build")
        docker compose -f docker-compose.yaml build --no-cache
        # docker compose -f docker-compose.yaml build 
        ;;
    "up")
        cleanup

        # docker compose -f docker-compose.yaml build --no-cache
        docker compose -f docker-compose.yaml up --remove-orphans
        ;;
    "up-bg")
        cleanup
        docker compose -f docker-compose.yaml up --build -d --remove-orphans
        ;;
    "down"|"dn")
        docker compose -f docker-compose.yaml down
        ;;
    "logs")
        docker compose -f docker-compose.yaml logs -f
        ;;
    "logs-apache")
        docker compose -f docker-compose.yaml logs apache-server -f
        ;;
    "logs-flask-app"| "logs-flask"| "logs-app")
        docker compose -f docker-compose.yaml logs flask-app -f
        ;;
    *)
        usage
        ;;
esac