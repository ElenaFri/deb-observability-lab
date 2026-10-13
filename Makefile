.PHONY: lint syntax check ping

lint:
	yamllint .
	ansible-lint

syntax:
	ansible-playbook --syntax-check playbooks/site.yml
	ansible-playbook --syntax-check playbooks/deploy-node-exporter.yml
	ansible-playbook --syntax-check playbooks/deploy-prometheus.yml
	ansible-playbook --syntax-check playbooks/deploy-grafana.yml

check:
	ansible-playbook --check --diff playbooks/site.yml

ping:
	ansible-playbook playbooks/site.yml
