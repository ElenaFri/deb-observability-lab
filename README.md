# deb-observability-lab

> Reproducible Linux monitoring lab built entirely with Ansible on Debian.

`deb-observability-lab` deploys and configures a complete observability stack —
Prometheus, Node Exporter and Grafana — using Infrastructure as Code.
It is designed to run on a single local Debian VM for development and testing, and
to scale to a multi-host setup by editing the Ansible inventory, without a redesign.

> Project status: work in progress. This repository is being built incrementally,
> milestone by milestone (see [Roadmap](#roadmap)). Features are only considered done
> when their acceptance criteria are met. Nothing here assumes a deployment that has
> not actually been run.

## What it demonstrates

- Reproducible, idempotent deployments with Ansible (roles, handlers, Ansible Vault).
- System metrics collection: CPU, memory, filesystem, host availability.
- Dashboards provisioned as code in Grafana (no manual clicking).
- Incident detection (stopped service / unreachable host) and documented recovery.
- Automated validation (`yamllint`, `ansible-lint`, syntax & dry-run checks) in CI,
  with no paid infrastructure.

## Scope

Local-first. No public cloud, no paid services, no containers (Docker / Kubernetes),
no Terraform. The focus is Linux system administration and Ansible fundamentals applied
to a realistic observability use case.

Optional later phases: Alertmanager notifications, multi-VM separation, Molecule tests,
TLS / authenticated reverse proxy.

## Architecture

The minimum viable architecture runs every component on a single Debian VM. The
Ansible control node is your workstation.

```mermaid
flowchart TD
    subgraph Workstation["Workstation (Ansible control node)"]
        A["Ansible<br/>playbooks + roles"]
        B["Browser"]
    end

    subgraph VM["Debian VM (single host)"]
        NE["Node Exporter<br/>:9100"]
        P["Prometheus<br/>:9090 + TSDB"]
        G["Grafana<br/>:3000"]
    end

    A -->|SSH| VM
    P -->|scrape /metrics| NE
    G -->|PromQL| P
    B -->|HTTP :3000| G
```

Data flow (pull model): Prometheus scrapes Node Exporter over HTTP, stores the series in
its local TSDB, and Grafana queries Prometheus to render dashboards. Moving to a
multi-host layout (dedicated monitoring host + several monitored hosts) only requires
moving hosts between inventory groups.

See [`docs/architecture.md`](docs/architecture.md) for the detailed design and the
future multi-host diagram.

### Components and ports

| Component | Runs on | Port | Role |
|---|---|---|---|
| Node Exporter | every monitored host | `9100` | Exposes Linux host metrics at `/metrics` |
| Prometheus | monitoring host | `9090` | Scrapes exporters, stores metrics, evaluates alert rules |
| Grafana | monitoring host | `3000` | Dashboards and visualization |
| Alertmanager *(optional, later)* | monitoring host | `9093` | Alert routing and notifications |

In the MVP all of these run on the same VM. Ports are bound to the private VM network
only; nothing is exposed to an untrusted network.

## Repository layout

```
deb-observability-lab/
├── ansible.cfg                  # Ansible defaults (inventory, roles_path, SSH)
├── requirements.yml             # Galaxy collections/roles, if any
├── inventory/
│   ├── hosts.example.ini        # example inventory (versioned)
│   └── group_vars/              # per-group variables (all / monitoring / monitored)
├── playbooks/
│   ├── site.yml                 # main orchestration playbook
│   ├── monitoring.yml           # Prometheus + Grafana
│   └── monitored.yml            # Node Exporter
├── roles/
│   ├── common/                  # base setup (users, firewall, prerequisites)
│   ├── node_exporter/
│   ├── prometheus/
│   └── grafana/
├── files/grafana/dashboards/    # dashboards as code (JSON)
├── tests/
│   └── smoke/                   # post-deploy verification scripts
├── docs/
│   ├── architecture.md
│   └── runbook.md               # troubleshooting & recovery procedures
├── examples/
│   └── vault.example.yml        # secrets structure (no real values)
└── .github/workflows/ci.yml     # yamllint + ansible-lint + syntax & dry-run checks
```

## Prerequisites

Control node (your workstation):
- Ansible (2.15+ recommended)
- `ansible-lint`, `yamllint`
- An SSH key pair for connecting to the target

Target (recommended): a local Debian 13 (Trixie) VM.
Since the lab is local-first and requires no cloud, the recommended setup is a VM on
your Linux workstation using KVM/libvirt, provisioned reproducibly with
Vagrant + libvirt (a `Vagrantfile` will be provided in Milestone 0). VirtualBox is a
supported alternative. A `localhost` fallback (deploying onto the control node itself) is
also documented for environments without virtualization.

> The VM provisioning tooling (Vagrant / libvirt) is part of Milestone 0 and not yet
> committed.

## Quick start

> Target workflow (available as milestones land; see [Roadmap](#roadmap)).

```bash
# 1. Bring up the local Debian VM (Milestone 0)
vagrant up

# 2. Verify Ansible connectivity
ansible all -i inventory/hosts.ini -m ping

# 3. Deploy the full stack
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 4. Confirm idempotence (second run should report changed=0)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

Then open Grafana at `http://<vm-ip>:3000` and Prometheus at `http://<vm-ip>:9090`.

## Testing & acceptance criteria

In CI (GitHub Actions, no VM required):
- `yamllint` passes
- `ansible-lint` passes
- `ansible-playbook --syntax-check` passes
- `ansible-playbook --check` (dry-run) runs without error

Locally (requires a Debian VM):
- Clean deployment from a fresh Debian succeeds
- A second run reports `changed=0` (idempotence)
- `curl http://<vm>:9100/metrics` returns metrics
- Prometheus shows the target as `up == 1`
- Grafana datasource is healthy and the dashboard shows live data
- Failure simulation: stopping Node Exporter makes the target `up == 0` in
  Prometheus/Grafana; restarting it restores `up == 1`

See [`docs/runbook.md`](docs/runbook.md) for failure simulation and recovery procedures.

## Security

Sensible defaults for a local lab:

- Monitoring interfaces bound to the private VM network only — not exposed publicly.
- Least privilege: dedicated, shell-less system users for `node_exporter` and `prometheus`;
  hardened systemd units.
- No hardcoded secrets. The Grafana admin password and any sensitive values are stored
  with Ansible Vault; password files and local secrets are git-ignored.
- Clear separation between configuration (managed in `/etc`) and runtime data
  (persisted under `/var/lib`, never committed).

Before exposing the stack to an untrusted network you would additionally need TLS
everywhere, an authenticated reverse proxy in front of Grafana/Prometheus, and
authentication on the metrics endpoints. These are explicitly out of scope for the
local lab and documented as future hardening.

## Roadmap

| Milestone | Objective |
|---|---|
| 0 | Local environment (Debian VM) + Ansible connectivity + CI lint |
| 1 | `node_exporter` role (first full idempotent IaC chain) |
| 2 | `prometheus` role (scrape + store, config generated from inventory) |
| 3 | `grafana` role (datasource + dashboards provisioned as code) |
| 4 | Incident detection (alert rules) + runbook + smoke tests |
| 5 *(optional)* | Alertmanager + notifications |
| 6 *(optional)* | Multi-VM separation |
| 7 *(optional)* | Molecule tests + TLS/auth hardening |
