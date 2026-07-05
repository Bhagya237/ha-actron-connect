#!/usr/bin/env bash
#
# Turn the Actron AC ON, enable ALL zones, and set the target temperature.
# Uses the local write channel:  GET http://<AC>/4.json?DA=<url-encoded JSON>
#
# Usage:
#   ./actron_on.sh <AC_IP>          # ON, all zones, 24C (default)
#   ./actron_on.sh <AC_IP> 22.5     # ON, all zones, custom temp
#
# WARNING: this physically starts the air conditioner.
#
set -u

AC="${1:-}"
TEMP="${2:-24}"
if [[ -z "$AC" ]]; then echo "Usage: $0 <AC_IP> [temp]" >&2; exit 1; fi
AC="${AC#http://}"; AC="${AC#https://}"; AC="${AC%/}"

send() {  # send one DA command, print the HTTP code
  local da="$1" code
  code=$(curl -s -G -o /dev/null -m 5 -w '%{http_code}' \
         --data-urlencode "DA=$da" "http://$AC/4.json")
  printf '  DA %-42s -> HTTP %s\n' "$da" "$code"
  sleep 1
}

state() {
  echo "  Settings: $(curl -s -m 3 "http://$AC/4.json" | tr -d ' \n')"
  echo "  Live    : $(curl -s -m 3 "http://$AC/6.json" | tr -d ' \n')"
}

echo "=== BEFORE ==="; state
echo
echo ">>> Turning ON, enabling all zones, setting ${TEMP}C"
send '{"amOn":1}'
send '{"enabledZones":[1,1,1,1,1,1,1,1]}'
send "{\"tempTarget\":${TEMP}}"
echo
sleep 2
echo "=== AFTER ==="; state
