# docker-compose.yml

Docker stack for Portainer CE.

## Overview

This `portainer` Docker stack starts a [Portainer CE](https://github.com/portainer/portainer)
instance. This [Portainer](https://docs.portainer.io) instance is pre-configured with an
admin user and handles deployments of other Docker stacks through GitOps techniques.

| Component | Port |URL                    |
| --------- | ---- |---------------------- |
| Portainer | 9990 | http://localhost:9990 |
