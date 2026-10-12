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
out = project_root / '.local/v0.2'
out.mkdir(parents=True, exist_ok=True)
results={'preview_only':True,'checks':[],'layouts':[],'errors':[]}

with sync_playwright() as p:
    browser=p.chromium.launch()
    context=browser.new_context(viewport={'width':390,'height':844},device_scale_factor=2)
    page=context.new_page()
    page.on('pageerror',lambda e:results['errors'].append(str(e)))
    page.clock.install()
    page.goto(url)
    assert page.locator('#help').is_visible()
    page.screenshot(path=str(out/'onboarding-1.png'),full_page=True)
    page.get_by_role('button',name='次へ',exact=True).click()
    page.screenshot(path=str(out/'onboarding-2.png'),full_page=True)
    page.get_by_role('button',name='省略',exact=True).click()
    page.screenshot(path=str(out/'onboarding-3.png'),full_page=True)
    page.get_by_role('button',name='タイマーへ',exact=True).click()
    assert not page.locator('#help').is_visible()
    assert page.locator('main').evaluate("e=>{const c=e.cloneNode(true);c.querySelectorAll('.sr-only').forEach(n=>n.remove());return c.textContent.replace(/\\s/g,'')}")=='+1min+10min'
    page.screenshot(path=str(out/'timer-ready.png'),full_page=True)
    page.reload()
    assert not page.locator('#help').is_visible()
    results['checks'].append('First-launch 3-step onboarding, optional biometry skip, no main copy; seen flag survives reload')

    def select_time(m,s):
        page.get_by_role('button',name='時間を変更',exact=True).click()
        page.get_by_role('combobox',name='分',exact=True).select_option(str(m))
        page.get_by_role('combobox',name='秒',exact=True).select_option(str(s))
        page.get_by_role('button',name='時間を決定',exact=True).click()

    select_time(0,0)
    assert page.get_by_role('button',name='開始',exact=True).is_disabled()
    select_time(99,59)
    page.get_by_role('button',name='10分追加',exact=True).click()
    assert page.locator('#time').get_attribute('aria-valuetext')=='99:59'
    select_time(0,59)
    page.get_by_role('button',name='1分追加',exact=True).click()
    assert page.locator('#time').get_attribute('aria-valuetext')=='01:59'
    results['checks'].append('00:00 disables start; 99:59 maximum; quick-add seconds carry')

    select_time(30,0)
    page.get_by_role('button',name='開始',exact=True).click()
    assert page.locator('#hint').is_visible()
    page.clock.fast_forward(154000)
    assert page.locator('#time').get_attribute('aria-valuetext')=='27:26'
    assert page.locator('.bar:not(.off)').count()==28
    page.screenshot(path=str(out/'timer-running.png'),full_page=True)
    page.get_by_role('button',name='一時停止',exact=True).click()
    page.clock.fast_forward(120000)
    assert page.locator('#time').get_attribute('aria-valuetext')=='27:26'
    page.reload()
    assert page.get_by_role('button',name='再開',exact=True).is_visible()
    page.get_by_role('button',name='再開',exact=True).click()
    page.clock.fast_forward(60000)
    assert page.locator('#time').get_attribute('aria-valuetext')=='26:26'
    page.reload()
    assert page.get_by_role('button',name='一時停止',exact=True).is_visible()
    results['checks'].append('Start, pause, resume, deadline restoration, 30-bar remaining fraction')

    page.get_by_role('button',name='1分追加',exact=True).click()
    assert page.locator('#time').get_attribute('aria-valuetext')=='27:26'
    select_time(0,3)
    assert page.get_by_role('button',name='一時停止',exact=True).is_visible()
    page.evaluate("window.alarmCount=0; document.querySelector('#alarm').addEventListener('play',()=>window.alarmCount++)")
    page.get_by_role('button',name='画面を暗くする',exact=True).click()
    assert page.locator('body').evaluate("e=>e.classList.contains('dimmed')")
    page.screenshot(path=str(out/'timer-dimmed.png'),full_page=True)
    page.clock.fast_forward(3000)
    page.wait_for_function('window.alarmCount===1')
    assert not page.locator('body').evaluate("e=>e.classList.contains('dimmed')")
    assert page.locator('#time').get_attribute('aria-valuetext')=='00:00'
    assert page.locator('.bar:not(.off)').count()==0
    page.clock.fast_forward(3000)
    assert page.evaluate('window.alarmCount')==1
    page.get_by_role('button',name='終了',exact=True).click()
    assert page.locator('#time').get_attribute('aria-valuetext')=='00:03'
    results['checks'].append('Running edit and quick-add; chime play event exactly once; dim restores at completion; stop keeps chosen duration')

    page.get_by_role('button',name='アクセスガイドの説明',exact=True).click()
    page.get_by_role('button',name='次へ',exact=True).click()
    page.get_by_role('button',name='次へ',exact=True).click()
    page.get_by_role('button',name='iPad',exact=True).click()
    page.get_by_role('button',name='タイマーへ',exact=True).click()
    page.get_by_role('button',name='開始',exact=True).click()
    assert 'top' in page.locator('#hint').get_attribute('class')
    page.get_by_role('button',name='終了',exact=True).click()
    page.get_by_role('button',name='アクセスガイドの説明',exact=True).click()
    page.get_by_role('button',name='次へ',exact=True).click()
    page.get_by_role('button',name='次へ',exact=True).click()
    page.get_by_role('button',name='ホームボタンあり',exact=True).click()
    page.get_by_role('button',name='タイマーへ',exact=True).click()
    page.get_by_role('button',name='開始',exact=True).click()
    assert 'home' in page.locator('#hint').get_attribute('class')
    page.get_by_role('button',name='ボタンの案内を閉じる',exact=True).click()
    assert not page.locator('#hint').is_visible()
    page.get_by_role('button',name='終了',exact=True).click()
    results['checks'].append('Info reopens onboarding; side/top/home hints and dismissal (preview device choices only)')

    select_time(30,0)
    for w,h,theme in [(320,568,'light'),(375,667,'light'),(390,844,'light'),(844,390,'light'),(768,1024,'light'),(390,844,'dark')]:
        page.set_viewport_size({'width':w,'height':h})
        page.emulate_media(color_scheme=theme,reduced_motion='reduce')
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        for selector in ['#action','#guide','#dim','#time','#add-one','#add-ten']:
            box=page.locator(selector).bounding_box()
            assert box['width']>=44 and box['height']>=44,(selector,box)
        page.screenshot(path=str(out/f'timer-{w}x{h}-{theme}.png'),full_page=True)
        page.get_by_role('button',name='アクセスガイドの説明',exact=True).click()
        assert page.locator('#help').evaluate('e=>e.scrollWidth<=e.clientWidth')
        page.get_by_role('button',name='案内を閉じる',exact=True).click()
        results['layouts'].append({'width':w,'height':h,'theme':theme,'overflow':False,'touch_targets':'passed'})
    assert not results['errors']
    browser.close()
(out/'verification.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(results,ensure_ascii=False,indent=2))

if server is not None:
    server.shutdown()
    server.server_close()
