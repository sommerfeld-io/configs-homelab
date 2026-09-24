# Ansible Playbook - SSH Trust

This Ansible playbook sets up password-less SSH connections between the nodes of the home lab. It does the same as running `ssh-copy-id` on every source node for every destination node, but without any password prompts, and only for connections that aren't configured yet.

Run it with `task ansible:ssh:trust`. It needs neither `sudo` nor the Ansible vault, so it doesn't prompt for their passwords.

## What it does

The connections are configured as `src`/`dest` pairs in `ansible/vars/ssh-trust.yml`. Each pair lets `sebastian` on `src` connect to `dest` without a password:

```yaml
ssh_trust_pairs:
  - { src: picon.fritz.box, dest: kobol.fritz.box }
  - { src: caprica.fritz.box, dest: picon.fritz.box }
```

For every pair, the playbook:

- **Authorizes the source key**: reads `~/.ssh/id_rsa.pub` from `src` and adds it to `~/.ssh/authorized_keys` on `dest`
- **Trusts the destination host key**: scans `dest`'s SSH host keys from `src` (`ssh-keyscan`) and adds them to `~/.ssh/known_hosts` on `src`, so the first `ssh <dest>` from `src` doesn't ask to confirm the host key
- **Reports skipped pairs**: prints a summary of the pairs it couldn't process and why

Both steps are idempotent. Pairs that are already configured are left untouched, so running the playbook again only reports changes for new pairs. Existing keys are never removed.

## Why not `ssh-copy-id`?

`ssh-copy-id` logs into the destination with a password, which Ansible can't answer without storing the password and scripting the prompt. It also asks to confirm unknown host keys. Ansible already has password-less access from the controller to every node, so the playbook writes `authorized_keys` and `known_hosts` directly over that connection instead.

## Things to keep in mind

- **Controller access stays manual**: Ansible itself needs password-less SSH from the controller to every node before it can run anything. That first connection can't be set up by this playbook and still needs `ssh-copy-id sebastian@<hostname>.fritz.box` from the controller (see the node setup guides).
- **The source needs a key pair**: `~/.ssh/id_rsa` is created by the `bash` role of the [ansible-roles-collection](https://github.com/sommerfeld-io/ansible-roles-collection) (run by the desktop, server and raspi playbooks). Pairs whose `src` has no key yet are skipped.
- **Offline nodes are skipped**: laptops are often not reachable. Pairs with an unreachable `src` or `dest` don't fail the run. They are listed in the summary; run the playbook again once the node is online.
- **Every pair is a trust edge**: a compromised node can connect to every node that trusts it. Only add the pairs you need.
- **Reinstalled nodes**: a reinstalled node gets a new host key and a new user key. The playbook adds the new keys but doesn't remove the old ones. Remove the stale host key on the other nodes with `ssh-keygen -R <hostname>.fritz.box` (otherwise `ssh` refuses to connect because the host key changed), and delete the old key from `~/.ssh/authorized_keys` if needed.
