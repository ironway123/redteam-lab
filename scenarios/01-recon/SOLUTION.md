# 01-recon — Solution walkthrough

All commands below are run from inside the attacker box (`./lab shell`), which
sits at `172.28.0.5` on the lab's private `172.28.0.0/24` network.

```bash
nmap -sn 172.28.0.0/24                      # host discovery — who is alive
nmap -sV -p- 172.28.0.10                     # full port + version sweep of the web host
nmap -sV -p22,80,139,445 172.28.0.10-13      # fingerprint the range
gobuster dir -u http://172.28.0.10 -w /usr/share/wordlists/dirb/common.txt
curl http://172.28.0.10/backup/creds.txt     # the flag + leaked staging creds
```

## Why each step, in order

**`nmap -sn 172.28.0.0/24`** — a ping sweep (no ports scanned) across the
whole lab subnet. Discovery always comes before scanning: you don't yet know
which of the 254 possible addresses are actually hosts, so there is no point
throwing a full port scan at addresses that don't answer. This step alone is
enough to confirm the four targets — `172.28.0.10` through `.13` — are up.

**`nmap -sV -p- 172.28.0.10`** — once a host is confirmed alive, a full
(`-p-`, all 65535 TCP ports) scan with version detection (`-sV`) on the web
host shows exactly what's listening and what software/version answers on
each port. `-sV` matters beyond "is it open": mapping a port to a concrete
service and version is what lets you look up known vulnerabilities and pick
the right exploitation technique later — recon isn't just a port list, it's
an actionable inventory.

**`nmap -sV -p22,80,139,445 172.28.0.10-13`** — with the interesting web
host already characterized, sweep the well-known ports for the services this
lab cares about (`22` ssh, `80` http, `139`/`445` smb) across the whole
`.10-13` range in one pass. This is faster than a full `-p-` sweep of every
host and confirms which host is which role: `.10` answers on 80 with an
`nginx` banner, `.11` answers on 22 with an `OpenSSH` banner, `.12` answers
on 139/445 as the SMB target, and `.13` is the multi-service box.

**`gobuster dir -u http://172.28.0.10 -w /usr/share/wordlists/dirb/common.txt`**
— the web host's front page (`index.html`) doesn't link anywhere interesting,
but a comment in the HTML source hints that "old files are in /backup".
Directory brute-forcing surfaces content that exists on the server but isn't
linked from anywhere you can click — exactly what gobuster is for: it walks
a wordlist of common directory/file names against the target and reports
what actually resolves (here, a `301` redirect to `/backup/`).

**`curl http://172.28.0.10/backup/creds.txt`** — with the hidden directory
found, fetch the file directly. It contains the checkpoint flag
(`RECON-FLAG{h1dden_d1rs_g1ve_up_secrets}`) and a leaked staging credential
pair, illustrating a common real-world finding: forgotten backup directories
left on production-facing web servers leak far more than harmless test
files.

## Flag

```
RECON-FLAG{h1dden_d1rs_g1ve_up_secrets}
```
