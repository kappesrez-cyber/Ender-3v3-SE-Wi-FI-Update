# 6. Панель управления и Moonraker (заметка)

Панель управления принтерами, которую делаем в пути ESP3D, здесь **не
переделывается**. Но если победит путь с ноутбуком, ту же панель можно
переключить на Moonraker: у него открытый HTTP/WebSocket API на каждом
экземпляре (`http://IP:7125`, `:7126`…), и доступ из домашней сети без пароля
уже разрешён в `[authorization]`.

Что панели понадобится (вместо команд ESP3D):

| Действие | Moonraker API |
|---|---|
| Состояние принтера | `GET /printer/info` → `state` (`ready`, `error`, `shutdown`…) |
| Температуры, прогресс, позиция | `GET /printer/objects/query?extruder&heater_bed&print_stats&virtual_sdcard&display_status` |
| Живые обновления | WebSocket `ws://IP:7125/websocket`, метод `printer.objects.subscribe` |
| Загрузить файл | `POST /server/files/upload` (multipart, поле `file`; `print=true` — сразу печатать) |
| Список файлов | `GET /server/files/list?root=gcodes` |
| Старт / пауза / продолжить / отмена | `POST /printer/print/start?filename=…`, `/printer/print/pause`, `/printer/print/resume`, `/printer/print/cancel` |
| Произвольный G-code | `POST /printer/gcode/script?script=G28` |
| Аварийный стоп | `POST /printer/emergency_stop` |

Мультипринтерность в панели: список «принтер → `IP:порт`». Браузерная панель
на другом адресе упрётся в CORS — добавь её адрес в `cors_domains` в
`moonraker.conf` (или раздавай панель с самого ноутбука через nginx).

Документация: <https://moonraker.readthedocs.io/en/latest/web_api/>
