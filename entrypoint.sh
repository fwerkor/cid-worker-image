#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /run/sshd /root/.ssh "${LSM_WORKDIR:-/workspace}"
chmod 700 /root/.ssh

if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
  touch /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  if ! grep -Fqx -- "$SSH_PUBLIC_KEY" /root/.ssh/authorized_keys; then
    printf '%s\n' "$SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
  fi
fi

if [[ -n "${SSH_AUTHORIZED_KEYS_FILE:-}" && -f "${SSH_AUTHORIZED_KEYS_FILE}" ]]; then
  install -m 600 "${SSH_AUTHORIZED_KEYS_FILE}" /root/.ssh/authorized_keys
fi

if [[ -n "${SSH_PASSWORD:-}" ]]; then
  printf 'root:%s\n' "$SSH_PASSWORD" | chpasswd
  sed -i 's/^PasswordAuthentication no$/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/99-unist3.conf
fi

if [[ ! -s /root/.ssh/authorized_keys && -z "${SSH_PASSWORD:-}" ]]; then
  echo 'WARNING: neither SSH_PUBLIC_KEY/SSH_AUTHORIZED_KEYS_FILE nor SSH_PASSWORD is set; SSH login will not be possible.' >&2
fi

ssh-keygen -A
/usr/sbin/sshd

worker_state="/root/.local/state/local-shell-mcp-worker"
worker_config="$worker_state/config.json"

if [[ -f "$worker_config" ]]; then
  echo "Starting enrolled local-shell-mcp worker as ${LSM_NAME:-unist3} ..." >&2
  exec /opt/lsm-venv/bin/python -m local_shell_mcp.main worker run
fi

invite=""
if [[ -n "${LSM_INVITE_FILE:-}" && -f "${LSM_INVITE_FILE}" ]]; then
  invite="$(<"${LSM_INVITE_FILE}")"
elif [[ -n "${LSM_INVITE:-}" ]]; then
  invite="$LSM_INVITE"
fi

if [[ -n "$invite" ]]; then
  # Do not put the invite in argv. Enrollment persists the worker identity in the
  # state volume, then local-shell-mcp re-execs into normal worker run mode.
  unset LSM_INVITE
  printf '%s\n' "$invite" | exec /opt/lsm-venv/bin/python -m local_shell_mcp.main worker connect \
    --server "${LSM_SERVER:-https://local-shell-mcp.fwerkor.eu.org}" \
    --invite-stdin \
    --name "${LSM_NAME:-unist3}" \
    --workdir "${LSM_WORKDIR:-/workspace}"
fi

cat >&2 <<'MSG'
SSH is running, but local-shell-mcp is not enrolled yet.
Set LSM_INVITE (or mount a secret and set LSM_INVITE_FILE), then recreate the
container. Persist /root/.local/state/local-shell-mcp-worker so enrollment survives restarts.
MSG
exec sleep infinity
