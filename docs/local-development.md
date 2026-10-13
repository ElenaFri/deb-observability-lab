# Local development environment

Milestone 0 supports a local-only workflow. It does not require a public cloud,
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

At this milestone the playbook only verifies Ansible connectivity. It does not
install or modify the monitoring stack on the workstation.

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
