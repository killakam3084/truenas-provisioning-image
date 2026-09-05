#!/bin/sh
set -u

TRUENAS_USER="${TRUENAS_USER:-truenas_admin}"
TRUENAS_UID="${TRUENAS_UID:-950}"
TRUENAS_GID="${TRUENAS_GID:-950}"
TRUENAS_HOME="/home/${TRUENAS_USER}"

run_as_truenas() {
  HOME="$TRUENAS_HOME" gosu "$TRUENAS_USER" "$@"
}

# Ensure the runtime account matches expected host identity even if image defaults drift.
if ! id "$TRUENAS_USER" >/dev/null 2>&1; then
  groupadd -g "$TRUENAS_GID" "$TRUENAS_USER" 2>/dev/null || true
  useradd -m -u "$TRUENAS_UID" -g "$TRUENAS_GID" -s /bin/bash "$TRUENAS_USER" 2>/dev/null || true
fi

# Allow truenas_admin to access Docker socket by matching socket group id at runtime.
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c %g /var/run/docker.sock)
  if ! getent group "$DOCKER_GID" >/dev/null 2>&1; then
    groupadd -g "$DOCKER_GID" dockersock >/dev/null 2>&1 || true
  fi
  DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
  if [ -n "$DOCKER_GROUP" ]; then
    usermod -aG "$DOCKER_GROUP" "$TRUENAS_USER" >/dev/null 2>&1 || true
  fi
fi

mkdir -p "$TRUENAS_HOME"
chown -R "$TRUENAS_UID:$TRUENAS_GID" "$TRUENAS_HOME" 2>/dev/null || true

# Allow git to operate on repos owned by other users (provisioner runs as root,
# repo may be owned by truenas_admin on the host volume).
run_as_truenas git config --global --add safe.directory "$REPO_DEST"
run_as_truenas git config --global --add safe.directory '*'

run_as_truenas git config --global user.name "killakam3084"
run_as_truenas git config --global user.email "cameron.rison@gmail.com"

# Clone the monorepo if not already present; otherwise refresh in a fail-safe way.
if [ ! -d "$REPO_DEST/.git" ]; then
  echo "[provisioner] Cloning $REPO_URL into $REPO_DEST"
  run_as_truenas git clone --recurse-submodules "$REPO_URL" "$REPO_DEST" || {
    echo "[provisioner] Clone failed; container will remain alive for manual recovery" >&2
  }
else
  echo "[provisioner] Repo already present at $REPO_DEST — refreshing"
  run_as_truenas git -C "$REPO_DEST" fetch --all --prune --tags || \
    echo "[provisioner] Fetch failed; continuing with existing checkout"

  if run_as_truenas git -C "$REPO_DEST" rev-parse --verify main >/dev/null 2>&1; then
    run_as_truenas git -C "$REPO_DEST" checkout main >/dev/null 2>&1 || true
    if run_as_truenas git -C "$REPO_DEST" merge --ff-only origin/main >/dev/null 2>&1; then
      echo "[provisioner] Fast-forwarded to origin/main"
    else
      echo "[provisioner] Local checkout diverged from origin/main; leaving repo intact so container stays alive"
    fi
  else
    run_as_truenas git -C "$REPO_DEST" checkout -B main origin/main >/dev/null 2>&1 || true
  fi

  run_as_truenas git -C "$REPO_DEST" submodule sync --recursive || true
  run_as_truenas git -C "$REPO_DEST" submodule update --init --recursive || true
fi

echo "[provisioner] Bootstrap complete. Repo at $REPO_DEST"

# Keep the container running so it can be exec'd into for ad-hoc tasks.
exec tail -f /dev/null
