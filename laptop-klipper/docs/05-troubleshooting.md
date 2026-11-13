# 5. Неполадки

Сначала: `bash ~/e3se/laptop-klipper/scripts/healthcheck.sh` и лог
`~/printer_data/logs/klippy.log` (или `~/printer_<имя>_data/logs/klippy.log`).

| Симптом | Причина / что делать |
|---|---|
| `mcu 'mcu': Unable to connect` | Неверный `serial:` → `find-printers.sh`; принтер выключен; кабель только для зарядки; пользователь не в `dialout` (перелогинься после `01-prepare-laptop.sh`). |
| После прошивки снова Marlin | Файл с прежним именем / карта не FAT32 4096 / на карте несколько `.bin`. Пересобери (новое имя) и повтори. |
| `MCU Protocol error` / просит обновить MCU | Klipper на ноутбуке обновился, а плата нет. Пересобери `03-build-firmware.sh` и перепрошей. |
| `Lost communication with MCU`, `Timer too close` | USB autosuspend (проверь `-1`), плохой кабель/хаб без питания, перегрев/троттлинг ноутбука, тяжёлые процессы. Кабель короче, хаб с питанием, ноутбук на подставке. |
| Klipper не переподключается после выключения принтера | Mainsail → `FIRMWARE_RESTART`. Можно правило udev из [jpcurti troubleshooting](https://github.com/jpcurti/ender3-v3-se-klipper-with-display/blob/master/e3v3se_docs/troubleshooting.md), но для CH340 VID/PID `1a86:7523`. |
| Экран показывает мусор / не те картинки | Прошивка экрана не 1.0.6. |
| Экран пустой, а Klipper Ready | В прошивке платы не включён мост USART2 — пересобери скриптом; в `printer.cfg` нет `[include display.cfg]`. |
| Два принтера «перепутались» | Использован `by-id` вместо `by-path`, или кабели переставлены между портами. |
| Ноутбук засыпает при закрытой крышке | Перезагрузись после `01-prepare-laptop.sh`; проверь `systemctl is-enabled sleep.target` → `masked`. |
| Orca: «Could not connect» | Порт (`:7125`/`:7126`) в адресе, тот же IP (резервирование в роутере), Host Type `Octo/Klipper`. `curl http://IP:7125/server/info` с компьютера. |
| `Unknown command: START_PRINT` | Нет `[include macros.cfg]` или стартовый G-code в Orca не тот. |
| `Move out of range` в начале печати | Z-offset/сетка не откалиброваны; выполни калибровки из чек-листа. |

Возврат на Marlin: стоковый `.bin` Creality своей ревизии на SD (новое имя файла).
