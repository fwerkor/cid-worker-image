FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG LSM_VERSION=4.3.2

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/opt/lsm-venv/bin:/root/.local/bin:/usr/local/bin:/usr/bin:/bin \
    LSM_SERVER=https://local-shell-mcp.fwerkor.eu.org \
    LSM_NAME=unist3 \
    LSM_WORKDIR=/workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git git-lfs openssh-server openssh-client \
      tmux rsync ripgrep jq less vim-tiny nano htop tree unzip zip zstd \
      procps psmisc iproute2 iputils-ping net-tools dnsutils lsof \
      build-essential cmake ninja-build pkg-config libnuma-dev \
      tini sudo locales tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd /workspace /root/.ssh \
    && chmod 700 /root/.ssh \
    && git lfs install --system

# Ubuntu 22.04 ships Python 3.10, while local-shell-mcp >=4 requires Python >=3.11.
# uv gives us a pinned, isolated Python without adding a third-party apt repository.
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
    && uv python install 3.12 \
    && uv venv --python 3.12 /opt/lsm-venv \
    && uv pip install --python /opt/lsm-venv/bin/python "local-shell-mcp==${LSM_VERSION}" \
    && /opt/lsm-venv/bin/python -m playwright install --with-deps chromium \
    && rm -rf /root/.cache/uv /root/.cache/pip /var/lib/apt/lists/*

COPY sshd_config /etc/ssh/sshd_config.d/99-unist3.conf
COPY entrypoint.sh /usr/local/bin/unist3-entrypoint
RUN chmod 0755 /usr/local/bin/unist3-entrypoint \
    && chmod 0644 /etc/ssh/sshd_config.d/99-unist3.conf

WORKDIR /workspace
EXPOSE 22
VOLUME ["/workspace", "/root/.local/state/local-shell-mcp-worker"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/unist3-entrypoint"]
