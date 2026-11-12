// Проверка панели 309_base на эмуляторе (tools/esp3d_emulator.py).
//   python3 tools/esp3d_emulator.py --ports 8081 8082 8083 --upload-delay 1 &
//   node tools/panel_test.js            (нужен пакет playwright)
// Панель открывается с «модуля» 8081, остальные принтеры — другие адреса (проверка CORS).
const { chromium } = require("playwright");
const fs = require("fs");
const os = require("os");
const path = require("path");

const BASE = process.env.PANEL_URL || "http://127.0.0.1:8081/panel.html";
const HOSTS = ["127.0.0.1:8081", "127.0.0.1:8082", "127.0.0.1:8083"];
const SHOTS = process.env.SHOTS_DIR || null;

let failed = 0;
function check(cond, what) {
  console.log((cond ? "  ok   " : "  FAIL ") + what);
  if (!cond) failed++;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
  await page.goto(BASE);

  console.log("Добавление принтеров");
  for (const [i, host] of HOSTS.entries()) {
    await page.click("#add");
    await page.fill('#dlgForm input[name="name"]', `Принтер ${i + 1}`);
    await page.fill('#dlgForm input[name="host"]', host);
    await page.click('#dlgForm button[value="ok"]');
  }
  const cards = page.locator("section.card");
  await page.waitForFunction(() => document.querySelectorAll("section.card").length === 3, null, { timeout: 3000 }).catch(() => {});
  check((await cards.count()) === 3, "три карточки");

  console.log("Статус и температуры (в том числе с других адресов — CORS)");
  for (let i = 0; i < 3; i++) {
    await page.waitForFunction((n) => document.querySelectorAll("section.card")[n].querySelector(".t-hot").textContent.includes("°"), i, { timeout: 8000 }).catch(() => {});
    check((await cards.nth(i).locator(".t-hot").textContent()).includes("°"), `принтер ${i + 1}: температура сопла показана`);
    check((await cards.nth(i).locator(".state").textContent()).includes("на связи"), `принтер ${i + 1}: на связи`);
  }

  console.log("Файлы на SD и запуск печати (принтер 2)");
  const c2 = cards.nth(1);
  await c2.locator('[data-act="refresh"]').click();
  await page.waitForFunction(() => document.querySelectorAll("section.card")[1].querySelectorAll(".files option").length > 1, null, { timeout: 8000 });
  check((await c2.locator(".files option").count()) === 3, "список файлов: 2 файла + подсказка");
  await c2.locator(".files").selectOption("CUBE.GCO");
  await c2.locator('[data-act="print"]').click();
  await page.waitForFunction(() => document.querySelectorAll("section.card")[1].querySelector(".state").textContent.includes("печать"), null, { timeout: 12000 });
  check(true, "статус «печать»");
  await page.waitForTimeout(6000);
  const pct = parseFloat(await c2.locator(".pct").textContent());
  check(pct > 0, `прогресс растёт (${pct} %)`);

  console.log("Пауза, продолжение, стоп");
  await c2.locator('[data-act="pause"]').click();
  await page.waitForTimeout(1500);
  check((await c2.locator(".state").textContent()).includes("пауза"), "после паузы статус «пауза»");
  await page.waitForTimeout(5500);
  check((await c2.locator(".state").textContent()).includes("пауза"), "«пауза» держится после опроса");
  await c2.locator('[data-act="resume"]').click();
  await page.waitForTimeout(1500);
  check((await c2.locator(".state").textContent()).includes("печать"), "после «Продолжить» снова печать");
  await c2.locator('[data-act="stop"]').click();
  check((await c2.locator('[data-act="stop"]').textContent()).includes("Точно"), "стоп просит подтверждения");
  await page.waitForTimeout(500);
  check((await c2.locator(".state").textContent()).includes("печать"), "одно нажатие не останавливает");
  await c2.locator('[data-act="stop"]').click();
  await page.waitForTimeout(1500);
  check((await c2.locator(".state").textContent()).includes("на связи"), "двойное нажатие останавливает");
  if (SHOTS) await page.screenshot({ path: path.join(SHOTS, "panel-1.png"), fullPage: true });

  console.log("Загрузка файла и автостарт (принтер 3)");
  const c3 = cards.nth(2);
  const tmp = path.join(os.tmpdir(), "My Long Model Name v2.gcode");
  fs.writeFileSync(tmp, "G28\nG1 X10 Y10\n".repeat(500));
  await c3.locator(".upfile").setInputFiles(tmp);
  await c3.locator('[data-act="upload"]').click();
  await page.waitForFunction(() => document.querySelectorAll("section.card")[2].querySelector(".upstate").textContent.includes("Печать запущена"), null, { timeout: 20000 });
  check((await c3.locator(".upstate").textContent()).includes("MYLONGMO.GCO"), "имя сокращено до 8.3 (MYLONGMO.GCO)");
  await page.waitForTimeout(5500);
  check((await c3.locator(".state").textContent()).includes("печать"), "после загрузки печать идёт");

  console.log("Консоль");
  const c1 = cards.nth(0);
  await c1.locator("details summary").click();
  await c1.locator(".cmd").fill("M115");
  await c1.locator(".cmd").press("Enter");
  await page.waitForTimeout(1500);
  check((await c1.locator(".log").textContent()).includes("Creality + ESP3D Wi-Fi"), "M115 отвечает");

  console.log("Сохранение списка после перезагрузки");
  await page.reload();
  check((await page.locator("section.card").count()) === 3, "после перезагрузки 3 принтера");

  console.log("Нет связи");
  await page.click("#add");
  await page.fill('#dlgForm input[name="name"]', "Выключенный");
  await page.fill('#dlgForm input[name="host"]', "127.0.0.1:8099");
  await page.click('#dlgForm button[value="ok"]');
  await page.waitForTimeout(8000);
  check((await page.locator("section.card").nth(3).locator(".state").textContent()).includes("нет связи"), "недоступный модуль — «нет связи»");
  if (SHOTS) {
    await page.screenshot({ path: path.join(SHOTS, "panel-2.png"), fullPage: true });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: path.join(SHOTS, "panel-phone.png"), fullPage: true });
  }

  const realErrors = errors.filter((e) => !/8099|ERR_CONNECTION_REFUSED|Failed to load resource/.test(e));
  check(realErrors.length === 0, "нет ошибок JavaScript" + (realErrors.length ? ": " + realErrors.join(" | ") : ""));

  await browser.close();
  console.log(failed ? `\nПРОВАЛЕНО проверок: ${failed}` : "\nВсе проверки пройдены");
  process.exit(failed ? 1 : 0);
})();
