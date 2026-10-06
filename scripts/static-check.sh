#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import hashlib
import json
import pathlib
import re
import sys

root = pathlib.Path('.')
dashboard = root / 'roles/elastic_assets/files/soc-dashboard.ndjson'
for number, line in enumerate(dashboard.read_text().splitlines(), 1):
    json.loads(line)

rules = (root / 'roles/sensor/templates/local.rules.j2').read_text()
sids = re.findall(r'\bsid:(\d+);', rules)
expected = [str(number) for number in range(1000001, 1000008)]
if sorted(sids) != expected or len(set(sids)) != 7:
    raise SystemExit(f'unexpected SID set: {sids}')

artifact = b'SOC-LAB-KNOWN-ARTIFACT-v1\n'
digest = hashlib.sha256(artifact).hexdigest()
if digest not in (root / 'roles/sensor/tasks/main.yml').read_text():
    raise SystemExit('known artifact SHA-256 and Suricata list differ')

for path in root.rglob('*'):
    if path.is_file() and path.suffix in {'.key', '.pem'}:
        raise SystemExit(f'private key material must not be committed: {path}')
print('JSON, SID, artifact hash, and secret-material checks passed')
PY

bash -n roles/attacker/templates/soc-attack.sh.j2
bash -n roles/target/templates/tls-endpoint.sh.j2

if command -v ansible-playbook >/dev/null 2>&1 && [[ -f inventory/hosts.yml ]]; then
  make syntax
else
  echo "Ansible syntax check skipped (install Ansible and create inventory/hosts.yml)."
fi

