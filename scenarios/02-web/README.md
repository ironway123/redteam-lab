# 02-web — Web app exploitation (DVWA + OWASP Juice Shop)

## Objectives

1. Dump the DVWA `users` table via SQL injection.
2. Upload a web shell and run a command through it.
3. Solve 3 OWASP Juice Shop challenges (track progress on its `/#/score-board`).

## Setup

```bash
./lab up 02-web
```

- DVWA: open `http://localhost:8080` in a browser.
  - Log in with `admin` / `password`.
  - First run only: if you're bounced to a setup page, browse to
    `http://localhost:8080/setup.php` and click **Create / Reset Database**.
  - Set **DVWA Security** (left nav) to **Low** before starting — the
    exercises below assume no input sanitization.
- Juice Shop: open `http://localhost:3000` in a browser. No login needed to
  start; the score board is at `http://localhost:3000/#/score-board`.

## Hints

<details><summary>Hint 1</summary>The <code>id</code> parameter on DVWA's SQL Injection page is not sanitized at Security = Low.</details>

<details><summary>Hint 2</summary>Try <code>' OR '1'='1</code> manually in the <code>id</code> field first to confirm the injection, then automate extraction with <code>sqlmap</code>.</details>

<details><summary>Hint 3</summary>

```bash
sqlmap -u "http://172.28.0.20/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=<yours>; security=low" --batch --dump -D dvwa -T users
```

See `SOLUTION.md` for the full command shape and the file-upload web shell steps.

</details>

## Checkpoint

You can display the DVWA `users` table (usernames + password hashes).

## Verify note

`verify.sh` asserts a lighter, reliable signal (DVWA serves `login.php` with
HTTP 200 and Juice Shop serves its landing page on `:3000`) rather than
scripting the full authenticated sqlmap dump end-to-end. Reason: DVWA ships
with no database until `setup.php`'s "Create / Reset Database" is submitted,
and every `./lab reset 02-web` recreates the DVWA container from scratch
(its DB lives inside the container, not a persisted volume), so a fully
scripted checkpoint would also have to automate that one-time DB-init POST
on every run in addition to the login/anti-CSRF-token/cookie dance — real
but extra fragility for a `verify.sh` gate, exactly the flakiness this
scenario's task brief anticipated and pre-approved a lighter signal for.

The full exploit chain is real and was manually verified end-to-end against
this scenario (DB init -> login -> set Security=Low -> `sqlmap --dump` on
the `users` table -> file-upload web shell -> RCE via the shell). All of it
is documented, command-by-command, in `SOLUTION.md` — that's the actual
checkpoint to run and confirm works by hand (or via the attacker box).
