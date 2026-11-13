#!/usr/bin/env bash
# Копирует конфиги из этого репозитория в экземпляр Klipper и подставляет порт принтера.
#
# Один принтер (KIAUH создал ~/printer_data):
#   bash 04-install-config.sh --serial /dev/serial/by-path/pci-0000:00:14.0-usb-0:1:1.0-port0
# Несколько принтеров (KIAUH создал ~/printer_ender1_data, ~/printer_ender2_data, ...):
#   bash 04-install-config.sh --instance ender1 --serial /dev/serial/by-path/...-usb-0:1.1:1.0-port0
#   bash 04-install-config.sh --instance ender2 --serial /dev/serial/by-path/...-usb-0:1.2:1.0-port0
#
# Пути смотри через: bash find-printers.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../config"
INSTANCE=""; SERIAL=""; FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --instance) INSTANCE="$2"; shift 2 ;;
    --serial)   SERIAL="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    -h|--help)  sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Неизвестный параметр: $1" >&2; exit 1 ;;
  esac
done
[[ -n $SERIAL ]] || { echo "Укажи --serial (см. find-printers.sh)" >&2; exit 1; }
if [[ $SERIAL == /dev/serial/by-id/* ]]; then
  echo "!! by-id у всех Ender 3 V3 SE одинаковый. Для нескольких принтеров нужен /dev/serial/by-path/..."
fi
if [[ ! -e $SERIAL && $FORCE -eq 0 ]]; then
  echo "Нет устройства $SERIAL (принтер выключен?). Повтори с --force, если уверен." >&2
  exit 1
fi

if [[ -n $INSTANCE ]]; then
  DATA="$HOME/printer_${INSTANCE}_data"
  KSVC="klipper-${INSTANCE}"; MSVC="moonraker-${INSTANCE}"
else
  DATA="$HOME/printer_data"
  KSVC="klipper"; MSVC="moonraker"
fi
CFG="$DATA/config"
[[ -d $CFG ]] || { echo "Нет $CFG — сначала установи экземпляр Klipper/Moonraker через KIAUH." >&2; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
for f in printer.cfg macros.cfg prtouch.cfg display.cfg; do
  if [[ -f $CFG/$f ]]; then
    cp "$CFG/$f" "$CFG/$f.bak-$STAMP"
  fi
done

# printer.cfg: сохраняем блок SAVE_CONFIG из старого файла (PID, сетка стола, z_offset)
OLD_SAVE=""
if [[ -f $CFG/printer.cfg ]] && grep -q '^#\*# <---------------------- SAVE_CONFIG' "$CFG/printer.cfg"; then
  OLD_SAVE=$(sed -n '/^#\*# <---------------------- SAVE_CONFIG/,$p' "$CFG/printer.cfg")
fi

sed "s#__SERIAL__#${SERIAL}#" "$SRC/printer.cfg" > "$CFG/printer.cfg"
cp "$SRC/macros.cfg" "$SRC/prtouch.cfg" "$SRC/display.cfg" "$CFG/"

if [[ ! -e $CFG/mainsail.cfg ]]; then
  echo "!! Нет $CFG/mainsail.cfg (Mainsail ещё не установлен?) — временно отключаю include."
  sed -i 's/^\[include mainsail.cfg\]/#[include mainsail.cfg]   # включи после установки Mainsail/' "$CFG/printer.cfg"
  cat >> "$CFG/printer.cfg" <<'CONF'

# Временная замена mainsail.cfg
[virtual_sdcard]
path: ~/printer_data/gcodes
[pause_resume]
[display_status]
CONF
  sed -i "s#~/printer_data/gcodes#${DATA}/gcodes#" "$CFG/printer.cfg"
fi

if [[ -n $OLD_SAVE ]]; then
  printf '\n%s\n' "$OLD_SAVE" >> "$CFG/printer.cfg"
  echo "==> Перенёс блок SAVE_CONFIG из старого printer.cfg"
fi

# moonraker.conf: добавить [file_manager], если его нет
MCONF="$CFG/moonraker.conf"
if [[ -f $MCONF ]] && ! grep -q '^\[file_manager\]' "$MCONF"; then
  { echo; sed -n '/^\[file_manager\]/,$p' "$SRC/moonraker-extra.conf"; } >> "$MCONF"
  echo "==> Добавил [file_manager] в $MCONF"
fi
PORT=$(awk -F': *' '/^port:/{print $2; exit}' "$MCONF" 2>/dev/null || true)

sudo systemctl restart "$MSVC" "$KSVC"
IP=$(hostname -I | awk '{print $1}')
cat <<MSG

Готово: $CFG
  Klipper:   $KSVC    Moonraker: $MSVC (порт ${PORT:-7125})
  Логи:      $DATA/logs/klippy.log
  Mainsail:  http://${IP}/   (для 2-го и следующих принтеров: добавь ${IP}:${PORT:-7125} в меню принтеров)
  Orca:      Host Type "Octo/Klipper", адрес ${IP}:${PORT:-7125}
Первый запуск — по чек-листу docs/02-firmware-c13-c14.md (раздел "Первый запуск").
MSG
