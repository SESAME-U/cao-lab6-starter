#!/usr/bin/env bash
# Runs once when the codespace is created. Installs the tools that are not
# available as dev container features. Safe to re-run (idempotent).
set -euo pipefail

echo "==> Installing Ansible (user scope, via pipx)"
if ! command -v ansible >/dev/null 2>&1; then
  python3 -m pip install --user --quiet pipx
  python3 -m pipx ensurepath >/dev/null
  python3 -m pipx install --include-deps ansible >/dev/null
else
  echo "    already installed, skipping"
fi

echo "==> Installing Packer (HashiCorp apt repository)"
if ! command -v packer >/dev/null 2>&1; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y -qq packer >/dev/null
else
  echo "    already installed, skipping"
fi

echo "==> Installing lab test tools (pytest, PyYAML, yamllint)"
python3 -m pip install --user --quiet pytest pyyaml yamllint

echo "==> Creating your lab SSH key (~/.ssh/cao_lab) if missing"
[[ -f "$HOME/.ssh/cao_lab" ]] || ssh-keygen -q -t ed25519 -N "" -f "$HOME/.ssh/cao_lab" -C "cao-lab"

echo "==> Installing kind (Kubernetes in Docker)"
KIND_VERSION="v0.27.0"
if ! command -v kind >/dev/null 2>&1; then
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
  rm -f /tmp/kind
else
  echo "    already installed, skipping"
fi

echo "==> Making course scripts executable"
chmod +x scripts/*.sh

echo
echo "Toolbox ready. Run:  make check"
