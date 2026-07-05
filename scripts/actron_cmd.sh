#!/usr/bin/env bash
#
# Send a LOCAL command to an Actron Connect module and show before/after state.
#
# Discovered mechanism (firmware V0.18G, ESP Plus):
#   - The module's local web server only implements GET (PUT/POST -> 501).
#   - Commands are sent via a GET with a URL-encoded "DA" JSON envelope:
#         GET http://<AC>/4.json?DA=<json>
#     using the SAME DA payloads as the cloud, e.g. {"amOn":1}, {"mode":2},
#     {"fanSpeed":2}, {"tempTarget":22.0}, {"enabledZones":[1,0,0,0,0,0,0,0]}.
#   - Plain query params (?tempTarget=22) return 200 but do NOTHING; the DA
#     envelope is required.
#
# Usage:
#   ./actron_cmd.sh <AC_IP>                         # READ ONLY: dump state
#   ./actron_cmd.sh <AC_IP> '{"tempTarget":22.0}'   # send a DA command
#   ./actron_cmd.sh <AC_IP> '{"mode":2}'            # 0=auto 1=heat 2=cool 3=fan
#   ./actron_cmd.sh <AC_IP> '{"fanSpeed":1}'        # 0=low 1=med 2=high
#   ./actron_cmd.sh <AC_IP> '{"amOn":1}'            # 1=on 0=off  (physically starts AC!)
#
# WARNING: sending amOn/mode can physically start the air conditioner.
#
set -u

AC="${1:-}"
DA="${2:-}"

if [[ -z "$AC" ]]; then
  echo "Usage: $0 <AC_IP> ['{\"DA-json\"}']" >&2
  exit 1
fi
AC="${AC#http://}"; AC="${AC#https://}"; AC="${AC%/}"

state() {
  echo "  Settings(4.json): $(curl -s -m 3 "http://$AC/4.json" | tr -d ' \n')"
  echo "  Live(6.json)    : $(curl -s -m 3 "http://$AC/6.json" | tr -d ' \n')"
}

echo "=== BEFORE ==="
state

if [[ -n "$DA" ]]; then
  echo
  echo ">>> Sending DA command: $DA"
  # curl -G + --data-urlencode builds ?DA=<url-encoded json> safely
  code=$(curl -s -G -o /dev/null -m 5 -w '%{http_code}' \
         --data-urlencode "DA=$DA" "http://$AC/4.json")
  echo ">>> HTTP $code"
  sleep 2
  echo
  echo "=== AFTER ==="
  state
fi
