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
  playbooks/deploy-node-exporter.yml \\
  --private-key ~/.ssh/deb-observability-lab \\
  --ask-become-pass
```

The target user must have working `sudo` access. The Node Exporter role uses the
signed Debian `prometheus-node-exporter` package and manages its systemd service.

For Milestone 2, deploy Prometheus on the monitoring host:

```bash
ansible-playbook \\
  -i inventory/hosts.local.ini \\
  playbooks/deploy-prometheus.yml \\
  --private-key ~/.ssh/deb-observability-lab \\
  --ask-become-pass
```

Prometheus scrape targets are generated from the `monitored` inventory group, and the
scrape port comes from `node_exporter_port` in `inventory/group_vars/all.yml`, so the two
roles stay in sync from a single value.

For Milestone 3, deploy Grafana on the monitoring host:

```bash
ansible-playbook \\
  -i inventory/hosts.local.ini \\
  playbooks/deploy-grafana.yml \\
  --private-key ~/.ssh/deb-observability-lab \\
  --ask-become-pass
```

Grafana is pulled from its official signed APT repository (it is not in Debian), and its
Prometheus datasource and dashboards are provisioned as code. The admin password is a
variable with a lab default; override it at deploy time, for example with a git-ignored
vars file:

```bash
ansible-playbook \\
  -i inventory/hosts.local.ini \\
  playbooks/deploy-grafana.yml \\
  --private-key ~/.ssh/deb-observability-lab \\
  --ask-become-pass \\
  -e @secrets.local.yml
```

The repository does not currently require Vagrant. If Vagrant or another VM
provisioner is added later, it must remain an optional local development helper,
not a runtime dependency of the Ansible roles.

## Milestone 6: a second local VM

A second monitored host lets you demonstrate the multi-host topology. The fastest
reliable way to get one is to clone the known-good monitoring VM rather than fighting a
fresh install. With libvirt (`qemu:///system`):

```bash
# The source domain must be shut off before cloning.
sudo virsh -c qemu:///system shutdown debian13

sudo virt-clone --connect qemu:///system \
  --original debian13 \
  --name node2 \
  --file /var/lib/libvirt/images/node2.qcow2

# Reset the clone's identity (hostname, machine-id, SSH host keys, logs).
sudo virt-sysprep -d node2 --hostname node2

sudo virsh -c qemu:///system start debian13
sudo virsh -c qemu:///system start node2
```

`virt-clone` assigns a new MAC, so the clone gets its own DHCP lease. Find its address:

```bash
sudo virsh -c qemu:///system domifaddr node2 --source agent
```

Two `virt-sysprep` side effects need attention before Ansible can reach the clone, because
it removes SSH host keys and every user's `~/.ssh`:

- `sshd` will not start until host keys exist: regenerate them with `ssh-keygen -A`,
  then `systemctl enable --now ssh`.
- the deploy key is gone from `authorized_keys`: re-add your public key to
  `/home/<user>/.ssh/authorized_keys` (mode 600, owned by the user; `.ssh` mode 700).

If SSH is not yet reachable, both fixes can be applied through the qemu guest agent, which
runs as root inside the VM, so no in-guest password is needed:

```bash
sudo virsh -c qemu:///system qemu-agent-command node2 \
  '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","ssh-keygen -A && systemctl enable --now ssh"],"capture-output":true}}'
```

Because the clone inherits the full stack, disable the monitoring services on the new
monitored-only host, keeping Node Exporter:

```bash
ssh -t <user>@<node2-ip> 'sudo systemctl disable --now prometheus grafana-server prometheus-alertmanager'
```

Then add `node2` to the `[monitored]` group in your local inventory and re-deploy Node
Exporter and Prometheus (see Milestone 6 in the README).

## Milestone 7: TLS and authenticated access

The `reverse_proxy` role fronts a web UI with nginx, terminating TLS and requiring HTTP
basic authentication. It generates a self-signed certificate on the host and computes the
auth hash with `openssl`, so it adds no new Ansible collection. Override the basic-auth
password at deploy time with a git-ignored vars file:

```bash
ansible-playbook \\
  -i inventory/hosts.local.ini \\
  playbooks/deploy-reverse-proxy.yml \\
  --private-key ~/.ssh/deb-observability-lab \\
  --ask-become-pass \\
  -e @secrets.local.yml
```

By default the proxy fronts Grafana (`reverse_proxy_backend_url`); point it at Prometheus
(`http://127.0.0.1:9090`) or Alertmanager (`http://127.0.0.1:9093`) to protect a service
that has no native authentication. Validate it with
`bash tests/smoke/reverse_proxy.sh <vm> observer <password>`.

## Host checks
The repository does not currently require Vagrant. If Vagrant or another VM

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
