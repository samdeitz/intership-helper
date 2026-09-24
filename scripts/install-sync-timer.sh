#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
unit_dir="$HOME/.config/systemd/user"
sync_dir="$HOME/.local/share/internship-helper/sync"

test -r /opt/internship-helper/.env.production
docker image inspect intership-helper-sync:latest >/dev/null
docker network inspect intership-helper_default >/dev/null
mkdir -p "$unit_dir" "$sync_dir" "$HOME/.local/state/internship-helper"
install -m 644 "$repo_dir/deploy/sync/compose.yml" "$sync_dir/compose.yml"
install -m 644 "$repo_dir/deploy/sync/internship-sync.service" "$unit_dir/"
install -m 644 "$repo_dir/deploy/sync/internship-sync.timer" "$unit_dir/"
docker compose -f "$sync_dir/compose.yml" --env-file /opt/internship-helper/.env.production config --quiet
systemd-analyze --user verify "$unit_dir/internship-sync.service" "$unit_dir/internship-sync.timer"
# Keep the user manager running after logout and start it at boot.
loginctl enable-linger "$(id -un)"
systemctl --user daemon-reload
systemctl --user enable --now internship-sync.timer
systemctl --user list-timers internship-sync.timer --no-pager
