#!/usr/bin/env bash
# Сборка прошивки Klipper (с мостом для родного экрана) для платы Ender 3 V3 SE.
#
#   bash 03-build-firmware.sh --board c13
#   bash 03-build-firmware.sh --board c14 --chip gd32f303   # или stm32f103
#   bash 03-build-firmware.sh --board c13 --sd /media/$USER/SDCARD
#
# Ревизия платы написана на самой плате: CR4NS200320C13 или CR4NS200320C14.
# Маркировка чипа — на большом квадратном МК в центре платы.
# Один и тот же .bin подходит ко всем принтерам с ОДИНАКОВОЙ ревизией/чипом.
set -euo pipefail

KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
BOARD=""; CHIP=""; SD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --board) BOARD="${2,,}"; shift 2 ;;
    --chip)  CHIP="${2,,}"; shift 2 ;;
    --sd)    SD="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Неизвестный параметр: $1" >&2; exit 1 ;;
  esac
done

case "$BOARD" in
  c13)
    # C13: GigaDevice GD32F303 — Klipper собирается как STM32F103 (так делают
    # 0xD34D и jpcurti, проверено сообществом).
    CHIP="${CHIP:-gd32f303}" ;;
  c14)
    if [[ -z $CHIP ]]; then
      cat >&2 <<'MSG'
Для C14 укажи чип: --chip gd32f303 | stm32f103 | stm32f401
Посмотри маркировку на главном чипе платы (фото с лупой/зумом).
MSG
      exit 1
    fi ;;
  *) echo "Укажи --board c13 или --board c14" >&2; exit 1 ;;
esac

case "$CHIP" in
  gd32f303|stm32f103) MACH=STM32F103 ;;
  stm32f401)
    cat >&2 <<'MSG'
СТОП: для варианта платы со STM32F401 нет проверенной сообществом конфигурации
Klipper с экраном (смещение загрузчика, выводы и USART для экрана могут отличаться).
Прошивка "наугад" может оставить принтер без рабочей прошивки (потом только ST-Link).
Пришли фото платы — подберём параметры отдельно. Скрипт ничего не собрал.
MSG
    exit 2 ;;
  *) echo "Неизвестный чип: $CHIP" >&2; exit 1 ;;
esac

[[ -d $KLIPPER_DIR ]] || { echo "Нет $KLIPPER_DIR — сначала установи Klipper через KIAUH." >&2; exit 1; }
if ! git -C "$KLIPPER_DIR" remote get-url origin | grep -q jpcurti; then
  echo "!! $KLIPPER_DIR установлен не из jpcurti/ender3-v3-se-klipper-with-display."
  echo "   Родной экран работать не будет. Смени репозиторий в KIAUH (Settings) и переустанови Klipper."
  exit 1
fi
if ! command -v arm-none-eabi-gcc >/dev/null; then
  echo "==> Ставлю компилятор ARM"
  sudo apt-get install -y gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi make
fi

cd "$KLIPPER_DIR"
cat > .config <<CONF
CONFIG_LOW_LEVEL_OPTIONS=y
CONFIG_MACH_STM32=y
CONFIG_MACH_${MACH}=y
CONFIG_STM32_FLASH_START_7000=y
CONFIG_STM32_CLOCK_REF_8M=y
CONFIG_STM32_SERIAL_USART1=y
CONFIG_SERIAL_BAUD=115200
CONFIG_SERIAL_BRIDGE=y
CONFIG_ENABLE_SERIAL_BRIDGE_USART2=y
CONF
make olddefconfig >/dev/null

# Проверяем, что Kconfig принял ключевые опции
for opt in CONFIG_MACH_${MACH}=y CONFIG_STM32_FLASH_START_7000=y CONFIG_STM32_SERIAL_USART1=y \
           CONFIG_SERIAL_BRIDGE=y CONFIG_ENABLE_SERIAL_BRIDGE_USART2=y CONFIG_SERIAL_BAUD=115200; do
  grep -qx "$opt" .config || { echo "Ошибка: в .config нет $opt" >&2; exit 1; }
done
echo "==> Конфигурация: ${MACH}, загрузчик 28KiB, USB-serial на USART1 (PA10/PA9) 115200, мост экрана USART2"

make clean >/dev/null
make -j"$(nproc)"

# Имя файла каждый раз новое (плата не прошивает файл с прежним именем), формат 8.3.
NAME="k$(date +%d%H%M).bin"
mkdir -p ~/firmware
cp out/klipper.bin ~/firmware/"$NAME"
echo "==> Прошивка: ~/firmware/$NAME ($(stat -c %s out/klipper.bin) байт)"

if [[ -n $SD ]]; then
  [[ -d $SD ]] || { echo "Нет каталога $SD" >&2; exit 1; }
  rm -f "$SD"/*.bin
  cp out/klipper.bin "$SD/$NAME"
  sync
  echo "==> Скопировано на карту: $SD/$NAME"
fi

cat <<MSG

Как прошить:
  1. microSD (FAT32, кластер 4096) — в корне только $NAME.
  2. Выключи принтер, вставь карту, включи, подожди 1–2 минуты.
  3. Экран может остаться на заставке — это нормально до запуска Klipper на ноутбуке.
  4. Если на экране снова меню Marlin — прошивка не применилась: пересобери (имя поменяется).
Сохрани стоковую прошивку Creality своей ревизии — ею возвращаются на Marlin тем же способом.
MSG
