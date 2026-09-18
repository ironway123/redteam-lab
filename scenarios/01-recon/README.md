# 01-recon — Recon & enumeration

## Objectives

1. Discover all live hosts on `172.28.0.0/24`.
2. Identify every open port and service version.
3. Find the hidden web directory on the web host.
4. Read its flag.

## Setup

```bash
./lab up 01-recon
./lab shell
```

## Hints

<details><summary>Hint 1</summary>Start with host discovery across the whole /24, then port-scan what answers.</details>

<details><summary>Hint 2</summary>Use <code>nmap -sn</code> for a ping sweep to find live hosts, then <code>nmap -sV</code> against those hosts to fingerprint open ports and service versions. Once you know which host is running a web server, brute-force its directory structure with a wordlist-based tool to surface content that isn't linked from the page.</details>

<details><summary>Hint 3</summary>

```bash
nmap -sn 172.28.0.0/24
nmap -sV -p- <host>
gobuster dir -u http://<web> -w /usr/share/wordlists/dirb/common.txt
```

</details>

## Checkpoint

You can `curl` a file under `/backup/` whose contents start with `RECON-FLAG{`.
