#!/usr/bin/env bash
#
# Probe an Actron Connect module's local HTTP endpoints.
# Read-only: only issues GET requests. Safe to run against your AC.
#
# Usage:
#   ./probe_actron.sh <AC_IP_OR_HOST>            # probe 0.json .. 12.json
#   ./probe_actron.sh <AC_IP_OR_HOST> 0 20       # custom range
#
# Output is printed to the screen AND saved to a timestamped file so we
# can drop the real JSON shapes into tests/fixtures/.

set -u

HOST="${1:-}"
FROM="${2:-0}"
TO="${3:-12}"

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <AC_IP_OR_HOST> [from] [to]" >&2
  echo "Example: $0 192.168.1.50" >&2
  exit 1
fi

# strip any accidental scheme the user pastes in
HOST="${HOST#http://}"
HOST="${HOST#https://}"
HOST="${HOST%/}"

OUT="actron_probe_$(date +%Y%m%d_%H%M%S).txt"
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

echo "Probing http://$HOST/  (endpoints $FROM.json .. $TO.json)"
echo "Saving full output to: $OUT"
echo

{
  echo "# Actron Connect local probe"
  echo "# host: $HOST"
  echo "# date: $(date)"
  echo
} > "$OUT"

for i in $(seq "$FROM" "$TO"); do
  url="http://$HOST/$i.json"

  # capture body + trailing HTTP status code
  resp="$(curl -s -m 4 -w $'\n__HTTP_%{http_code}__' "$url" 2>/dev/null)"
  code="$(printf '%s' "$resp" | sed -n 's/.*__HTTP_\([0-9]*\)__$/\1/p')"
  body="$(printf '%s' "$resp" | sed 's/__HTTP_[0-9]*__$//')"

  header="=== $i.json  (HTTP ${code:-ERR}) ==="
  echo "$header"

  if [[ "$code" == "200" && -n "$body" ]]; then
    if [[ "$HAVE_JQ" == "1" ]] && printf '%s' "$body" | jq . >/dev/null 2>&1; then
      pretty="$(printf '%s' "$body" | jq .)"
    else
      pretty="$body"
    fi
    echo "$pretty"
  else
    echo "(no usable body)"
  fi
  echo

  {
    echo "$header"
    [[ "$code" == "200" && -n "$body" ]] && printf '%s\n' "${pretty:-$body}" || echo "(no usable body)"
    echo
  } >> "$OUT"
done

echo "Done. Share $OUT (or paste the output above) and I'll map what we're missing."
