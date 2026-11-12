#!/usr/bin/env bash
# Run once per laptop, as root:   sudo ./install.sh <git-repo-url> [branch]
# Installs ansible + git, does a first pull, then installs a systemd timer
# so the laptop re-pulls and re-applies config every 15 minutes.
set -euo pipefail

REPO_URL="${1:?usage: install.sh <git-repo-url> [branch]}"
BRANCH="${2:-main}"
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

echo ">> Installing ansible + git"
if   command -v apt-get >/dev/null; then apt-get update -qq && apt-get install -y ansible git
elif command -v dnf     >/dev/null; then dnf install -y ansible-core git && ansible-galaxy collection install ansible.posix -p /usr/share/ansible/collections
elif command -v pacman  >/dev/null; then pacman -Sy --noconfirm ansible git
else echo "unsupported distro: install ansible and git manually" >&2; exit 1; fi

mkdir -p /etc/ansible-pull /var/lib/ansible-pull
cat > /etc/ansible-pull/env <<ENV
REPO_URL=${REPO_URL}
BRANCH=${BRANCH}
ENV

cat > /etc/systemd/system/ansible-pull.service <<'UNIT'
[Unit]
Description=Pull and apply Ansible configuration
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/ansible-pull/env
# --only-if-changed: skip the playbook when the repo has no new commits
# NOTE: drop it if you also want to re-correct local drift between commits.
ExecStart=/usr/bin/ansible-pull -U ${REPO_URL} -C ${BRANCH} \
  -d /var/lib/ansible-pull/checkout -i localhost, \
  --purge local.yml
UNIT

cat > /etc/systemd/system/ansible-pull.timer <<'UNIT'
[Unit]
Description=Run ansible-pull periodically

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
RandomizedDelaySec=2min
Persistent=true

[Install]
WantedBy=timers.target
UNIT

echo ">> First run"
systemctl daemon-reload
systemctl start ansible-pull.service || echo "first run failed - check: journalctl -u ansible-pull"
systemctl enable --now ansible-pull.timer
echo ">> Done. Logs: journalctl -u ansible-pull -f"
