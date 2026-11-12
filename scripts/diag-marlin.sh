#!/usr/bin/env bash
# Временная диагностика: препроцессирует HAL.cpp и показывает, во что раскрылся SerialOutputT
set -x
cd .work/marlin-c13
export PATH="$HOME/.platformio/packages/toolchain-gccarmnoneeabi/bin:$PATH"
CMD="$(pio run -e STM32F103RET6_creality -v 2>&1 | grep -m1 -E 'g\+\+.* -o .*HAL/STM32F1/HAL.cpp.o')"
CMD="$(echo "$CMD" | sed -E 's/ -o [^ ]+/ -E -o \/tmp\/hal.ii/')"
eval "$CMD" || true
grep -n "SerialOutputT\|MYSERIAL2\|MSerial3" /tmp/hal.ii | head -20
grep -n "typedef MultiSerial" -B3 -A2 /tmp/hal.ii | head -20
grep -n "MSerialT MSerial" /tmp/hal.ii | head
grep -c . /tmp/hal.ii
