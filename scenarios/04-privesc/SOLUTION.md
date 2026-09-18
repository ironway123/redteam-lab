# 04-privesc — Solution walkthrough

All commands below are run as `lowpriv` on the target `172.28.0.40`,
reached over SSH from inside the attacker box (`./lab shell`):

```bash
ssh lowpriv@172.28.0.40   # password: lowpriv
```

Exactly one of the four escalation paths below is live at a time,
selected by the `PRIVESC_PATH` environment variable at container start
(default `suid`). Re-roll with `PRIVESC_PATH=<path> ./lab reset
04-privesc`.

## Enumerate

```bash
find / -perm -4000 -type f 2>/dev/null   # SUID binaries
sudo -l                                   # sudo rights
getcap -r / 2>/dev/null                   # file capabilities
cat /etc/cron.d/* 2>/dev/null             # root-run cron jobs
```

Whichever of these turns up something unusual (`/usr/local/bin/backup`
SUID, `NOPASSWD: /usr/bin/find` in sudoers, `cap_setuid` on
`/usr/local/bin/pypriv`, or a world-writable script run by root's crontab)
tells you which path is active.

## suid — a SUID copy of bash

```bash
/usr/local/bin/backup -p -c 'cat /root/flag.txt'
```

**Why this works:** `/usr/local/bin/backup` is a copy of `/bin/bash` with
the setuid bit set (`chmod 4755`) and owned by root, so it executes with
an effective UID of 0 no matter who runs it. Bash normally drops
privileges when it detects that its real and effective UIDs differ (to
stop exactly this kind of abuse), unless it is invoked with `-p`, which
tells it to preserve the privileged (effective) UID instead of dropping
it. `-c '...'` then runs the given command with that preserved root
privilege. Any SUID-root binary that can execute arbitrary commands (a
shell, `find`, `vim`, etc. — see GTFOBins) is a privilege escalation path
by the same mechanism.

## sudo — NOPASSWD find (GTFOBins)

```bash
sudo find . -exec cat /root/flag.txt \; -quit
```

**Why this works:** `/etc/sudoers.d/lowpriv` grants `lowpriv` passwordless
sudo rights to run `/usr/bin/find` as any user, including root. `find`
supports an `-exec` action that runs an arbitrary command for each
matched file, and that command inherits `find`'s own (now root)
privileges. This is a well-known GTFOBins technique: any sudo rule that
allows a binary capable of spawning or executing other programs
effectively grants full root, regardless of how narrow the intended use
of that binary seemed.

## cron — world-writable script run by root

```bash
echo 'cat /root/flag.txt > /tmp/out.txt; chmod 666 /tmp/out.txt' > /usr/local/bin/task.sh
sleep 65
cat /tmp/out.txt
```

**Why this works:** `/etc/cron.d/task` schedules `/usr/local/bin/task.sh`
to run as `root` every minute, but the script itself is `chmod 777` —
writable by any user, including `lowpriv`. Cron doesn't care who last
wrote the script; it just executes whatever is at that path with the
privilege the crontab entry specifies. Overwriting the script with a
command that copies the flag somewhere `lowpriv` can read (and loosens
its permissions) turns the next scheduled run into a root-privileged read
on your behalf. The lesson: a script's execution privilege is only as
trustworthy as its write permissions.

## cap — cap_setuid on a Python copy

```bash
/usr/local/bin/pypriv -c 'import os; os.setuid(0); os.system("cat /root/flag.txt")'
```

**Why this works:** Linux file capabilities let a binary be granted a
specific slice of root's powers without the all-or-nothing SUID bit.
`/usr/local/bin/pypriv` (a copy of `python3`) has been given
`cap_setuid+ep`, meaning it can call `setuid()` to change its effective
UID to any value, including 0, even though it isn't setuid-root itself.
Because it's a full Python interpreter, that capability is trivially
enough to become root: call `os.setuid(0)` from inside a `-c` one-liner
and then shell out with the new privilege. Any interpreter or
general-purpose binary granted `cap_setuid` (or several other
capabilities — see GTFOBins' capabilities section) is equivalent to a
root shell.

## Flags

```
PRIVESC-FLAG{r00t_via_suid}
PRIVESC-FLAG{r00t_via_sudo}
PRIVESC-FLAG{r00t_via_cron}
PRIVESC-FLAG{r00t_via_cap}
```

The active flag's suffix always matches the current `PRIVESC_PATH`.
