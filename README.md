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
