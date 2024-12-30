#!/bin/bash

echo "[INFO] Starting portainer"
docker compose --file .devcontainer/ops/docker-compose.yml --env-file .devcontainer/ops/.env up -d
