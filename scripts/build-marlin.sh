#!/usr/bin/env bash
# Собирает Marlin для Ender 3 V3 SE с портом для ESP3D.
#   scripts/build-marlin.sh c13
# Результат: out/E3V3SE_<REV>_ESP3D_<дата-время>.bin (уникальное имя — иначе принтер не прошьётся).
set -euo pipefail

REV="${1:-c13}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/.work}"
OUT="${OUT:-$ROOT/out}"

case "$REV" in
  c13)
    # Официальные исходники Creality (плата CR4NS200320C13, GD32F303RET6 / совместим с STM32F103RET6)
    REPO="https://github.com/CrealityOfficial/Ender-3V3-SE.git"
    REF="e7b2bad8ff23b3b3723ac6875ed02561a90a8f2b"
    ENV="STM32F103RET6_creality"
    ;;
  c14)
    echo "Для C14 (STM32F401RET6) свободного аппаратного UART нет — см. docs/uart-analysis.md." >&2
    echo "Сборка будет добавлена после выбора варианта подключения." >&2
    exit 2
    ;;
  *)
    echo "Неизвестная ревизия: $REV (ожидается c13 или c14)" >&2
    exit 1
    ;;
esac

SRC="$WORK/marlin-$REV"
rm -rf "$SRC"
mkdir -p "$SRC" "$OUT"
git -C "$SRC" init -q
git -C "$SRC" remote add origin "$REPO"
git -C "$SRC" fetch -q --depth 1 origin "$REF"
git -C "$SRC" checkout -q FETCH_HEAD

for p in "$ROOT"/marlin/"$REV"/*.patch; do
  echo "Применяю $(basename "$p")"
  git -C "$SRC" apply --whitespace=nowarn "$p"
done

# Исходники Creality писались под Windows: <arduino.h>, <wstring.h> в нижнем регистре.
# На Linux/macOS подкладываем заголовки-переходники.
export PLATFORMIO_BUILD_FLAGS="${PLATFORMIO_BUILD_FLAGS:-} -I$ROOT/marlin/shim"

(cd "$SRC" && pio run -e "$ENV")

BIN="$(ls "$SRC"/.pio/build/"$ENV"/*.bin | head -n1)"
NAME="E3V3SE_${REV^^}_ESP3D_$(date +%Y%m%d-%H%M).bin"
cp "$BIN" "$OUT/$NAME"
echo "Готово: $OUT/$NAME ($(stat -c %s "$OUT/$NAME") байт)"
