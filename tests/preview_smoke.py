import json
from pathlib import Path
import sys
from playwright.sync_api import sync_playwright

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

project_root = Path(__file__).resolve().parents[1]
server = None
if len(sys.argv) > 1:
    url = sys.argv[1]
else:
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=str(project_root / "preview")))
    Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}/"
out = project_root / '.local/v0.3'
out.mkdir(parents=True, exist_ok=True)
results = {'preview_only': True, 'checks': [], 'layouts': [], 'errors': []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    context = browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
    page = context.new_page()
    page.on('pageerror', lambda e: results['errors'].append(str(e)))
    page.clock.install()
    page.goto(url)
    button = lambda name: page.get_by_role('button', name=name, exact=True)
    assert page.locator('#help').is_visible()
    assert page.locator('#steps span').count() == 4
    for index in range(1, 4):
        page.screenshot(path=str(out / f'onboarding-{index}.png'))
        button('次へ').click()
    page.screenshot(path=str(out / 'onboarding-4.png'))
    button('タイマーへ').click()
    assert not page.locator('#help').is_visible()
    assert page.locator('main').evaluate("e=>{const c=e.cloneNode(true);c.querySelectorAll('.sr-only').forEach(n=>n.remove());return c.textContent.replace(/\\s/g,'')}") == 'ロック+1+10'
    page.screenshot(path=str(out / 'timer-ready.png'))
    page.reload()
    assert not page.locator('#help').is_visible()
    results['checks'].append('First launch shows 4 pages (welcome + 3 optional setup steps); seen flag survives reload; main screen has no copy beyond the lock chip')

    def select_time(m, s):
        button('時間を変更').click()
        page.get_by_role('combobox', name='分', exact=True).select_option(str(m))
        page.get_by_role('combobox', name='秒', exact=True).select_option(str(s))
        button('時間を決定').click()

    select_time(0, 0)
    assert button('開始').is_disabled()
    select_time(999, 59)
    button('10分追加').click()
    assert page.locator('#time').get_attribute('aria-valuetext') == '999:59'
    select_time(120, 0)
    assert page.locator('#time').get_attribute('aria-valuetext') == '120:00'
    select_time(0, 59)
    button('1分追加').click()
    assert page.locator('#time').get_attribute('aria-valuetext') == '01:59'
    button('時間を変更').click()
    button('45分').click()
    assert page.locator('#time').get_attribute('aria-valuetext') == '45:00'
    results['checks'].append('00:00 disables start; 999:59 maximum; 3-digit minutes; presets; quick-add seconds carry')

    select_time(30, 0)
    button('開始').click()
    assert page.locator('#hint').is_visible()
    page.clock.fast_forward(154000)
    assert page.locator('#time').get_attribute('aria-valuetext') == '27:26'
    assert page.locator('.bar:not(.off)').count() == 28
    page.screenshot(path=str(out / 'timer-running.png'))
    page.clock.fast_forward(5000)
    assert 'idle' in page.locator('main').get_attribute('class')
    page.screenshot(path=str(out / 'timer-idle.png'))
    page.mouse.click(195, 300)
    assert 'idle' not in page.locator('main').get_attribute('class')
    results['checks'].append('Controls hide 4 s into a run and return on tap')

    button('横向きにする').click()
    assert 'land' in page.locator('main').get_attribute('class')
    button('縦向きに戻す').click()
    assert 'land' not in page.locator('main').get_attribute('class')
    results['checks'].append('Rotate button switches to the landscape bar-timer layout and back')

    button('一時停止').click()
    page.clock.fast_forward(120000)
    assert page.locator('#time').get_attribute('aria-valuetext') == '27:21'
    page.reload()
    assert button('再開').is_visible()
    button('再開').click()
    page.clock.fast_forward(60000)
    assert page.locator('#time').get_attribute('aria-valuetext') == '26:21'
    page.reload()
    assert button('一時停止').is_visible()
    results['checks'].append('Start, pause, resume, deadline restoration, 30-slat remaining fraction')

    button('1分追加').click()
    assert page.locator('#time').get_attribute('aria-valuetext') == '27:21'
    select_time(0, 3)
    assert button('一時停止').is_visible()
    page.evaluate("window.alarmCount=0; document.querySelector('#alarm').addEventListener('play',()=>window.alarmCount++)")
    button('画面を暗くする').click()
    assert page.locator('body').evaluate("e=>e.classList.contains('dimmed')")
    page.clock.fast_forward(3000)
    page.wait_for_function('window.alarmCount===1')
    assert not page.locator('body').evaluate("e=>e.classList.contains('dimmed')")
    assert page.locator('#time').get_attribute('aria-valuetext') == '00:00'
    assert page.locator('.bar:not(.off)').count() == 0
    assert page.locator('main').get_attribute('data-phase') == 'finished'
    page.clock.fast_forward(3000)
    assert page.evaluate('window.alarmCount') == 1
    button('終了').click()
    assert page.locator('#time').get_attribute('aria-valuetext') == '00:03'
    button('画面を暗くする').click()
    results['checks'].append('Running edit and quick-add; chime play event exactly once; dim restores at completion; stop keeps chosen duration')

    button('アクセスガイドでロックする方法').click()
    assert page.locator('#steps span').count() == 3
    button('次へ').click()
    button('次へ').click()
    button('iPad').click()
    button('タイマーへ').click()
    button('開始').click()
    assert 'top' in page.locator('#hint').get_attribute('class')
    button('終了').click()
    button('アクセスガイドでロックする方法').click()
    button('次へ').click()
    button('次へ').click()
    button('ホームボタンあり').click()
    button('タイマーへ').click()
    button('開始').click()
    assert 'bottom' in page.locator('#hint').get_attribute('class')
    button('ボタンの案内を閉じる').click()
    assert not page.locator('#hint').is_visible()
    button('終了').click()
    button('アクセスガイドでロックする方法').click()
    button('次へ').click()
    button('次へ').click()
    button('iPhone').click()
    button('タイマーへ').click()
    results['checks'].append('Lock chip opens the 3 setup steps; side/top/home hints and dismissal (preview device choices only)')

    select_time(30, 0)
    for w, h, theme in [(320, 568, 'light'), (375, 667, 'light'), (390, 844, 'light'), (844, 390, 'light'), (768, 1024, 'light'), (390, 844, 'dark'), (844, 390, 'dark')]:
        page.set_viewport_size({'width': w, 'height': h})
        page.emulate_media(color_scheme=theme, reduced_motion='reduce')
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        for selector in ['#action', '#lock', '#dim', '#time', '#add-one', '#add-ten'] + (['#rotate'] if h > w else []):
            box = page.locator(selector).bounding_box()
            assert box['width'] >= 44 and box['height'] >= 44, (selector, w, h, box)
            assert box['x'] >= 0 and box['y'] >= 0 and box['x'] + box['width'] <= w and box['y'] + box['height'] <= h, (selector, w, h, box)
        page.screenshot(path=str(out / f'timer-{w}x{h}-{theme}.png'))
        button('アクセスガイドでロックする方法').click()
        assert page.locator('#help').evaluate('e=>e.scrollWidth<=e.clientWidth')
        button('案内を閉じる').click()
        results['layouts'].append({'width': w, 'height': h, 'theme': theme, 'overflow': False, 'touch_targets': 'passed'})
    assert not results['errors']
    browser.close()
(out / 'verification.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(results, ensure_ascii=False, indent=2))

if server is not None:
    server.shutdown()
    server.server_close()
