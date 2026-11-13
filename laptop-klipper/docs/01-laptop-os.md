# 1. Установка ОС на ноутбук

## Что выбрать

| Вариант | Когда |
|---|---|
| **Debian 12 (bookworm) netinst** | Рекомендую: лёгкий, стабильный, KIAUH на нём основной |
| Ubuntu Server 24.04 LTS | Если с Ubuntu привычнее; тоже работает |

Нужна 64-битная версия (`amd64`). Если ноутбук очень старый и 32-битный — Debian 12 i386
(KIAUH работает, но Moonraker на i386 проверяй отдельно).

## Установка

1. Скачай ISO: <https://www.debian.org/distrib/netinst> (amd64), запиши на флешку
   через Rufus / balenaEtcher / Ventoy.
2. В BIOS ноутбука: загрузка с USB; если есть — **AC Power Recovery / Power On AC = On**
   (ноутбук сам включится после пропадания света), **лимит заряда батареи** (у Lenovo, ASUS,
   Dell бывает в BIOS).
3. Установщик Debian:
   - язык можно русский, раскладку — по вкусу;
   - имя компьютера: например `klipper` (тогда в сети он будет `klipper.local`);
   - пароль root можно оставить пустым — тогда созданный пользователь получит `sudo`;
   - пользователь: например `max` (под ним будет работать Klipper);
   - разметка: «весь диск», всё в одном разделе;
   - **выбор ПО: снять всё (Desktop environment, GNOME…), оставить только
     «SSH server» и «standard system utilities»**.
4. После перезагрузки войди на самом ноутбуке и узнай IP: `ip -4 addr` (или `hostname -I`).

## Сеть

- **Лучше кабель Ethernet** до роутера — меньше задержек, стабильнее.
- Если только Wi-Fi, на Debian без графики:
  ```sh
  sudo apt install -y network-manager
  sudo nmtui        # "Activate a connection" -> выбрать сеть -> пароль
  ```
  (на Ubuntu Server Wi-Fi настраивается в установщике или через netplan).
- В роутере закрепи IP за ноутбуком (DHCP reservation / «Привязка IP к MAC»).
  Этот IP потом пишем в Orca.

## Дальше — с основного компьютера по SSH

```sh
ssh max@192.168.1.50          # или ssh max@klipper.local
sudo apt install -y git
git clone https://github.com/kappesrez-cyber/ender-3v3-se-wi-fi-update.git ~/e3se
cd ~/e3se/laptop-klipper/scripts
bash 01-prepare-laptop.sh      # --charge-limit 60 по умолчанию
sudo reboot
```

Что делает `01-prepare-laptop.sh`:

- `HandleLidSwitch=ignore` (+ ExternalPower/Docked) в `logind.conf.d` — крышку можно закрыть;
- `systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`;
- `usermod -aG dialout <user>` — доступ к USB-serial принтера;
- `usbcore.autosuspend=-1` — USB не засыпает (частая причина «Lost communication with MCU»);
- `consoleblank=60` — экран ноутбука гаснет, но система работает;
- служба `cpu-performance` — governor `performance` (меньше задержек хоста);
- служба `wifi-powersave-off` — без энергосбережения Wi-Fi адаптера;
- служба `battery-charge-limit` — порог заряда (если ноутбук поддерживает
  `charge_control_end_threshold`), иначе подскажет вынуть батарею.

Проверка после перезагрузки:

```sh
systemctl status systemd-logind | head -3
systemctl is-enabled sleep.target          # должно быть "masked"
id                                         # в списке групп есть dialout
cat /sys/module/usbcore/parameters/autosuspend   # -1
```

Батарея в роли ИБП — плюс (свет моргнул — ноутбук не перезагрузился), но
постоянные 100 % заряда и тепло от закрытой крышки её убивают. Держи ноутбук
открытым или на подставке, если батарея остаётся внутри.
