#!/usr/bin/env bash
# Собирает ESP3D 2.1.x для ESP32-WROOM-32U (UART2: GPIO16 = RX, GPIO17 = TX, 115200).
#   scripts/build-esp3d.sh
# Результат:
#   out/esp3d-esp32-merged.bin  — один файл, шить с адреса 0x0 (esptool / веб-прошивальщик)
#   out/esp3d-esp32-app.bin     — только приложение, для обновления через веб-интерфейс ESP3D
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/.work}"
OUT="${OUT:-$ROOT/out}"

# ESP3D 2.1.x — именно эта ветка умеет /upload_serial, который использует Orca Slicer (см. docs/esp3d.md)
REPO="https://github.com/luc-github/ESP3D.git"
REF="80d5ed1c3f251b0fe9f06e20b9024830949fb29c"
ENV="esp32dev"

SRC="$WORK/esp3d"
rm -rf "$SRC"
mkdir -p "$SRC" "$OUT"
git -C "$SRC" init -q
git -C "$SRC" remote add origin "$REPO"
git -C "$SRC" fetch -q --depth 1 origin "$REF"
git -C "$SRC" checkout -q FETCH_HEAD

for p in "$ROOT"/esp3d/*.patch; do
  echo "Применяю $(basename "$p")"
  git -C "$SRC" apply --whitespace=nowarn "$p"
done

(cd "$SRC" && pio run -e "$ENV")

B="$SRC/.pioenvs/$ENV"
BOOT_APP0="$(find "${PLATFORMIO_CORE_DIR:-$HOME/.platformio}/packages" -path '*framework-arduinoespressif32*' -name boot_app0.bin | head -n1)"
cp "$B/firmware.bin" "$OUT/esp3d-esp32-app.bin"
python3 -m esptool --chip esp32 merge_bin -o "$OUT/esp3d-esp32-merged.bin" \
  0x1000 "$B/bootloader.bin" \
  0x8000 "$B/partitions.bin" \
  0xe000 "$BOOT_APP0" \
  0x10000 "$B/firmware.bin"
echo "Готово: $OUT/esp3d-esp32-merged.bin, $OUT/esp3d-esp32-app.bin"
