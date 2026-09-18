#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail() { echo "FAIL: $1"; ./lab down --all >/dev/null 2>&1 || true; exit 1; }

./lab up base
trap './lab down --all >/dev/null 2>&1 || true' EXIT

docker ps --format '{{.Names}}' | grep -qx redteam-lab-attacker || fail "attacker not running"

for tool in nmap gobuster ffuf whatweb nc curl smbclient sqlmap hydra msfconsole \
            hashcat john aircrack-ng hcxpcapngtool; do
  docker exec redteam-lab-attacker bash -lc "command -v $tool" >/dev/null \
    || fail "missing tool: $tool"
done

docker exec redteam-lab-attacker test -f /opt/privesc/linpeas.sh || fail "linpeas missing"
docker exec redteam-lab-attacker test -f /usr/share/wordlists/rockyou.txt || fail "rockyou missing"
docker exec redteam-lab-attacker ip -o -4 addr show \
  | grep -q '172.28.0.5' || fail "attacker not on 172.28.0.5"

echo "PASS: verify-base"
