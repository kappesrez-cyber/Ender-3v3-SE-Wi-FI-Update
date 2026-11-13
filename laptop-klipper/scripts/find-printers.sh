#!/usr/bin/env bash
# Показывает подключённые принтеры и пути для [mcu] serial.
# У всех Ender 3 V3 SE одинаковый USB-чип (CH340, 1a86:7523), поэтому
# путь /dev/serial/by-id у них ОДИНАКОВЫЙ. Для нескольких принтеров
# используй /dev/serial/by-path — он привязан к физическому USB-порту.
set -uo pipefail

echo "== USB-устройства CH340/CH341 (1a86) =="
lsusb | grep -i '1a86' || echo "(не найдено — принтер включён? кабель с данными?)"

echo
echo "== /dev/serial/by-path (используй это в printer.cfg) =="
if ls /dev/serial/by-path/ >/dev/null 2>&1; then
  for p in /dev/serial/by-path/*; do
    printf '%s -> %s\n' "$p" "$(readlink -f "$p")"
  done
else
  echo "(пусто)"
fi

echo
echo "== /dev/serial/by-id =="
ls -1 /dev/serial/by-id/ 2>/dev/null || echo "(пусто)"

cat <<'MSG'

Как понять, какой путь у какого принтера: включи принтеры по одному
и запускай скрипт после каждого — новая строка и есть этот принтер.
Не переставляй потом кабели в другие порты хаба: путь by-path сменится.
MSG
