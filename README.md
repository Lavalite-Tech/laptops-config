# fleet-config

Ansible config for the laptop fleet, applied with `ansible-pull`.
Each laptop clones this repo and runs `local.yml` against itself.

## Layout
| Path | Purpose |
|---|---|
| `local.yml` | Entry point ansible-pull runs |
| `group_vars/all.yml` | **The user list and SSH keys - the file you edit day to day** |
| `files/pubkeys/` | Optional: public keys as files, referenced via `lookup('file', ...)` |
| `roles/users` | Creates users/groups, manages `authorized_keys`, removes offboarded users |
| `roles/sshd_hardening` | Optional: disables password SSH login (off by default) |
| `bootstrap/install.sh` | One-time per-laptop setup + systemd timer |

## Day-to-day
1. Edit `group_vars/all.yml` (add a user, add/rotate a key, move a name to `removed_users`).
2. `ansible-playbook --syntax-check local.yml`
3. Commit and push. Laptops converge within ~15 min.

## Try it locally (safe-ish: run in a VM or container, it really creates users)
    sudo ansible-pull -U "$PWD" -d /tmp/checkout -i localhost, local.yml
    # preview only:
    sudo ansible-pull -U "$PWD" -d /tmp/checkout -i localhost, local.yml --check --diff

## Enroll a laptop
    sudo ./bootstrap/install.sh git@yourhost:org/fleet-config.git main

## Things to know
- `exclusive_keys: true` means keys added by hand are wiped on the next run.
- Removing a user from `managed_users` does NOT delete them; add to `removed_users`.
- Keep this repo private-write: anyone who can push can get root on every laptop.
- Enable `sshd_hardening` only after confirming key login works.
