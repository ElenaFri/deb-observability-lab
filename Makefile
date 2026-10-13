.PHONY: lint syntax check ping

lint:
	yamllint .
	ansible-lint

syntax:
	ansible-playbook --syntax-check playbooks/site.yml
	ansible-playbook --syntax-check playbooks/node_exporter.yml

check:
	ansible-playbook --check --diff playbooks/site.yml

ping:
	ansible-playbook playbooks/site.yml
