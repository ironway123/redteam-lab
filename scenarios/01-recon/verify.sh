#!/usr/bin/env bash
# Note: deliberately not using `pipefail` here. `grep -q` exits as soon as it
# finds a match, which can close the pipe while the producer (gobuster/nmap
# inside `docker exec`) is still writing later lines; under pipefail that
# SIGPIPE becomes the pipeline's exit status even though grep matched. The
# grep exit code alone is what these checks care about.
set -eu
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# All four hosts discoverable
A "nmap -sn 172.28.0.10-13 -oG - | grep -c Up" | grep -q '^4$' || fail "not all hosts up"
# Service/version detection sees ssh + http
A "nmap -sV -p22,80,445 172.28.0.10-13" | grep -qi "OpenSSH" || fail "no ssh banner"
A "nmap -sV -p80 172.28.0.10"          | grep -qi "nginx"   || fail "no http banner"
# Hidden directory brute-force finds /backup and it holds the flag string
A "gobuster dir -u http://172.28.0.10 -w /usr/share/wordlists/dirb/common.txt -q -t 20" \
  | grep -q "/backup" || fail "gobuster did not find /backup"
A "curl -s http://172.28.0.10/backup/creds.txt" | grep -q "RECON-FLAG" || fail "flag not readable"

echo "PASS: 01-recon"
