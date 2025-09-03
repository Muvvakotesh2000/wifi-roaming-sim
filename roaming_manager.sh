#!/bin/bash
set -euo pipefail

# ===== Config =====
IFACE="wlan2"
SSID_ALLOW_REGEX="^TestNet$"
THRESHOLD_DBM=-65
MIN_RSSI_IMPROVEMENT=2
SCAN_INTERVAL=10
SCAN_WAIT_MAX=6

# Optional anti-ping-pong
MIN_STAY_SECONDS=20
LAST_ROAM_FILE="/run/roam.last"
PINGPONG_GUARD_DB=5

log_msg(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
last_roam_age(){ [ -f "$LAST_ROAM_FILE" ] || { echo 9999; return; }; echo $(( $(date +%s) - $(cat "$LAST_ROAM_FILE") )); }

get_current_signal(){
  local v
  v="$(iw "$IFACE" link 2>/dev/null | sed -n 's/.*signal:[[:space:]]\(-\{0,1\}[0-9]\+\).*/\1/p')"
  [ -n "$v" ] && echo "$v" || echo ""
}
get_current_bssid(){ iw "$IFACE" link 2>/dev/null | awk '/Connected to/ {print $3}' || echo ""; }
get_net_id(){ wpa_cli -i "$IFACE" list_networks 2>/dev/null | awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1; exit}'; }

do_scan_and_get_results(){
  local t=0 out
  wpa_cli -i "$IFACE" scan >/dev/null 2>&1 || true
  sleep 1
  while [ $t -lt $SCAN_WAIT_MAX ]; do
    out="$(wpa_cli -i "$IFACE" scan_results 2>/dev/null)"
    if [ "$(printf '%s\n' "$out" | wc -l)" -gt 1 ]; then
      printf '%s\n' "$out" | tail -n +2; return 0
    fi
    sleep 1; t=$((t+1))
  done
  return 1
}

perform_roaming_check(){
  local current_rssi current_bssid scan_results best_bssid best_rssi best_freq current_ap_rssi
  current_rssi="$(get_current_signal)"
  current_bssid="$(get_current_bssid)"
  log_msg "Current: RSSI=${current_rssi:-NA} dBm | BSSID=${current_bssid:-NA}"

  if ! scan_results="$(do_scan_and_get_results)"; then
    log_msg "Scan produced no results (driver busy?)."; return
  fi

  best_bssid=""; best_rssi=-999; best_freq=""; current_ap_rssi=-999
  log_msg "Neighbors (matching $SSID_ALLOW_REGEX):"
  while IFS=$'\t' read -r bssid freq signal flags ssid; do
    [ -z "${bssid:-}" ] && continue
    if echo "$ssid" | grep -Eq "$SSID_ALLOW_REGEX" 2>/dev/null; then
      log_msg "  $ssid  $bssid  ${signal} dBm  ${freq} MHz"
      [ "$bssid" = "$current_bssid" ] && current_ap_rssi="$signal"
      if [ "$signal" -gt "$best_rssi" ]; then
        best_rssi="$signal"; best_bssid="$bssid"; best_freq="$freq"
      fi
    fi
  done <<< "$scan_results"

  log_msg "Best candidate: $best_bssid  (${best_rssi} dBm @ ${best_freq} MHz)"

  local should_roam=false reason="" improvement
  local age; age=$(last_roam_age)
  if [ -z "${current_rssi:-}" ]; then
    should_roam=true; reason="Disconnected → connect to best"
  elif [ -n "$best_bssid" ] && [ "$best_bssid" != "$current_bssid" ]; then
    [ "$current_ap_rssi" -gt -999 ] && current_rssi="$current_ap_rssi"
    improvement=$(( best_rssi - current_rssi ))
    needed_improvement=$MIN_RSSI_IMPROVEMENT
    [ "$age" -lt "$MIN_STAY_SECONDS" ] && needed_improvement=$((needed_improvement + PINGPONG_GUARD_DB))

    if [ "$improvement" -ge "$needed_improvement" ]; then
      should_roam=true; reason="Better AP (+${improvement} dB, need ${needed_improvement})"
    elif [ "$current_rssi" -lt "$THRESHOLD_DBM" ]; then
      should_roam=true; reason="Weak current (${current_rssi} dBm)"
    fi
  fi

  if [ "$should_roam" = true ] && [ -n "$best_bssid" ]; then
    local NET_ID; NET_ID="$(get_net_id)"
    if [ -z "$NET_ID" ]; then log_msg "❌ No NET_ID (check wpa_supplicant & network config)."; return; fi

    log_msg "ROAMING: $reason → $best_bssid (${best_rssi} dBm) [NET_ID=$NET_ID]"
    if wpa_cli -i "$IFACE" bssid "$NET_ID" "$best_bssid" | grep -q '^OK'; then
      wpa_cli -i "$IFACE" reassociate >/dev/null 2>&1 || true
      date +%s > "$LAST_ROAM_FILE"
      sleep 2
      local new_bssid new_rssi; new_bssid="$(get_current_bssid)"; new_rssi="$(get_current_signal)"
      if [ "$new_bssid" = "$best_bssid" ]; then log_msg "✅ Now on $new_bssid (${new_rssi:-NA} dBm)"
      else log_msg "⚠️ Reassoc did not land on target (now $new_bssid)"
      fi
    else
      log_msg "❌ wpa_cli bssid command failed"
    fi
  else
    log_msg "No roam needed."
  fi
}

log_msg "🚀 Roaming Manager started"
log_msg "Iface=$IFACE | SSID~/$SSID_ALLOW_REGEX/ | Weak<${THRESHOLD_DBM} dBm | Δ≥${MIN_RSSI_IMPROVEMENT} dB | Interval=${SCAN_INTERVAL}s"
while true; do perform_roaming_check; sleep "$SCAN_INTERVAL"; done
