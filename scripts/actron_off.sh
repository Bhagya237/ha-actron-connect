#!/usr/bin/env bash
#
# Turn the Actron AC OFF via the local write channel.
# Optionally restore the original zones/temp we started testing with.
#
# Usage:
#   ./actron_off.sh <AC_IP>            # just turn off (leaves temp/zones as-is)
#   ./actron_off.sh <AC_IP> restore    # off + restore temp 22.0 and single zone
#
set -u

AC="${1:-}"
MODE="${2:-}"
if [[ -z "$AC" ]]; then echo "Usage: $0 <AC_IP> [restore]" >&2; exit 1; fi
AC="${AC#http://}"; AC="${AC#https://}"; AC="${AC%/}"

send() {
  local da="$1" code
  code=$(curl -s -G -o /dev/null -m 5 -w '%{http_code}' \
         --data-urlencode "DA=$da" "http://$AC/4.json")
  printf '  DA %-42s -> HTTP %s\n' "$da" "$code"
  sleep 1
}

echo ">>> Turning OFF"
send '{"amOn":0}'
if [[ "$MODE" == "restore" ]]; then
  echo ">>> Restoring temp 22.0 and single zone"
  send '{"tempTarget":22.0}'
  send '{"enabledZones":[1,0,0,0,0,0,0,0]}'
fi
sleep 2
echo "Settings: $(curl -s -m 3 "http://$AC/4.json" | tr -d ' \n')"
echo "Live    : $(curl -s -m 3 "http://$AC/6.json" | tr -d ' \n')"
