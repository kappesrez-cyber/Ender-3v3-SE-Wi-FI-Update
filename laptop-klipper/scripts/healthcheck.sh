#!/usr/bin/env bash
# Быстрая проверка хоста: службы, принтеры, ошибки связи, температура/нагрузка.
set -uo pipefail
echo "== Службы =="
systemctl list-units --type=service --no-legend 'klipper*' 'moonraker*' nginx 2>/dev/null \
  | awk '{printf "  %-28s %s %s\n", $1, $3, $4}'

echo; echo "== Порты Moonraker =="
ss -ltnp 2>/dev/null | awk '/:71[0-9][0-9] /{print "  " $4}'

echo; echo "== Принтеры (USB) =="
ls -1 /dev/serial/by-path/ 2>/dev/null | sed 's/^/  /' || echo "  нет"

echo; echo "== Состояние Klipper по каждому Moonraker =="
for port in $(ss -ltn 2>/dev/null | awk '{print $4}' | grep -oE ':71[0-9]{2}$' | tr -d ':' | sort -u); do
  st=$(curl -s --max-time 3 "http://127.0.0.1:${port}/printer/info" | python3 -c 'import sys,json; r=json.load(sys.stdin)["result"]; print(r["state"], "-", r.get("state_message","").splitlines()[0])' 2>/dev/null)
  echo "  ${port}: ${st:-нет ответа}"
done

echo; echo "== Ошибки связи в логах за сутки =="
for log in ~/printer_data/logs/klippy.log ~/printer_*_data/logs/klippy.log; do
  [[ -f $log ]] || continue
  n=$(grep -cE 'Timer too close|Lost communication|MCU .* shutdown|Rescheduled timer' "$log")
  echo "  $log: $n"
done

echo; echo "== Нагрузка / память / батарея =="
uptime | sed 's/^/  /'
free -h | awk 'NR<=2{print "  " $0}'
for b in /sys/class/power_supply/BAT*; do
  [[ -d $b ]] && echo "  $(basename "$b"): $(cat "$b/capacity" 2>/dev/null)% $(cat "$b/status" 2>/dev/null), лимит $(cat "$b/charge_control_end_threshold" 2>/dev/null || echo '—')"
done
