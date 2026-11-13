#!/usr/bin/env bash
# Подготовка старого ноутбука как хоста Klipper (Debian 12 / Ubuntu Server 22.04+).
# Запускать ОТ ОБЫЧНОГО ПОЛЬЗОВАТЕЛЯ (не root), у которого есть sudo:
#   bash 01-prepare-laptop.sh [--charge-limit 60] [--no-battery-limit]
# Скрипт можно запускать повторно — он идемпотентен.
set -euo pipefail

CHARGE_LIMIT=60
DO_BATTERY=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --charge-limit) CHARGE_LIMIT="$2"; shift 2 ;;
    --no-battery-limit) DO_BATTERY=0; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Неизвестный параметр: $1" >&2; exit 1 ;;
  esac
done

if [[ $EUID -eq 0 ]]; then
  echo "Запусти от обычного пользователя (KIAUH и Klipper не ставятся под root)." >&2
  exit 1
fi
USER_NAME="$(id -un)"
say() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

say "1/8 Пакеты: git, ssh, avahi (имя ноутбука.local), утилиты"
sudo apt-get update
sudo apt-get install -y git openssh-server avahi-daemon usbutils curl \
  ca-certificates python3 python3-venv iw ethtool

say "2/8 SSH включён"
sudo systemctl enable --now ssh

say "3/8 Не засыпать при закрытой крышке и от бездействия"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/90-klipper-host.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
IdleAction=ignore
CONF
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null
# logind перечитает настройки после перезагрузки (restart может оборвать SSH-сессию)

say "4/8 Доступ к последовательным портам (группа dialout)"
sudo usermod -aG dialout "$USER_NAME"

say "5/8 Отключить USB autosuspend (иначе Klipper может терять связь с платой)"
GRUB=/etc/default/grub
if [[ -f $GRUB ]] && ! grep -q 'usbcore.autosuspend=-1' "$GRUB"; then
  sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 usbcore.autosuspend=-1"/' "$GRUB"
  sudo update-grub || true
fi
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null || true

say "6/8 Экран ноутбука гаснет через 60 с (консоль), CPU governor = performance"
if [[ -f $GRUB ]] && ! grep -q 'consoleblank=' "$GRUB"; then
  sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 consoleblank=60"/' "$GRUB"
  sudo update-grub || true
fi
sudo tee /etc/systemd/system/cpu-performance.service >/dev/null <<'UNIT'
[Unit]
Description=CPU governor performance (меньше задержек для Klipper)
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$g" ] && echo performance > "$g"; done; true'
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now cpu-performance.service

say "7/8 Wi-Fi: отключить энергосбережение адаптера (если ноутбук на Wi-Fi)"
sudo tee /etc/systemd/system/wifi-powersave-off.service >/dev/null <<'UNIT'
[Unit]
Description=Disable Wi-Fi power saving
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for i in /sys/class/net/*/wireless; do d=$(basename $(dirname $i)); /usr/sbin/iw dev "$d" set power_save off || true; done; true'
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-powersave-off.service || true

say "8/8 Батарея: ограничение заряда до ${CHARGE_LIMIT}% (если ноутбук поддерживает)"
if [[ $DO_BATTERY -eq 1 ]]; then
  found=0
  for b in /sys/class/power_supply/BAT*; do
    [[ -e $b/charge_control_end_threshold ]] || continue
    found=1
    sudo tee /etc/systemd/system/battery-charge-limit.service >/dev/null <<UNIT
[Unit]
Description=Limit battery charge to ${CHARGE_LIMIT}%
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for t in /sys/class/power_supply/BAT*/charge_control_end_threshold; do echo ${CHARGE_LIMIT} > "\$t" || true; done'
[Install]
WantedBy=multi-user.target
UNIT
    sudo systemctl daemon-reload
    sudo systemctl enable --now battery-charge-limit.service || true
    echo "Порог заряда: $(cat "$b"/charge_control_end_threshold)%"
    break
  done
  if [[ $found -eq 0 ]]; then
    echo "!! Ноутбук не даёт ограничить заряд через sysfs."
    echo "   Лучше вынуть батарею (если съёмная) или выставить лимит в BIOS/UEFI."
    echo "   Батарея на постоянных 100% со временем может вздуться."
  fi
fi

IP=$(hostname -I | awk '{print $1}')
cat <<MSG

Готово. ПЕРЕЗАГРУЗИ ноутбук: sudo reboot
После перезагрузки:
  * заходи по SSH: ssh ${USER_NAME}@${IP}   (или ${USER_NAME}@$(hostname).local)
  * закрепи этот IP за ноутбуком в роутере (DHCP-резервирование)
  * следующий шаг: bash 02-install-kiauh.sh
MSG
