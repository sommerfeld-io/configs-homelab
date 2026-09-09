# Omarchy in VirtualBox (without Vagrant)

Notes on what to do after the Omarchy setup wizard finishes when running Omarchy inside VirtualBox without Vagrant.

> **Source:** [github.com/omacom/omarchy discussion #7758 "Omarchy on VirtualBox"](https://github.com/omacom/omarchy/discussions/7758)

## Display settings (before first real boot)

Set these VM display settings before booting into the graphical session. Without them, Hyprland can't init OpenGL/EGL and you get a black screen after login.

- [ ] `VM Settings > Display > Graphics Controller`: `VMSVGA`
- [ ] `VM Settings > Display > Video Memory`: `128 MB`
- [ ] `VM Settings > Display > 3D Acceleration`: `Enabled`

## Black screen after disk decryption

- [ ] Re-check the 3 display settings above. They sometimes need re-applying.

## Enable VirtualBox guest utils

- [ ] Switch to a TTY (`Ctrl+Alt+F3`, via virtual keyboard / Soft Keyboard in VirtualBox if the host captures the real keys) and log in.
- [ ] Install and enable the guest utils:

    ```shell
    omarchy pkg add virtualbox-guest-utils
    sudo systemctl enable --now vboxservice.service
    ```

    This enables clipboard sharing and auto-resize, and also quiets the `vmw_msg_ioctl` "Failed to open channel" kernel warning.

## Fix Omarchy shell crash-looping (VMSVGA bug)

Known VMSVGA bug: the Omarchy shell (Quickshell/bar) crash-loops. The log shows:

- `invalid arguments for wl_surface.attach`
- `Wayland connection experienced a fatal error: Invalid argument`
- `Giving up on the Omarchy shell after 6 relaunches`

- [ ] Edit `~/.config/hypr/hyprland.lua` and add this line right after the bootstrap `dofile(...)` line at the top. Order matters: it must run before `require("hypr.autostart")`.

    ```lua
    hl.env("LIBGL_ALWAYS_SOFTWARE", "1")
    ```

- [ ] Reboot the VM (or run `hyprctl reload` and `omarchy restart shell` with `HYPRLAND_INSTANCE_SIGNATURE` set, see [Run hyprctl from a TTY](#run-hyprctl-from-a-tty) below).

> **Tradeoff:** GL clients render on CPU (llvmpipe), which means slower animations, but the shell is usable.

## Fix odd resolution

If the resolution sticks at something odd (e.g. `960x488`):

- [ ] Edit `~/.config/hypr/monitors.lua` and set:

    ```lua
    hl.monitor({ output = "Virtual-1", mode = "1920x1080@60",
                 position = "0x0", scale = 1 })
    ```

- [ ] Run `hyprctl reload`.

## Run hyprctl from a TTY

To run `hyprctl` from a TTY (not inside the graphical session):

```shell
ls /run/user/1000/hypr/
export XDG_RUNTIME_DIR=/run/user/1000
export HYPRLAND_INSTANCE_SIGNATURE=<folder name from ls above>
hyprctl configerrors      # should be empty
hyprctl layers            # should include "omarchy-bar"
```

## SSH Access (VirtualBox, NAT)

Steps to get SSH working against the VM over the default NAT network adapter.

### Setup

- [ ] Install and enable SSH in the guest (Omarchy):

    ```shell
    omarchy pkg add openssh
    sudo systemctl enable --now sshd
    ```

    Verify it's listening:

    ```shell
    sudo ss -tlnp | grep :22
    # expect: LISTEN ... 0.0.0.0:22 ... users:(("sshd",...))
    ```

- [ ] Add a NAT port-forward rule on the host. The VM adapter is NAT, so there's no direct IP access without this.

    ```shell
    # VM running:
    VBoxManage controlvm omarchy natpf1 "ssh,tcp,127.0.0.1,2222,,22"

    # VM powered off (equivalent):
    VBoxManage modifyvm omarchy --natpf1 "ssh,tcp,,2222,,22"
    ```

    Verify the rule:

    ```shell
    VBoxManage showvminfo omarchy --machinereadable | grep -i forwarding
    # Forwarding(0)="ssh,tcp,127.0.0.1,2222,,22"
    ```

    Remove it later if needed:

    ```shell
    VBoxManage controlvm omarchy natpf1 delete ssh
    ```

- [ ] Allow SSH through the guest firewall. This was the actual blocker:

    ```shell
    sudo ufw allow ssh      # or: sudo ufw allow 22/tcp
    sudo ufw reload
    ```

    > **Root cause:** `ufw` was active by default in Omarchy and silently dropped the forwarded connection even though `sshd` was listening correctly. VirtualBox's NAT proxy accepted the TCP handshake on the host side regardless, so the symptom looked like a hang/timeout (`Connection timed out during banner exchange`) rather than an obvious refusal.

- [ ] Connect from the host:

    ```shell
    ssh -p 2222 sebastian@127.0.0.1
    ```

### Passwordless SSH

- [ ] Copy your public key to the guest so you no longer have to type the password on every connection:

    ```shell
    ssh-copy-id -p 2222 sebastian@127.0.0.1
    ```

### Cleaning up known_hosts

`127.0.0.1:2222` gets reused every time the VM is reinstalled, reverted to a snapshot, or recreated, but each of those gets a fresh SSH host key. SSH then refuses to connect and warns `REMOTE HOST IDENTIFICATION HAS CHANGED!`, because the host key on file for `127.0.0.1:2222` no longer matches.

- [ ] Remove the stale entry from `~/.ssh/known_hosts` before reconnecting:

    ```shell
    ssh-keygen -R "[127.0.0.1]:2222"
    ```

### Troubleshooting

| Symptom                                                       | Cause                                                                                                                     |
|---------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `kex_exchange_identification: read: Connection reset by peer` | `sshd` not yet started/enabled in the guest                                                                               |
| `Connection timed out during banner exchange`                 | TCP handshake completes via VirtualBox's NAT proxy, but the guest firewall drops the connection before `sshd` can respond |

Diagnostic commands used along the way:

```shell
systemctl status sshd
sudo ss -tlnp | grep :22
ip addr show                                 # confirm guest IP (10.0.2.15 via NAT)
ip route show
systemctl is-active ufw nftables firewalld   # revealed ufw was active
sudo ufw status verbose
```
