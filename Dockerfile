FROM debian:bookworm-slim

ARG INFISICAL_VERSION=0.37.4
ARG TARGETARCH
ARG TRUENAS_UID=950
ARG TRUENAS_GID=950
ARG TRUENAS_USER=truenas_admin

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    curl \
    zsh \
    tree \
    unzip \
    openssh-client \
    gosu \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Create a host-aligned user/group for repo and dotfile operations.
RUN groupadd --gid ${TRUENAS_GID} ${TRUENAS_USER} \
  && useradd --uid ${TRUENAS_UID} --gid ${TRUENAS_GID} --create-home --shell /bin/bash ${TRUENAS_USER}

# Docker CLI (no daemon — connects via socket mount)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
     https://download.docker.com/linux/debian bookworm stable" \
     > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# Infisical CLI
RUN curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | bash \
  && apt-get install -y infisical \
  && rm -rf /var/lib/apt/lists/*

# Entrypoint: clone/pull monorepo into the mounted volume, then keep container alive
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV REPO_URL=git@github.com:killakam3084/truenas.git
ENV REPO_DEST=/mnt/cell_block_d/repos/truenas
ENV TRUENAS_USER=truenas_admin
ENV TRUENAS_UID=950
ENV TRUENAS_GID=950
ENV HOME=/home/truenas_admin

ENTRYPOINT ["/entrypoint.sh"]
