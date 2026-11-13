#!/usr/bin/env bash
# Ставит KIAUH и настраивает его так, чтобы по умолчанию устанавливался
# Klipper с поддержкой родного экрана Ender 3 V3 SE (jpcurti, ветка master).
#   bash 02-install-kiauh.sh            # подготовить и запустить KIAUH
#   bash 02-install-kiauh.sh --no-run   # только подготовить
set -euo pipefail

KLIPPER_REPO="https://github.com/jpcurti/ender3-v3-se-klipper-with-display"
KLIPPER_BRANCH="master"
RUN=1
[[ "${1:-}" == "--no-run" ]] && RUN=0

if [[ $EUID -eq 0 ]]; then echo "Не запускай от root." >&2; exit 1; fi
if ! id -nG | grep -qw dialout; then
  echo "!! Текущая сессия ещё не в группе dialout. Перезагрузись после 01-prepare-laptop.sh." >&2
fi

if [[ -d ~/kiauh/.git ]]; then
  git -C ~/kiauh pull --ff-only
else
  git clone https://github.com/dw-0/kiauh.git ~/kiauh
fi

# KIAUH v6 читает ~/kiauh/kiauh.cfg поверх default.kiauh.cfg.
# Первый репозиторий в списке используется по умолчанию.
CFG=~/kiauh/kiauh.cfg
if [[ -f $CFG ]] && ! grep -q 'jpcurti' "$CFG"; then
  cp "$CFG" "$CFG.bak.$(date +%s)"
fi
cat > "$CFG" <<CONF
[kiauh]
backup_before_update: True

[klipper]
repositories:
    ${KLIPPER_REPO}, ${KLIPPER_BRANCH}
    https://github.com/Klipper3d/klipper, master

[moonraker]
optional_speedups: True
repositories:
    https://github.com/Arksine/moonraker

[mainsail]
port: 80
unstable_releases: False

[fluidd]
port: 81
unstable_releases: False
CONF

# Для старого KIAUH (v5, bash) — файл со списком репозиториев.
printf '%s\n%s\n' "$KLIPPER_REPO" "https://github.com/Klipper3d/klipper" > ~/kiauh/klipper_repos.txt

cat <<'MSG'

KIAUH готов. В меню выбери:
  1) Install -> Klipper
       "Number of Klipper instances": 1 на каждый принтер (2 принтера = 2).
       Имена экземпляров удобно задать: ender1, ender2, ...
  1) Install -> Moonraker   (столько же экземпляров, порты 7125, 7126, ...)
  1) Install -> Mainsail    (один на все принтеры, порт 80)
Проверь в Settings, что Klipper repository = jpcurti/ender3-v3-se-klipper-with-display.
Выход из KIAUH — Q. Дальше: bash 03-build-firmware.sh --board c13|c14
MSG

if [[ $RUN -eq 1 ]]; then exec ~/kiauh/kiauh.sh; fi
