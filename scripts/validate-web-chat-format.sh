#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$1" >&2
}

test ! -f "_meta.yaml" || fail "Do not create root _meta.yaml. It can hide the portal root node."
test -d "api" || fail "Missing api/ directory."
test -f "api/_meta.yaml" || fail "Missing api/_meta.yaml."

grep -Eq '^title:[[:space:]]*.+' api/_meta.yaml || fail "api/_meta.yaml must define title."

while IFS= read -r file; do
  case "$file" in
    */_meta.yaml)
      grep -Eq '^title:[[:space:]]*.+' "$file" || fail "$file must define title."
      ;;
  esac
done < <(find api -name '_meta.yaml' -type f | sort)

while IFS= read -r file; do
  first_line="$(sed -n '1p' "$file")"
  test "$first_line" = "---" || fail "$file must start with YAML front matter."

  if ! sed -n '1,12p' "$file" | grep -Eq '^title:[[:space:]]*.+'; then
    fail "$file must put title in the first front matter block."
  fi

  if ! sed -n '2,20p' "$file" | grep -Eq '^---[[:space:]]*$'; then
    fail "$file front matter must be closed near the top of the file."
  fi
done < <(find api -name '*.md' -type f | sort)

while IFS= read -r file; do
  case "$file" in
    ./README.md|./docs/*)
      warn "$file is outside api/ and will not be visible in web-chat portal."
      ;;
    ./api/*)
      ;;
    *)
      warn "$file is outside api/. It is maintainer-only unless sync hook rules change."
      ;;
  esac
done < <(find . -name '*.md' -type f | sort)

printf 'OK: web-chat portal structure looks valid.\n'

