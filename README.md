# Remote KVM SOC Lab

This repository deploys a three-VM Suricata and Elastic training lab on a dedicated Debian 13 KVM host. All intentionally vulnerable services remain on isolated libvirt networks. Only SSH on the KVM host and outbound HTTPS to Elastic are required.

## What is included

- Idempotent Ansible provisioning for the KVM host, sensor, target, and attacker.
- Checksum-gated Ubuntu and Kali cloud images with cloud-init networking.
- Suricata rules with SIDs `1000001` through `1000007` for SQLi, XSS, oversized input, obsolete TLS, expired and rogue certificates, and known SHA-256 content.
- DVWA, four controlled TLS endpoints, a safe oversized-input recorder, and a known-file server.
- A deterministic `soc-attack` CLI, Filebeat ingestion, a chained enrichment pipeline, and a Kibana dashboard with five-second refresh.
- Read-only preflight, false-positive baseline, end-to-end validation, lockdown, and explicitly confirmed rollback.

## Safety model

The attacker and target networks use libvirt `forward mode="none"`. The sensor is their only router. Target ports are not forwarded to the KVM host or Internet. General lab egress is enabled only while packages and images are installed, then removed automatically. The oversized-input service records length and closes; it contains no exploitable memory-corruption bug.

Run this only on the dedicated host and networks you are authorized to test.

## Controller prerequisites

- Ansible Core 2.16 or newer.
- Python 3, OpenSSH, `make`, and access to the remote host using an SSH key.
- An SSH public key to inject into the guests.
- The public CA chain used by Elasticsearch and Kibana.

Install collections:

```bash
make collections
```

Copy and edit the inventory. Replace all documentation addresses, including the three `ProxyJump` values:

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

In `group_vars/all.yml`, set exact cloud-image URLs and their published SHA-256 values. The Ubuntu `current` URL is checksum-gated; use a release-specific URL if long-term byte-for-byte reproducibility is required. Kali uses a mandatory placeholder because its release filename changes. Do not accept a checksum obtained from the image download itself—verify it against the vendor's separately published manifest.

## Required environment

```bash
export SOC_SSH_PRIVATE_KEY=/secure/path/soc-admin
export SOC_SSH_PUBLIC_KEY_FILE=/secure/path/soc-admin.pub
export SOC_EXPECTED_EGRESS_IP=198.51.100.25
export ELASTICSEARCH_URL=https://elasticsearch.example.edu:443
export KIBANA_URL=https://kibana.example.edu:443
export ELASTIC_VERSION=9.x.y
export ELASTIC_CA_FILE=/secure/path/elastic-ca.pem
export ELASTIC_API_KEY='publishing-key-id:api-key'
export ELASTIC_SETUP_API_KEY='temporary-setup-key-id:api-key'
export KIBANA_API_KEY='temporary-kibana-key-id:api-key'
```

Supply API keys in the `id:api_key` form returned by Elastic, not the separately returned base64 `encoded` value. The automation performs HTTP Base64 encoding where required. Do not put these values in inventory or Git. Add the stable egress IP to the Elastic network allowlist before preflight.

The publishing key needs only event publishing and pipeline-use privileges for the Filebeat data stream/index. The temporary setup key needs cluster monitoring plus ingest-pipeline, index-template, and ILM management, and read access for validation. The Kibana key needs saved-object import rights for data views, visualizations, and dashboards. Revoke both temporary keys after successful validation.

## Deployment

The preflight does not modify the host or Elastic. It verifies Debian 13, `/dev/kvm`, at least 8 vCPUs, 15 GiB reported RAM, 90 GiB free storage, the stable egress IP, TLS trust, and exact Elastic version. Its sanitized report is written to `artifacts/preflight.json`.

```bash
make check
make preflight
make deploy
make validate
```

`make deploy` performs these stages in order:

1. Installs KVM/libvirt tools and creates only `soc-*` networks and domains.
2. Boots guests with cloud-init and waits for SSH through ProxyJump.
3. Configures the sensor with temporary installation egress.
4. Installs target services and the attack generator.
5. Removes general guest egress.
6. Loads Filebeat pipelines and imports **Remote SOC Lab — Intrusion & Cryptographic Threats** into Kibana.

If dashboard import permissions are deliberately separated, run `make elastic-assets` after supplying the temporary setup keys. `make lockdown` can be rerun at any time.

## Demonstration

On the attacker VM:

```bash
soc-attack baseline
soc-attack sqli
soc-attack xss
soc-attack overflow
soc-attack legacy-tls
soc-attack expired-tls
soc-attack rogue-tls
soc-attack weak-cipher
soc-attack hash
soc-attack all
```

`make validate` first records the current EVE offset, confirms baseline traffic generates none of the custom SIDs, runs all scenarios, checks the seven SIDs locally, verifies Filebeat output, and waits up to twenty seconds for seven distinct rule IDs in Elasticsearch.

The weak-cipher endpoint uses TLS 1.2 with `AES128-SHA` at OpenSSL security level 0. It is classified by the final ingest pipeline as `soc.tls.cipher_class=obsolete-cbc-sha1`. Suricata natively alerts on the legacy-protocol endpoint. The rogue-certificate rule matches the deterministic lab subject; it is not general certificate-chain validation.

## Idempotency and rollback

Run `make deploy` a second time and review the Ansible recap; stable resources should report no changes. Libvirt network/domain definitions and cloud-init seed images are immutable after first creation, so change guest identity, resources, or networking by rolling back and redeploying rather than editing an existing definition.

Rollback requires typing an exact confirmation phrase:

```bash
make rollback
```

It destroys and undefines only the three `soc-*` domains, the three `soc-*` networks, and `/var/lib/libvirt/images/soc-lab`. It does not touch unrelated domains, networks, host management configuration, SSH, or Elastic data. Revoke the lab API keys and remove the egress-IP allowlist entry separately after teardown.
# p_crypto_inform_sec_lab_1
