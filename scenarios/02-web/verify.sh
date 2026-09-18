#!/usr/bin/env bash
set -euo pipefail
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# Wait for DVWA to answer
for i in $(seq 1 30); do A "curl -s -o /dev/null -w '%{http_code}' http://172.28.0.20/login.php" | grep -q 200 && break; sleep 3; done
A "curl -s -o /dev/null -w '%{http_code}' http://172.28.0.20/login.php" | grep -q 200 \
  || fail "DVWA login.php not serving HTTP 200"

# Juice Shop is up (container listens on :3000 internally, not :80)
for i in $(seq 1 30); do A "curl -s -o /dev/null -w '%{http_code}' http://172.28.0.21:3000/" | grep -q 200 && break; sleep 3; done
A "curl -s http://172.28.0.21:3000/ | grep -qi 'OWASP Juice Shop'" || fail "juice shop not serving"

# Dual host access (spec): DVWA on host :8080, Juice Shop on host :3000.
# Checked from the HOST (no A()) — published ports must actually bind, which
# an internal-only network silently drops. Guards against that regression.
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:8080/login.php || true)
[ "$code" = "200" ] || fail "DVWA not reachable on host port 8080 (got '$code')"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:3000/ || true)
[ "$code" = "200" ] || fail "Juice Shop not reachable on host port 3000 (got '$code')"

echo "PASS: 02-web"
