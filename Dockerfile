FROM debian:bookworm-slim

ARG INFISICAL_VERSION=0.37.4
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    curl \
    tree \
    openssh-client \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

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

ENTRYPOINT ["/entrypoint.sh"]
