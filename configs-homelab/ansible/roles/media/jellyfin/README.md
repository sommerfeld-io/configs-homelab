# Role: Media / Jellyfin

This role deploys [Jellyfin](https://jellyfin.org) as a Docker Compose service, providing a media server for the home lab's video library.

The compose file is copied to `{{ jellyfin_path }}` and the container is brought up with `pull: missing` so the image is only pulled when not already present.

## Default Variables

| Variable              | Default               | Description                              |
|------------------------|-----------------------|-------------------------------------------|
| `jellyfin_path`  | `/opt/media/jellyfin` | Path where the compose file is deployed  |

## Required Variables

| Variable       | Description                                                           |
|----------------|------------------------------------------------------------------------|
| `default_user` | The user that owns the deploy directory and compose file on the node |
