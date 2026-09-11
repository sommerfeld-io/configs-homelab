# Role: Omarchy Customizations

Omarchy (Arch/Hyprland) specific customizations that don't fit into any of the other roles.

The role is intended to be included on every machine (like the other roles in `../common`), but all tasks run inside a `block` guarded by `when: ansible_facts['os_family'] == "Archlinux"`. This makes the role a no-op on Ubuntu/RasPi hosts, so it can safely run in the same playbook as non-Arch machines and does not need to be excluded there.

`tasks/main.yml` only imports further task files - one subfolder per customization, each with its own tasks and assets. More will be added over time.

## Customizations

### GitHub Theme (`github-theme`)

Installs a custom Omarchy theme to `~/.config/omarchy/themes/{{ common_omarchy_customizations_github_theme_name }}`. The theme follows the same file layout as the built-in `Tokyo Night` theme (`colors.toml`, `icons.theme`, `neovim.lua`, `vscode.json`, `shell.lock.toml`, `keyboard.rgb`, `backgrounds/`), but the palette in `colors.toml` is recolored to resemble GitHub's dark mode (Primer dark) instead.

The wallpapers shipped with the theme were originally sourced from `ansible-roles-collection/filesystem` (since removed there as unused) and copied into `files/themes/github/backgrounds/` so the whole theme - colors and wallpapers - is version controlled in this role instead of only existing on a target machine.

Omarchy picks the initial wallpaper for a theme by sorting the files in `backgrounds/` and taking the first one, then cycles through the rest in that order. `11.jpg` is shipped as `0-11.jpg` so it sorts first and is used as the default background when the theme is applied for the first time.

> **:bulb: NOTE:** Cosmetic-only assets that other themes ship (`preview.png`, `preview-unlock.png`, `unlock.png`) are generated screenshots, not hand-authored config, and are intentionally left out. The theme works without them, it's just missing a preview image in the theme picker.

Tasks and files for this customization live in `tasks/themes/github/` and `files/themes/github/`.

Switch to the theme once it has been rolled out:

```bash
omarchy-theme-set "{{ common_omarchy_customizations_github_theme_name }}"
```

### Keybindings (`keybindings`)

Omarchy's default `SUPER+SHIFT+RETURN` (and `SUPER+SHIFT+B`, private browsing) keybindings don't launch a fixed browser binary - they run `/usr/share/omarchy/bin/omarchy-launch-browser`, which resolves the browser to open via `xdg-settings get default-web-browser`. That command reads the `[Default Applications]` section of `~/.config/mimeapps.list`.

Instead of touching `bindings.lua`, this customization sets `{{ common_omarchy_customizations_default_browser }}` as the default handler for `text/html`, `x-scheme-handler/http`, `x-scheme-handler/https`, `x-scheme-handler/about` and `x-scheme-handler/unknown` in `~/.config/mimeapps.list`. This makes every browser-launching keybinding (and any other app that opens links via the desktop default) open Firefox instead of Chromium.

It also rebinds a handful of `SUPER+SHIFT+<key>` shortcuts (in an ansible-managed block in `~/.config/hypr/bindings.lua`) to open specific web apps frameless (no address bar/tabs), via Omarchy's `{ webapp = "..." }` binding helper:

| Keybinding       | App             | URL                                                                 | Default it replaces        |
|------------------|-----------------|----------------------------------------------------------------------|-----------------------------|
| `SUPER+SHIFT+P`  | GitHub Project  | `https://github.com/orgs/sommerfeld-io/projects/1/views/1`          | Google Photos               |
| `SUPER+SHIFT+W`  | WhatsApp        | `https://web.whatsapp.com`                                          | Omawrite                    |
| `SUPER+SHIFT+G`  | Grafana         | `https://sommerfeldio.grafana.net`                                  | Signal                      |
| `SUPER+SHIFT+M`  | Google Mail     | `https://mail.google.com/mail/u/0/?hl=de&tab=wm#inbox`              | Music (Spotify)             |
| `SUPER+SHIFT+N`  | Google Calendar | `https://calendar.google.com/calendar/u/0/r?pli=1`                  | Editor                      |

Each of these keys ships an Omarchy default binding, so the block unbinds it first before adding the new one. `{ webapp = "..." }` resolves to `omarchy-launch-webapp`, which opens the URL via the installed Chromium-family browser's `--app` mode (frameless) regardless of the Firefox default-browser change above - `omarchy-launch-webapp` falls back to `chromium.desktop` for non-Chromium browsers. `focus = true` makes repeat presses refocus the already-open window instead of opening a duplicate.

Tasks for this customization live in `tasks/keybindings/`.

## Expected Variables

| Variable             | Description                                                          |
|----------------------|------------------------------------------------------------------------|
| `{{ default_user }}` | The user to install and configure for (typically the logged-in user) |

## Optional Variables

The following variables are optional and have default values:

| Variable                                                 | Description                                                                              | Default                             |
|-------------------------------------------------------------|-----------------------------------------------------------------------------------------|--------------------------------------|
| `{{ common_omarchy_customizations_github_theme_name }}`      | Name of the installed theme (the target directory under `~/.config/omarchy/themes/`)    | see [`main.yml`](defaults/main.yml) |
| `{{ common_omarchy_customizations_default_browser }}`        | Desktop file (`xdg-settings`/`mimeapps.list` entry) set as the system default browser   | see [`main.yml`](defaults/main.yml) |
