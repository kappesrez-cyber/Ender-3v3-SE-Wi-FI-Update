# Резервная копия прошивки платы через ST-Link

Перед первой прошивкой своей сборки стоит снять полную копию flash-памяти микроконтроллера: загрузчик Creality + текущая прошивка + всё, что там есть. С такой копией плату можно вернуть ровно в исходное состояние, даже если перепрошивка через SD пойдёт не так.

Нужно: ST-Link V2 (клон подойдёт), 4–5 проводов мама-мама, ПК, [OpenOCD](https://github.com/xpack-dev-tools/openocd-xpack/releases) (для Windows — архив `win32-x64`, распаковать, программа в `bin\openocd.exe`). На Windows может понадобиться драйвер ST-Link (STSW-LINK009) или Zadig → WinUSB.

> Почему OpenOCD, а не STM32CubeProgrammer: на C13 стоит GD32F303, а не STM32. CubeProgrammer его часто не узнаёт, а OpenOCD работает с GD32 как с STM32F1, если отключить проверку ID ядра (`set CPUTAPID 0`).

## 1. Найти SWD на плате

Нужны контакты **SWDIO** (PA13), **SWCLK** (PA14), **GND**, желательно **NRST** и **3,3 В**. На платах Creality это обычно 4–5 площадок или незапаянный разъём рядом с микроконтроллером, иногда с подписями. Пришли фото, подскажу точно.

| ST-Link | Плата |
|---|---|
| SWDIO | SWDIO (PA13) |
| SWCLK | SWCLK (PA14) |
| GND | GND |
| RST | NRST (если есть) |
| 3.3V | 3,3 В — см. ниже |

**Питание:** принтер выключен и отключён от сети, плату питает ST-Link по линии 3,3 В. Если OpenOCD не видит чип (плата тянет слишком много тока), отключи провод 3,3 В от ST-Link и включи принтер. Никогда не подключай 3,3 В ST-Link при включённом принтере.

## 2. Снять копию

Команды для Windows (в папке `bin` OpenOCD; на Linux/macOS — `openocd` без `.exe`).

**C13 (GD32F303RET6, 512 КБ):**

```
openocd.exe -f interface/stlink.cfg -c "set CPUTAPID 0" -f target/stm32f1x.cfg -c "reset_config srst_only connect_assert_srst" -c "init; reset halt; stm32f1x options_read 0; dump_image e3v3se_c13_backup.bin 0x08000000 0x80000; reset run; shutdown"
```

**C14 (STM32F401RET6, 512 КБ):**

```
openocd.exe -f interface/stlink.cfg -f target/stm32f4x.cfg -c "reset_config srst_only connect_assert_srst" -c "init; reset halt; stm32f4x options_read 0; dump_image e3v3se_c14_backup.bin 0x08000000 0x80000; reset run; shutdown"
```

Если провод RST не подключён, убери `-c "reset_config ..."`. Если тогда OpenOCD не может подключиться: прошивка Creality отключает отладочные выводы (`DISABLE_DEBUG`), и без RST подключиться получится только удерживая кнопку сброса платы (если есть) в момент запуска команды.

Результат — файл размером ровно 524 288 байт. Сделай две копии и проверь, что они совпадают (Windows: `certutil -hashfile e3v3se_c13_backup.bin SHA256` для каждой).

## 3. Если включена защита от чтения

`options_read` покажет, включена ли защита чтения (RDP / `read protection`). Если включена, копия будет состоять из нулей или OpenOCD выдаст ошибку.

**Не снимай защиту.** Снятие защиты стирает всю память вместе с загрузчиком Creality, и плата перестанет прошиваться через SD. В этом случае резервной копией служит стоковый `.bin` с сайта Creality для твоей ревизии и версии. Напиши мне, обсудим, как быть.

## 4. Восстановление из копии

Только если плата не загружается и не прошивается с SD.

**C13:**

```
openocd.exe -f interface/stlink.cfg -c "set CPUTAPID 0" -f target/stm32f1x.cfg -c "reset_config srst_only connect_assert_srst" -c "program e3v3se_c13_backup.bin 0x08000000 verify reset exit"
```

**C14:**

```
openocd.exe -f interface/stlink.cfg -f target/stm32f4x.cfg -c "reset_config srst_only connect_assert_srst" -c "program e3v3se_c14_backup.bin 0x08000000 verify reset exit"
```

Загрузчик Creality занимает начало памяти: на C13 прошивка начинается с `0x08007000`, на C14 с `0x08010000`. Полная копия восстанавливает и загрузчик, и прошивку, поэтому после неё принтер снова прошивается с SD как обычно.
