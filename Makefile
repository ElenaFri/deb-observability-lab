.PHONY: lint syntax check ping

lint:
	yamllint .
	ansible-lint playbooks/

syntax:
	ansible-playbook --syntax-check playbooks/site.yml

check:
	ansible-playbook --check --diff playbooks/site.yml

ping:
	ansible-playbook playbooks/site.yml
