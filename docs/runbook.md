# Runbook: operations, incident detection and recovery

This runbook covers day-to-day checks, the alert rules shipped by the project, and a
reproducible incident simulation with its recovery procedure. All commands assume the
single-VM lab (`192.168.122.60` in the examples); adjust the address to your target.

Prometheus evaluates the alert rules itself and shows them on `/alerts`. From Milestone 5,
Alertmanager receives those alerts and groups, deduplicates and (optionally) notifies on
them. External notifications (email, chat, etc.) are deferred to a Vault-based hardening
step; the default receiver only exposes alerts in the Alertmanager UI.

## Service map

| Service | Host role | Unit | Port |
|---|---|---|---|
| Node Exporter | monitored | `prometheus-node-exporter` | `9100` |
| Prometheus | monitoring | `prometheus` | `9090` |
| Grafana | monitoring | `grafana-server` | `3000` |
| Alertmanager | monitoring | `prometheus-alertmanager` | `9093` |

In the single-VM lab one host fills both roles. In a multi-host lab (Milestone 6) the
monitoring services run on the monitoring host only, while each monitored host runs Node
Exporter alone. The commands below use the monitoring host address; replace the instance
address when acting on a specific monitored host.

## Routine health checks

From the control node (your workstation):

```bash
bash tests/smoke/node_exporter.sh 192.168.122.60
bash tests/smoke/prometheus.sh 192.168.122.60
bash tests/smoke/alert_rules.sh 192.168.122.60
bash tests/smoke/grafana.sh 192.168.122.60
bash tests/smoke/alertmanager.sh 192.168.122.60
```

Check that every target is up:

```bash
curl --silent 'http://192.168.122.60:9090/api/v1/query?query=up' | python3 -m json.tool
```

On the VM itself:

```bash
systemctl status prometheus-node-exporter prometheus grafana-server prometheus-alertmanager
journalctl -u prometheus -n 50 --no-pager
```

## Alert rules

The `prometheus` role deploys `/etc/prometheus/rules/alerts.yml`:

| Alert | Condition | For | Severity |
|---|---|---|---|
| `InstanceDown` | `up{job="node"} == 0` | 1m | critical |
| `HighCpuUsage` | CPU usage above threshold | 5m | warning |
| `HighMemoryUsage` | memory usage above threshold | 5m | warning |
| `LowDiskSpace` | root filesystem usage above threshold | 5m | warning |

Thresholds are role variables (`prometheus_alert_cpu_threshold`, etc.) and default to
85%. Inspect the loaded rules and the current alert states:

```bash
curl --silent 'http://192.168.122.60:9090/api/v1/rules'   | python3 -m json.tool
curl --silent 'http://192.168.122.60:9090/api/v1/alerts'  | python3 -m json.tool
```

Or open `http://192.168.122.60:9090/alerts` in a browser.

## Alertmanager

Prometheus forwards firing alerts to Alertmanager, which groups and deduplicates them.
Inspect the routed alerts:

```bash
curl --silent 'http://192.168.122.60:9093/api/v2/alerts' | python3 -m json.tool
```

Or open `http://192.168.122.60:9093` in a browser. The default receiver performs no
external notification; alerts are only displayed here. To add email/webhook/chat
notifications, extend the `alertmanager` role's configuration and store any credentials in
Ansible Vault.

To silence an alert during planned maintenance, use the Alertmanager UI ("Silences" tab)
or `amtool` on the VM:

```bash
ssh -t elena_f@192.168.122.60 \
  'amtool --alertmanager.url=http://localhost:9093 silence add alertname=InstanceDown --duration=1h --comment="planned maintenance"'
```

## Incident simulation: a monitored host goes down

This demonstrates detection of a stopped service or an unreachable host. Stopping Node
Exporter makes its target unscrapeable, so `up` drops to `0` and `InstanceDown` fires.

1. Confirm the baseline (target up, alert inactive):

   ```bash
   curl -g --silent 'http://192.168.122.60:9090/api/v1/query?query=up{job="node"}'
   ```

   Expect `"value": [ ..., "1" ]`.

2. Trigger the incident on the VM:

   ```bash
   ssh -t elena_f@192.168.122.60 'sudo systemctl stop prometheus-node-exporter'
   ```

3. Observe detection. Within one scrape interval `up` becomes `0`; after the
   `for: 1m` window `InstanceDown` moves from `pending` to `firing`:

   ```bash
   curl -g --silent 'http://192.168.122.60:9090/api/v1/query?query=up{job="node"}'
   curl --silent 'http://192.168.122.60:9090/api/v1/alerts' | python3 -m json.tool
   ```

   Expect `up == 0` and `InstanceDown` with `"state": "firing"`. In Grafana, the
   "Host availability" panel shows `DOWN`. With several monitored hosts, the firing
   `InstanceDown` alert carries the `instance` label of the affected host, so only that
   target is reported down while the others stay up.

## Recovery

1. Restart the service on the VM:

   ```bash
   ssh -t elena_f@192.168.122.60 'sudo systemctl start prometheus-node-exporter'
   ```

2. Confirm recovery from the control node:

   ```bash
   bash tests/smoke/node_exporter.sh 192.168.122.60
   curl -g --silent 'http://192.168.122.60:9090/api/v1/query?query=up{job="node"}'
   ```

   `up` returns to `1`, and `InstanceDown` clears from `/alerts` once the target is
   scraped again. Re-running the Ansible deployment is also a valid recovery path, as the
   role ensures the service is enabled and started.

## Common problems

| Symptom | Likely cause | Action |
|---|---|---|
| `promtool` validation fails during deploy | invalid scrape config or rule syntax | read the error; fix the template; re-run the playbook |
| Prometheus active but target `up == 0` | Node Exporter stopped or port blocked | `systemctl status prometheus-node-exporter`; check `:9100` reachability |
| Grafana datasource test fails | Prometheus down or wrong URL | verify `:9090` health; check `grafana_prometheus_url` |
| Alerts never fire | rules not loaded or evaluation disabled | `curl /api/v1/rules`; check `rule_files` in `prometheus.yml` |
| Config change not applied | handler not triggered | confirm the task reports `changed`; the reload handler runs at the end of the play |

## Safe configuration changes

- All configuration is managed by Ansible; edit templates and variables, not the files on
  the host. A manual edit will be overwritten on the next run.
- Rendered configuration is validated (`promtool check config` / `promtool check rules`)
  before it is applied, so an invalid change fails the task instead of breaking the running
  service.
- Prometheus is reloaded (not restarted) on config changes, preserving the TSDB and
  avoiding a scrape gap.
