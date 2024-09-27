#!/bin/bash
## Install tools and dependencies for the project.
## This script is run after the devcontainer is created.
##
## @see .devcontainer/devcontainer.json

echo "[INFO] Initialize pre-commit"
pre-commit install
