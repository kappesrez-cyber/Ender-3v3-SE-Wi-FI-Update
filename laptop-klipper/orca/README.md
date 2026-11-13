# Orca Slicer + Klipper на ноутбуке

Нужна Orca Slicer 2.x (подойдёт любая актуальная).

## 1. Подключение (физический принтер)

1. Выбери профиль принтера `Creality Ender-3 V3 SE` → значок Wi-Fi/«Подключение»
   рядом с именем принтера (Physical printer).
2. **Host Type:** `Octo/Klipper`
3. **Hostname, IP or URL:** `192.168.1.50:7125` (IP ноутбука; второй принтер — `:7126` и т. д.)
4. API key — пусто. **Test** → «Connection to Octo/Klipper works correctly».
5. Вкладка **Device** в Orca покажет Mainsail этого принтера.

## 2. Настройки профиля принтера (Printer settings)

**Basic information → Advanced:**

- **G-code flavor:** `Klipper`
- **Label objects:** включить (Process → Others → «Label objects») — для отмены
  отдельной детали в Mainsail (`[exclude_object]`) и адаптивной сетки стола.

**Machine G-code → Machine start G-code** (весь стоковый текст заменить на):

```
START_PRINT BED_TEMP=[bed_temperature_initial_layer_single] EXTRUDER_TEMP=[nozzle_temperature_initial_layer]
```

Хочешь брать сохранённую сетку вместо замера перед каждой печатью — добавь `MESH=0`.

**Machine end G-code:**

```
END_PRINT
```

**Machine limits:** «Use for time estimate» (лимиты задаёт Klipper; в Orca —
только для оценки времени): скорость 250, ускорение 2500.

**Extruder → Retraction:** длина 0.8–1.0 мм, скорость 40 мм/с (директ-экструдер V3 SE).

**Pressure advance** задаётся в Klipper (`pressure_advance` в `printer.cfg`
или `SET_PRESSURE_ADVANCE`), в Orca его не включай.

## 3. Печать

Кнопка **Print** (а не Export) → файл уходит на ноутбук и печать стартует.
«Send» — только загрузить без старта. Файлы видны в Mainsail и на экране
принтера (меню Print).

## Несколько принтеров

На каждый — отдельный Physical printer с одинаковым профилем, но своим
адресом: «Ender1» → `IP:7125`, «Ender2» → `IP:7126`.
