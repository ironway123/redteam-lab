# 03-services — Solution walkthrough

All commands below are run from inside the attacker box (`./lab shell`),
which sits at `172.28.0.5` on the lab's private `172.28.0.0/24` network.
The four targets are FTP `172.28.0.30`, SMB `172.28.0.31`, SSH
`172.28.0.32`, and web `172.28.0.33`.

## 1. FTP (anonymous)

```bash
curl ftp://172.28.0.30/pub/flag.txt --user anonymous:anon
```

**Why this works:** the server is configured with `anonymous_enable=YES`
and `no_anon_password=YES` — anyone can log in as the well-known
`anonymous` account with any (or no) real password and browse/read
whatever is under the anonymous root. Misconfigured anonymous FTP access
is one of the oldest and most common ways to leak files that were never
meant to be public.

## 2. SMB (null session)

```bash
smbclient -N -L //172.28.0.31 ; smbclient //172.28.0.31/public -N -c 'get flag.txt'
```

**Why this works:** the `-N` flag tells `smbclient` to attempt the
connection with no password — a "null session." The share is exported
with guest access allowed (`public;...;yes;no;yes;all` — guest ok, not
read-only... in this case writable — no password required), so an
unauthenticated client can list shares and pull files straight off it.
Null-session SMB is a classic misconfiguration: it was historically also a
path to enumerating usernames, groups, and policies on Windows hosts, not
just reading files.

## 3. SSH — crack the password, then use it two ways

Manual crack + login:

```bash
hydra -t 4 -l svc -P /usr/share/wordlists/rockyou.txt -f ssh://172.28.0.32
ssh svc@172.28.0.32           # password from hydra (password123, ~line 1400 of rockyou)
```

> **`-t 4` matters.** hydra defaults to 16 parallel tasks, but SSH servers cap
> concurrent unauthenticated connections (`MaxStartups`) and modern OpenSSH
> (9.8+) also throttles a source IP that racks up failed logins
> (`PerSourcePenalties`). Fire all 16 at once and hydra's children die with
> "all children were disabled due too many connection errors" — and worse, the
> penalty can then block you for a minute or two. Four tasks stays under those
> limits and cracks reliably. (This lab's target has those defenses relaxed so
> the attack is teachable, but `-t 4` is the right habit against any real box.)

Then, the same credential, via Metasploit (compare the workflow):

```bash
msfconsole -q -x 'use auxiliary/scanner/ssh/ssh_login; set RHOSTS 172.28.0.32; \
  set USERNAME svc; set PASS_FILE /usr/share/wordlists/rockyou.txt; run; sessions -l; exit'
```

**Why this works:** the `svc` account was created with the weak password
`password123`, guessable by brute force against a small or common
wordlist. `hydra` demonstrates password guessing itself — it tries
candidates from a wordlist against the live service until one succeeds
and simply reports the working credential pair. `ssh_login` performs the
identical guess-and-authenticate logic, but because it runs inside the
Metasploit framework, a successful login is captured as an **authenticated
session object** (`sessions -l` lists it) that other modules and
post-exploitation tooling can immediately reuse — the practical difference
between "I found a password" and "I have a live, scriptable foothold on
the box."

## 4. Web command injection

```bash
curl 'http://172.28.0.33/cmd.php?host=127.0.0.1;cat /flag.txt'
```

**Why this works:** `cmd.php` takes the `host` query parameter and
concatenates it directly into a shell command (`system("ping -c1 " .
$host)`) with no validation or escaping. Because `;` is a shell
metacharacter that separates sequential commands, `127.0.0.1;cat
/flag.txt` doesn't just get passed as an argument to `ping` — it closes
out the `ping` invocation and starts a brand-new command (`cat
/flag.txt`) that the shell happily runs with the same privileges as the
web server. This is the general shape of every command-injection bug:
untrusted input reaches a call that hands a string to a shell, and any
shell metacharacter (`;`, `|`, `&&`, backticks, `$(...)`) in that input
can be used to run something the developer never intended.

## Flags

```
FTP-FLAG{anon_ftp_is_a_gift}
SMB-FLAG{null_s3ss10ns_l3ak}
WEB-FLAG{cmd_1nj3ct10n_to_rce}
```

(SSH has no flag string — the checkpoint is the cracked credential plus an
open Metasploit session, both demonstrated above.)
