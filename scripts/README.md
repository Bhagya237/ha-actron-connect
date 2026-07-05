# Actron Connect — local scripts & development notes

Helper scripts used to probe and drive an **Actron Connect** Wi-Fi module
locally (no cloud), plus the findings that came out of using them. These are
**development / diagnostic tools**, not part of the Home Assistant integration.

Tested against: **ESP Plus**, module firmware **V0.18G**.

---

## Scripts

| Script | Purpose |
|---|---|
| `probe_actron.sh` | Read-only. Dumps every numbered endpoint (`0.json`..`12.json`) to a timestamped `actron_probe_*.txt`. |
| `actron_cmd.sh` | Send a single `DA` command and show before/after state. No command arg = read-only dump. |
| `actron_on.sh` | Turn ON, enable **all** zones, set target temp (default 24 °C). |
| `actron_off.sh` | Turn OFF. Optional `restore` arg resets temp 22 °C + single zone. |

```bash
./probe_actron.sh 192.168.1.117
./actron_cmd.sh   192.168.1.117 '{"mode":2}'      # read-only if you omit the JSON
./actron_on.sh    192.168.1.117 22.5
./actron_off.sh   192.168.1.117 restore
```

> ⚠️ `actron_on.sh` / `actron_cmd.sh '{"amOn":1}'` **physically start the air
> conditioner.**

---

## How local control works (the key discovery)

The module runs a tiny local web server exposing numbered JSON endpoints. It
**only implements GET** — `PUT`/`POST` return `501 Not Implemented`.

Writes are done by passing the **same `DA` JSON envelope the cloud uses** as a
URL-encoded GET query on the Settings endpoint:

```
GET http://<AC>/4.json?DA=<url-encoded JSON>
```

- Plain query params (`?tempTarget=22`) return `200` but **do nothing** — the
  `DA` envelope is required.
- `4.json` (Settings / desired) updates **instantly**; `6.json` (Live / actual)
  reflects the real unit a few seconds later. Any integration must **read back
  actual state** rather than trust the write echo.

### Endpoint map

| Endpoint | Meaning | Notes |
|---|---|---|
| `0.json` / `1.json` | Info | device id, MAC, firmware, capabilities |
| `2.json` | Network | **contains secrets** — Wi-Fi SSID/PSK, cloud `ApiToken` |
| `4.json` | Settings (desired) | write target via `?DA=` |
| `6.json` | Live (actual) | read the real unit state here |

### Command payloads

```jsonc
{"amOn":1}                              // 1=on, 0=off
{"mode":2}                              // 0=auto 1=heat 2=cool 3=fan-only
{"fanSpeed":1}                          // 0=low 1=med 2=high  (system-wide, not per-zone)
{"tempTarget":22.0}
{"enabledZones":[1,0,0,0,0,0,0,0]}      // per-zone dampers, on/off only
```

---

## Confirmed capabilities & limitations

**Works locally, no cloud:** on/off, mode (heat/cool/auto/fan), fan speed,
target temp, per-zone enable.

**Not settable** (module ignores these `DA` keys — real API limits, not a bug):
- ESP mode (`isInESP_Mode`)
- Continuous fan (`fanIsCont`)
- Per-zone fan speed — there is one system-wide fan; zones are on/off dampers only
- Per-zone target temperature — `individualZoneTemperatures_oC` is **read-only**,
  and is `null` on systems without individual zone sensors.

---

## ⚠️ Safety & correctness constraints (must carry into the integration)

Direct local writes **bypass the wall controller's safeguards**. Two real
effects were observed while testing:

1. **Minimum-airflow interlock is bypassed.** The wall controller normally
   refuses to close *all* zones while the unit is running. Over the local
   channel you *can* — which risks freezing the coil / tripping the high-limit /
   stressing the compressor and ductwork.
   → **The integration must never allow all zones closed while the unit is on.**

2. **Writes can desync the wall controller's display.** Writing `enabledZones`
   directly left a wall-panel zone **LED out of sync** with the actual (working)
   damper state — a cosmetic desync, cleared by toggling that zone from the wall
   panel or power-cycling the system.
   → Treat the wall controller as a **parallel controller**; always reconcile
   against `6.json` (actual) as source of truth.

Also: avoid rapid-fire commands (damper actuator stress) and `null`-guard every
`6.json` field — several (`individualZoneTemperatures_oC`, `liveTimer`) can be
`null`.

---

## Security

- `actron_probe_*.txt` output contains the **Wi-Fi PSK and cloud `ApiToken`**
  (from `2.json`). It is **gitignored — never commit it.**
- When building test fixtures from probe data, **redact** MAC / token / SSID /
  key first.

---

## Next steps for the integration

- [ ] Add a **local-write path** (`GET /4.json?DA=…`) as an alternative to the
      cloud write channel.
- [ ] Enforce the **"never close all zones while on"** guard in the zone switch
      platform.
- [ ] `null`-guard zone-temperature sensors — only create a sensor when the
      zone reports a non-null value.
- [ ] Reconcile written state against `6.json` after the existing
      `_skip_update_until` window.
