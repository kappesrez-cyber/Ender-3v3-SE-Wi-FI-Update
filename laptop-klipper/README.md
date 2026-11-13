# Wi-Fi печать через старый ноутбук (Klipper + Moonraker + Mainsail)

Запасной путь к печати по Wi-Fi из Orca Slicer, если вариант ESP32 + ESP3D
не пойдёт. Ноутбук (хватает 2–4 ГБ ОЗУ, у нас 8 ГБ) становится хостом Klipper
для одного или нескольких Ender 3 V3 SE. Родной экран принтера продолжает
работать благодаря форку
[jpcurti/ender3-v3-se-klipper-with-display](https://github.com/jpcurti/ender3-v3-se-klipper-with-display).

```
Orca Slicer ──Wi-Fi/LAN──► Ноутбук (Debian/Ubuntu Server)
                              ├─ Mainsail (порт 80) — веб-интерфейс для всех принтеров
                              ├─ Moonraker :7125 ─ Klipper "ender1" ─USB─► Ender 3 V3 SE №1 (+ экран)
                              └─ Moonraker :7126 ─ Klipper "ender2" ─USB─► Ender 3 V3 SE №2 (+ экран)
```

## Что здесь лежит

| Путь | Что делает |
|---|---|
| `scripts/01-prepare-laptop.sh` | Готовит ОС: SSH, не спать при закрытой крышке, `dialout`, USB autosuspend off, CPU performance, Wi-Fi powersave off, лимит заряда батареи |
| `scripts/02-install-kiauh.sh` | Ставит KIAUH и прописывает Klipper от jpcurti (экран) по умолчанию |
| `scripts/03-build-firmware.sh` | Собирает прошивку Klipper для платы C13 / C14, имя файла каждый раз новое |
| `scripts/find-printers.sh` | Показывает порты принтеров (`/dev/serial/by-path/...`) |
| `scripts/04-install-config.sh` | Ставит конфиги в экземпляр Klipper, подставляет порт, сохраняет SAVE_CONFIG |
| `scripts/healthcheck.sh` | Состояние служб, принтеров, ошибки связи, батарея |
| `config/printer.cfg` | Конфиг V3 SE (на основе 0xD34D), `[mcu]` 115200, exclude_object, дуги |
| `config/prtouch.cfg` | Тензодатчик стола: авто Z-offset, очистка сопла |
| `config/display.cfg` | Родной экран + пункты меню Misc |
| `config/macros.cfg` | `START_PRINT`, `END_PRINT`, загрузка/выгрузка прутка, калибровки |
| `config/moonraker-extra.conf` | Что добавить в `moonraker.conf` |
| `orca/` | Настройка Orca Slicer под Klipper |
| `docs/` | Подробные инструкции по шагам |

## Порядок действий (коротко)

1. **ОС на ноутбук** — [docs/01-laptop-os.md](docs/01-laptop-os.md). Debian 12 netinst
   или Ubuntu Server 24.04, без графики, с OpenSSH.
2. Скопировать репозиторий на ноутбук и подготовить систему:
   ```sh
   sudo apt install -y git
   git clone https://github.com/kappesrez-cyber/ender-3v3-se-wi-fi-update.git ~/e3se
   cd ~/e3se/laptop-klipper/scripts
   bash 01-prepare-laptop.sh
   sudo reboot
   ```
3. **Klipper/Moonraker/Mainsail через KIAUH** — [docs/03-kiauh-install.md](docs/03-kiauh-install.md):
   `bash 02-install-kiauh.sh` (экземпляров Klipper и Moonraker — по числу принтеров).
4. **Прошивка платы принтера** — [docs/02-firmware-c13-c14.md](docs/02-firmware-c13-c14.md).
   У нашего принтера плата **C13** (GD32F303RET6, кварц 8 МГц, проверено по фото):
   `bash 03-build-firmware.sh --board c13`. Для других принтеров сначала узнай ревизию.
   Прошивка экрана должна быть **1.0.6**.
5. **Подключить принтер(ы) по USB**, найти порт и поставить конфиг:
   ```sh
   bash find-printers.sh
   bash 04-install-config.sh --serial /dev/serial/by-path/...            # 1 принтер
   bash 04-install-config.sh --instance ender1 --serial /dev/serial/by-path/...   # несколько
   ```
6. **Первый запуск и калибровки** — чек-лист в [docs/02-firmware-c13-c14.md](docs/02-firmware-c13-c14.md#первый-запуск).
7. **Несколько принтеров** — [docs/04-multi-printer.md](docs/04-multi-printer.md).
8. **Orca Slicer** — [orca/README.md](orca/README.md): Host Type `Octo/Klipper`,
   адрес `IP_ноутбука:7125`, G-code flavor `Klipper`.

Проблемы — [docs/05-troubleshooting.md](docs/05-troubleshooting.md).
Как панель управления (из пути ESP3D) могла бы работать с Moonraker —
[docs/06-panel-and-moonraker.md](docs/06-panel-and-moonraker.md).

## Плюсы и минусы этого пути

**Плюсы:** ничего не надо паять и покупать (кроме, возможно, USB-хаба с питанием);
печать стартует из Orca одной кнопкой; Klipper даёт input shaping, pressure advance,
адаптивную сетку стола, отмену отдельных объектов; один ноутбук — несколько принтеров.

**Минусы:** ноутбук — единая точка отказа (завис — встали все принтеры);
батарея на постоянном заряде (ограничь заряд или вынь); принтеры привязаны к
месту, где стоит ноутбук (длина USB-кабеля); Klipper чувствителен к задержкам
хоста — нужны нормальные USB-кабели и хаб с внешним питанием; родной экран
привязан к прошивке экрана 1.0.6; часть пунктов меню экрана (max speed, accel,
steps/mm) недоступна.

**Откат на Marlin:** прошить стоковый `.bin` Creality своей ревизии через microSD
(имя файла — отличное от последнего прошитого).
