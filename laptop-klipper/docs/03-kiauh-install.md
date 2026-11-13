# 3. Klipper + Moonraker + Mainsail через KIAUH

```sh
cd ~/e3se/laptop-klipper/scripts
bash 02-install-kiauh.sh
```

Скрипт клонирует [KIAUH](https://github.com/dw-0/kiauh) в `~/kiauh` и пишет
`~/kiauh/kiauh.cfg`, где первым репозиторием Klipper стоит
`https://github.com/jpcurti/ender3-v3-se-klipper-with-display, master`
(KIAUH берёт первый из списка). Потом запускает меню KIAUH.

## В меню KIAUH

1. **Settings** → проверь, что Klipper repository = `jpcurti/ender3-v3-se-klipper-with-display`
   (если стоит официальный — выбери jpcurti). **B** — назад.
2. **Install → Klipper.**
   - «How many Klipper instances?» — **по числу принтеров** (1, 2, 3…).
   - Для 2+ KIAUH спросит имена: задай `ender1`, `ender2`… (без пробелов).
     Тогда папки будут `~/printer_ender1_data`, `~/printer_ender2_data`, а службы —
     `klipper-ender1`, `klipper-ender2`.
   - Для одного принтера папка `~/printer_data`, служба `klipper`.
3. **Install → Moonraker.** Экземпляров столько же; порты KIAUH раздаёт сам:
   `7125`, `7126`, `7127`…
4. **Install → Mainsail.** Один на все принтеры, порт 80. На вопрос про
   `mainsail-config` / «add recommended macros» — **Yes** (это `mainsail.cfg` с
   `PAUSE/RESUME/CANCEL_PRINT` и `[virtual_sdcard]`, наш `printer.cfg` его подключает).
5. (по желанию) **Install → Crowsnest** — если будет веб-камера.
6. **Q** — выход.

Проверка:

```sh
systemctl status klipper moonraker nginx          # один принтер
systemctl status 'klipper-*' 'moonraker-*' nginx  # несколько
```

Открой в браузере `http://IP_ноутбука/` — Mainsail. Пока плата не прошита и
конфиг не поставлен, Klipper будет в ошибке — это нормально.

Дальше: [02-firmware-c13-c14.md](02-firmware-c13-c14.md) → сборка прошивки и конфиг.

## Обновления

Mainsail → Machine → Update Manager. Klipper обновляется из репозитория jpcurti
(тот, из которого установлен). **После обновления Klipper пересобери и перепрошей
плату** (`03-build-firmware.sh`), если Mainsail пишет о несовпадении версий MCU.
