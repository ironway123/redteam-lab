#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "FAIL: $1"; exit 1; }

bash -n lab || fail "lab has a syntax error"
[ -x lab ] || fail "lab is not executable"

./lab help | grep -q "redteam-lab control script" || fail "help banner missing"
list_output="$(./lab list)"
grep -qi "01-recon" <<<"$list_output" || fail "list should show scenarios"
grep -qi "authorization" README.md || fail "README missing authorization/safety notice"

echo "PASS: lab-smoke"
