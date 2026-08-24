# Glossary — Homelab Configs

- **Node** — Any managed machine in the fleet: an Ubuntu workstation/server or a Raspberry Pi. VMs are nodes too.
- **Fleet** — The full set of nodes: caprica, kobol, picon (workstations/servers), pi4-01/02/03/05 and pi5-01 (Raspberry Pi), plus VMs. All current Pi nodes run Ubuntu; Raspberry Pi OS remains a deliberately supported target for a possible future Pi node needing a desktop environment.
- **Role** (node role) — The category a node belongs to for provisioning purposes: desktop, server, or raspi. Determines which playbook and InSpec profile apply.
- **Ansible role** — A reusable, versioned unit of provisioning logic in the `ansible-roles-collection` submodule or a local `ansible/roles/*` directory. Distinct from "node role" — context disambiguates.
- **Playbook** — An Ansible entry point that applies one or more Ansible roles to nodes of a given node role.
- **Baseline** — The declared, InSpec-checked OS/security configuration a node of a given role must satisfy.
- **Drift** — A node's actual state diverging from its baseline or its playbook's declared configuration.
- **Host group** — An Ansible inventory grouping used to scope a playbook to a subset of nodes, including per-machine exceptions.
- **Disposability** — The property that a node can be wiped and rebuilt from its playbook at low cost, because its configuration is fully defined as code rather than hand-tuned.
