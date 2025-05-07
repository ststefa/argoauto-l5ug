# https://just.systems/man/en/

default:
  just --list

# Check whether all defined files are sops-encrypted
sops-check:
  #!/usr/bin/env bash
  set -euo pipefail
  RC=0
  while read -r REGEX; do
      while read -r FILE; do
          if ! grep -q 'ENC\[.*\]' "$FILE"; then
              echo "not encrypted: $FILE"
              RC=1
          fi
      done < <(find . -type f -mindepth 2 | grep -E "$REGEX")
  done < <(grep 'path_regex:' ".sops.yaml" | sed -E 's/.*path_regex:\s*["'\'']?(.*?)["'\'']?$/\1/')
  exit $RC

# Sops-encrypt defined files
sops-encrypt:
  #!/usr/bin/env bash
  set -euo pipefail
  while read -r REGEX; do
      while read -r FILE; do
        if grep -q 'ENC\[.*\]' "$FILE"; then
            echo "skip: $FILE (already encrypted)"
        else
            echo "encrypt: $FILE"
            sops -e -i "$FILE"
        fi
      done < <(find . -type f -mindepth 2 | grep -E "$REGEX")
  done < <(grep 'path_regex:' ".sops.yaml" | sed -E 's/.*path_regex:\s*["'\'']?(.*?)["'\'']?$/\1/')
