# Role: Omarchy Customizations

Omarchy (Arch/Hyprland) specific customizations that don't fit into any of the other roles.

The role is intended to be included on every machine (like the other roles in `../common`), but all tasks run inside a `block` guarded by `when: ansible_facts['os_family'] == "Archlinux"`. This makes the role a no-op on Ubuntu/RasPi hosts, so it can safely run in the same playbook as non-Arch machines and does not need to be excluded there.

`tasks/main.yml` only imports further task files - one subfolder per customization, each with its own tasks and assets. This is the first customization, more will be added over time.

## Customizations

### GitHub Theme (`github-theme`)

Installs a custom Omarchy theme to `~/.config/omarchy/themes/{{ omarchy_customizations_github_theme_name }}`. The theme follows the same file layout as the built-in `Tokyo Night` theme (`colors.toml`, `icons.theme`, `neovim.lua`, `vscode.json`, `shell.lock.toml`, `keyboard.rgb`, `backgrounds/`), but the palette in `colors.toml` is recolored to resemble GitHub's dark mode (Primer dark) instead.

The wallpapers shipped with the theme are the same images used by [`ansible-roles-collection/filesystem`](../../ansible-roles-collection/filesystem/files/wallpapers), copied into `files/github-theme/backgrounds/` so the whole theme - colors and wallpapers - is version controlled in this role instead of only existing on a target machine.

Omarchy picks the initial wallpaper for a theme by sorting the files in `backgrounds/` and taking the first one, then cycles through the rest in that order. `11.jpg` is shipped as `0-11.jpg` so it sorts first and is used as the default background when the theme is applied for the first time.

> **:bulb: NOTE:** Cosmetic-only assets that other themes ship (`preview.png`, `preview-unlock.png`, `unlock.png`) are generated screenshots, not hand-authored config, and are intentionally left out. The theme works without them, it's just missing a preview image in the theme picker.

Tasks and files for this customization live in `tasks/github-theme/` and `files/github-theme/`.

Switch to the theme once it has been rolled out:

```bash
omarchy-theme-set "{{ omarchy_customizations_github_theme_name }}"
```

## Expected Variables

| Variable             | Description                                                          |
|----------------------|------------------------------------------------------------------------|
| `{{ default_user }}` | The user to install and configure for (typically the logged-in user) |

## Optional Variables

The following variables are optional and have default values:

| Variable                                          | Description                                                                          | Default                             |
|----------------------------------------------------|-----------------------------------------------------------------------------------------|----------------------------------------|
| `{{ omarchy_customizations_github_theme_name }}` | Name of the installed theme (the target directory under `~/.config/omarchy/themes/`) | see [`main.yml`](defaults/main.yml) |
