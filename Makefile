INVENTORY ?= inventory/hosts.yml
ANSIBLE ?= ansible-playbook

.PHONY: collections syntax preflight deploy validate elastic-assets lockdown rollback check

collections:
	ansible-galaxy collection install -r requirements.yml

syntax:
	$(ANSIBLE) -i $(INVENTORY) playbooks/preflight.yml --syntax-check
	$(ANSIBLE) -i $(INVENTORY) playbooks/deploy.yml --syntax-check
	$(ANSIBLE) -i $(INVENTORY) playbooks/validate.yml --syntax-check
	$(ANSIBLE) -i $(INVENTORY) playbooks/rollback.yml --syntax-check

preflight:
	$(ANSIBLE) -i $(INVENTORY) playbooks/preflight.yml

deploy:
	$(ANSIBLE) -i $(INVENTORY) playbooks/deploy.yml

elastic-assets:
	$(ANSIBLE) -i $(INVENTORY) playbooks/elastic-assets.yml

lockdown:
	$(ANSIBLE) -i $(INVENTORY) playbooks/lockdown.yml

validate:
	$(ANSIBLE) -i $(INVENTORY) playbooks/validate.yml

rollback:
	$(ANSIBLE) -i $(INVENTORY) playbooks/rollback.yml

check:
	./scripts/static-check.sh

