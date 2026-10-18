#!/usr/bin/env bash
# Lab 0 environment check. Prints one line per requirement and exits
# non-zero if a required tool is missing. Azure login is reported but
# optional, so students whose Azure sign-up is still pending can pass.
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
fail=0

ok()   { printf "${GREEN}[ OK ]${NC} %-12s %s\n" "$1" "$2"; }
bad()  { printf "${RED}[FAIL]${NC} %-12s %s\n" "$1" "$2"; fail=1; }
warn() { printf "${YELLOW}[WARN]${NC} %-12s %s\n" "$1" "$2"; }

check_tool() {
  local name="$1" cmd="$2"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name" "$(eval "$cmd" 2>/dev/null | head -n1)"
  else
    bad "$name" "not found"
  fi
}

echo "== Required tools =="
check_tool git       "git --version"
check_tool python3   "python3 --version"
check_tool terraform "terraform version | head -n1"
check_tool packer    "packer version"
check_tool az        "az version --query '\"azure-cli\"' -o tsv"
check_tool ansible   "ansible --version"
check_tool docker    "docker --version"
check_tool kubectl   "kubectl version --client 2>/dev/null | head -n1"
check_tool helm      "helm version --short"
check_tool kind      "kind version"

echo
echo "== Git identity =="
name=$(git config user.name || true)
email=$(git config user.email || true)
if [[ -n "$name" && -n "$email" ]]; then
  ok "git config" "$name <$email>"
else
  bad "git config" "set user.name and user.email (see Lab 0, step 3)"
fi

echo
echo "== Azure (optional this week) =="
if az account show >/dev/null 2>&1; then
  offer=$(az account show --query name -o tsv)
  ok "az login" "subscription: $offer"
else
  warn "az login" "not logged in yet (fine if your Azure for Students sign-up is pending)"
fi

echo
if [[ $fail -eq 0 ]]; then
  printf "${GREEN}Environment ready.${NC}\n"
else
  printf "${RED}Some checks failed. Fix them before continuing.${NC}\n"
fi
exit $fail
