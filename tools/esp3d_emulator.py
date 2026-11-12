#!/usr/bin/env python3
"""
Эмулятор ESP3D 2.1.x + Marlin для проверки панели 309_base и Orca без железа.

Запуск (три «принтера» на портах 8081-8083):
    python3 tools/esp3d_emulator.py --ports 8081 8082 8083

Панель будет доступна на http://127.0.0.1:8081/panel.html, принтеры добавляются
по адресам 127.0.0.1:8081, 127.0.0.1:8082, ...  В Orca можно указать 127.0.0.1:8081.

Эмулируется то, что используют панель и Orca:
  GET  /command?plain=<gcode>   ответ Marlin до строки "ok" (как ESP3D 2.1.x)
  POST /upload_serial           multipart, поле "file" -> файл на «SD» (M28/M29)
  GET  /panel.html              панель из panel/index.html (как из SPIFFS модуля)
G-code: M105 M104 M109 M140 M190 M20 M23 M24 M25 M27 M524 M115 M28/M29-заглушки, прочее -> ok.
Все ответы с Access-Control-Allow-Origin: * (как в нашем патче ESP3D).
"""
import argparse
import email.parser
import email.policy
import re
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PANEL = Path(__file__).resolve().parent.parent / "panel" / "index.html"


class Marlin:
    """Очень упрощённая модель принтера: температуры, SD-карта, печать."""

    def __init__(self, name):
        self.name = name
        self.lock = threading.Lock()
        self.hot, self.hot_set = 24.0, 0.0
        self.bed, self.bed_set = 23.0, 0.0
        self.sd = {"CUBE.GCO": 180_000, "BENCHY.GCO": 2_400_000}
        self.selected = None
        self.printing = False
        self.pos = 0
        self.last = time.time()

    def tick(self):
        now = time.time()
        dt, self.last = now - self.last, now
        for attr, target_attr, k in (("hot", "hot_set", 0.25), ("bed", "bed_set", 0.08)):
            cur, tgt = getattr(self, attr), getattr(self, target_attr) or 23.0
            setattr(self, attr, cur + (tgt - cur) * min(1.0, k * dt))
        if self.printing and self.selected:
            size = self.sd[self.selected]
            self.pos = min(size, self.pos + int(size * 0.01 * dt))  # ~1 % в секунду
            if self.pos >= size:
                self.printing = False
                self.hot_set = self.bed_set = 0

    def temps(self):
        return f"ok T:{self.hot:.2f} /{self.hot_set:.2f} B:{self.bed:.2f} /{self.bed_set:.2f} @:0 B@:0"

    def gcode(self, line):
        with self.lock:
            self.tick()
            line = line.strip()
            cmd = line.split(" ")[0].upper()
            arg = line[len(cmd):].strip()
            num = lambda letter: float(re.search(letter + r"(-?[\d.]+)", arg).group(1)) if re.search(letter + r"(-?[\d.]+)", arg) else 0.0
            if cmd == "M105":
                return self.temps()
            if cmd in ("M104", "M109"):
                self.hot_set = num("S")
                return "ok"
            if cmd in ("M140", "M190"):
                self.bed_set = num("S")
                return "ok"
            if cmd == "M115":
                return f"FIRMWARE_NAME:Marlin 2.0.8.2 (Creality + ESP3D Wi-Fi) SOURCE_CODE_URL:emulator MACHINE_TYPE:{self.name}\nok"
            if cmd == "M20":
                files = "\n".join(f"{n} {s} {n.split('.')[0].title()}.gcode" for n, s in self.sd.items())
                return f"Begin file list\n{files}\nEnd file list\nok"
            if cmd == "M23":
                name = arg.upper()
                if name not in self.sd:
                    return f"open failed, File: {arg}.\nok"
                self.selected, self.pos = name, 0
                return f"File opened: {name} Size: {self.sd[name]}\nFile selected\nok"
            if cmd == "M24":
                if self.selected:
                    self.printing = True
                    if not self.hot_set:
                        self.hot_set, self.bed_set = 210.0, 60.0
                return "ok"
            if cmd == "M25":
                self.printing = False
                return "ok"
            if cmd == "M524":
                self.printing, self.selected, self.pos = False, None, 0
                self.hot_set = self.bed_set = 0
                return "echo:Print aborted\nok"
            if cmd == "M27":
                # Как в Marlin (CardReader::report_status): только во время печати, на паузе — «Not SD printing»
                if self.selected and self.printing:
                    return f"SD printing byte {self.pos}/{self.sd[self.selected]}\nok"
                return "Not SD printing\nok"
            return "ok"

    def store(self, name, data):
        with self.lock:
            # Marlin M28 пишет имя в верхнем регистре на FAT
            self.sd[name.upper()] = max(1, len(data))


def make_handler(printer, upload_delay):
    class Handler(BaseHTTPRequestHandler):
        server_version = "ESP3D-emulator/2.1"

        def log_message(self, fmt, *args):
            print(f"[{printer.name}] " + fmt % args)

        def send(self, code, body, ctype="text/plain"):
            data = body.encode() if isinstance(body, str) else body
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            url = urlparse(self.path)
            if url.path == "/command":
                q = parse_qs(url.query)
                cmd = (q.get("plain") or q.get("commandText") or [""])[0]
                if not cmd:
                    return self.send(200, "Invalid command")
                return self.send(200, printer.gcode(cmd) + "\n")
            if url.path in ("/panel.html", "/"):
                return self.send(200, PANEL.read_bytes(), "text/html; charset=utf-8")
            return self.send(404, "not found")

        def do_OPTIONS(self):
            # Настоящий ESP3D 2.1 предварительные запросы CORS не обрабатывает — эмулируем это,
            # чтобы тест ловил случаи, когда панель случайно делает «непростой» запрос.
            return self.send(501, "OPTIONS not supported")

        def do_POST(self):
            url = urlparse(self.path)
            if url.path != "/upload_serial":
                return self.send(404, "not found")
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            msg = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(
                b"Content-Type: " + self.headers["Content-Type"].encode() + b"\r\n\r\n" + body
            )
            for part in msg.iter_parts():
                name = part.get_filename()
                if name:
                    data = part.get_payload(decode=True) or b""
                    # Имитируем медленную передачу по UART (115200 бод ≈ 10 КБ/с, ограничим задержку)
                    time.sleep(min(upload_delay, len(data) / 10_000))
                    printer.store(name, data)
                    return self.send(200, '{"status":"ok"}', "application/json")
            return self.send(500, '{"status":"no file"}', "application/json")

    return Handler


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--ports", type=int, nargs="+", default=[8081, 8082])
    ap.add_argument("--upload-delay", type=float, default=3.0, help="максимальная задержка загрузки, с")
    args = ap.parse_args()
    servers = []
    for i, port in enumerate(args.ports, 1):
        srv = ThreadingHTTPServer((args.host, port), make_handler(Marlin(f"Ender3V3SE-{i}"), args.upload_delay))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        servers.append(srv)
        print(f"Принтер {i}: http://{args.host}:{port}  (панель: http://{args.host}:{port}/panel.html)")
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
