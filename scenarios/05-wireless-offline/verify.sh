#!/usr/bin/env bash
# Note: deliberately not using `pipefail` here. `grep -q` exits as soon as it
# finds a match, which can close the pipe while the producer (aircrack-ng)
# is still writing later lines; under pipefail that SIGPIPE becomes the
# pipeline's exit status even though grep matched. The grep exit code alone
# is what these checks care about. (Same gotcha documented in
# scenarios/01-recon/verify.sh.)
set -eu
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# Wait for the generator to drop files into the shared volume
for i in $(seq 1 20); do A "test -f /root/wifi/wpa.cap" && break; sleep 2; done
A "test -f /root/wifi/wpa.cap" || fail "wpa.cap not generated"

# aircrack-ng recovers the known passphrase 'biscotte'
A "aircrack-ng -w /root/wifi/lab.lst -b 00:0D:93:EB:B0:8C /root/wifi/wpa.cap" \
  | grep -q "KEY FOUND! \[ biscotte \]" || fail "aircrack did not recover key"

echo "PASS: 05-wireless-offline"
