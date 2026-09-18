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
