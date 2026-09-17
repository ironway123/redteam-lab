#!/usr/bin/env sh
set -e
# Copy the bundled aircrack-ng training capture (known passphrase: biscotto) and
# wordlist into the shared volume. Synthetic training data, not a real capture.
OUT=/out
cp /seed/lab.lst "$OUT/lab.lst"
cp /seed/wpa.cap "$OUT/wpa.cap"
echo "wireless training data ready in $OUT"
