# CID compute-node image

CUDA training container for CID compute nodes, with SSH and `local-shell-mcp` worker preinstalled.
It contains no credentials or worker identity.

## Image

```text
ghcr.io/fwerkor/cid-worker-image:cuda12.4-lsm4.3.2
```

The host must have an NVIDIA driver and NVIDIA Container Toolkit. Pass both GPUs with `--gpus all`.

## Recommended deployment

Persist both `/workspace` and the worker state directory. Prefer an SSH public key and a mounted
invite secret rather than passwords/environment-variable secrets.

```bash
docker run -d --name unist3 \
  --restart unless-stopped \
  --gpus all \
  --ipc=host \
  --shm-size=32g \
  -p 2222:22 \
  -e LSM_NAME=unist3 \
  -e LSM_SERVER=https://local-shell-mcp.fwerkor.eu.org \
  -e SSH_PUBLIC_KEY='ssh-ed25519 AAAA... user@host' \
  -e LSM_INVITE_FILE=/run/secrets/lsm_invite \
  -v unist3-workspace:/workspace \
  -v unist3-lsm-state:/root/.local/state/local-shell-mcp-worker \
  -v /host/path/lsm_invite:/run/secrets/lsm_invite:ro \
  ghcr.io/fwerkor/cid-worker-image:cuda12.4-lsm4.3.2
```

If the deployment platform only supports environment variables, `LSM_INVITE` is also accepted.
After the first successful enrollment the invite is no longer needed, as long as the LSM state
volume is retained.

## Included tools

- CUDA 12.4.1 + cuDNN development image (includes `nvcc`)
- Python 3.12 managed by `uv`
- local-shell-mcp 4.3.2, including Playwright Chromium
- OpenSSH server/client
- git + git-lfs, curl/wget, rsync, tmux, ripgrep, jq
- build-essential, CMake, Ninja, pkg-config
- common diagnostics (`htop`, `lsof`, `iproute2`, `ping`, etc.)

PyTorch is intentionally not pinned in the base image. Project environments can install the
appropriate PyTorch/CUDA wheel without rebuilding the node image.
