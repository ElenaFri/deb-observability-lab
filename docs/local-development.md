# Local development environment

The project supports a local-only workflow. It does not require a public cloud,
a dedicated server or a paid service.

## Current fallback: localhost

The versioned `inventory/hosts.ini` targets the local workstation with Ansible's
local connection. This makes the first connectivity check executable before a VM
has been provisioned:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
ansible-playbook playbooks/site.yml
```

The localhost inventory is intentionally limited to the connectivity playbook. Do not
run the Node Exporter deployment against it unless you explicitly want to modify the
workstation.

## Recommended target: a local Debian VM

The intended target is a Debian 13 VM managed locally with KVM/libvirt. The target
VM should have:

- a reachable SSH address;
- a Debian user with an SSH key;
- `sudo` access for future configuration roles;
- network access to Debian package repositories.

`inventory/hosts.example.ini` shows the intended single-VM inventory. In that
topology the same host belongs to both `monitoring` and `monitored` groups.
The inventory can later contain a dedicated monitoring host and several monitored
hosts without changing the role boundaries.

For Milestone 1, create `inventory/hosts.local.ini` from the example and run:

```bash
ansible-playbook \\
  -i inventory/hosts.local.ini \\
  playbooks/node_exporter.yml \\
  --private-key ~/.ssh/deb-observability-lab \\
  --ask-become-pass
```

The target user must have working `sudo` access. The Node Exporter role uses the
signed Debian `prometheus-node-exporter` package and manages its systemd service.

The repository does not currently require Vagrant. If Vagrant or another VM
provisioner is added later, it must remain an optional local development helper,
not a runtime dependency of the Ansible roles.

## Host checks

These commands only inspect the local machine and do not change the repository:

```bash
command -v ansible
command -v ansible-playbook
command -v virsh
test -e /dev/kvm && echo 'KVM is available'
virsh list --all
```

A stopped or unavailable VM is not a failed Ansible project; it means the local
integration target still needs to be provisioned or started.
