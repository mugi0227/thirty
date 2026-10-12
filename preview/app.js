(() => {
'use strict';
const key = 'thirty.preview.v1', seenKey = 'thirty.onboardingSeen.v3', max = 999 * 60 + 59, slats = 30, idleAfter = 4000;
const $ = s => document.querySelector(s);
const stroke = d => `<path d="${d}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`;
const icons = {
  play: '<path d="M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5z"/>',
  pause: '<rect x="5.5" y="4" width="4.5" height="16" rx="1.2"/><rect x="14" y="4" width="4.5" height="16" rx="1.2"/>',
  stop: '<rect x="5" y="5" width="14" height="14" rx="2.5"/>',
  moon: stroke('M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z'),
  moonOn: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  rotate: stroke('M4 9V5a1 1 0 0 1 1-1h4M20 15v4a1 1 0 0 1-1 1h-4M15 4h4a1 1 0 0 1 1 1v4M9 20H5a1 1 0 0 1-1-1v-4'),
  portrait: stroke('M8 3h8a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM11 18h2'),
  close: stroke('M6 6l12 12M18 6L6 18'),
  check: stroke('M4.5 12.5l5 5L19.5 7'),
  back: stroke('M15 4.5L7.5 12l7.5 7.5'),
  lock: stroke('M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3'),
  unlock: stroke('M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 6.8-1.2'),
  chevron: stroke('M9 5l7 7-7 7'),
  palette: stroke('M12 3a9 9 0 1 0 0 18c1.2 0 1.8-.8 1.8-1.7 0-1.3-1-1.6-1-2.6 0-.9.7-1.5 1.7-1.5H17a4 4 0 0 0 4-4C21 6.6 17 3 12 3z') + '<circle cx="7.5" cy="11" r="1.3"/><circle cx="10.5" cy="7" r="1.3"/><circle cx="15" cy="7.5" r="1.3"/>',
};
const icon = name => `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">${icons[name]}</svg>`;
const read = k => { try { return localStorage.getItem(k); } catch { return null; } };
const write = (k, v) => { try { localStorage.setItem(k, v); } catch {} };

let state = { phase: 'ready', deadline: null, remaining: 1800, configured: 1800 };
try {
  const saved = JSON.parse(read(key));
  if (saved && ['ready', 'running', 'paused', 'finished'].includes(saved.phase) && Number.isFinite(saved.remaining)
      && saved.remaining >= 0 && saved.remaining <= max && (saved.phase !== 'running' || Number.isFinite(saved.deadline))) {
    state = { ...saved, configured: Number.isInteger(saved.configured) ? Math.max(0, Math.min(max, saved.configured)) : 1800 };
  }
} catch {}
let dimmed = read('thirty.dim') === 'true', showHint = state.phase === 'running', step = 0, firstStep = 0;
let forced = false, idle = false, idleTimer = null;
let device = read('thirty.preview.device') || 'side';
const names = { side: 'サイドボタン', top: 'トップボタン', home: 'ホームボタン' };
if (!names[device]) device = 'side';

const skins = [
  ['classic', 'クラシック', '反射型の液晶。暗い配色ではバックライト'], ['paper', 'ペーパー', '電子ペーパーのような白'],
  ['mint', 'ミント', 'やわらかい緑の液晶'], ['amber', 'アンバー', '琥珀色のバックライト'],
  ['night', 'ナイトブルー', '青く光る夜の時計'], ['ruby', 'ルビー', '赤いLEDの表示'],
];
let hasPlus = read('thirty.plus') === 'true', skin = read('thirty.skin') || 'classic', previewSkin = skin;
const usable = id => id === 'classic' || hasPlus;
if (!skins.some(([id]) => id === skin) || !usable(skin)) skin = 'classic';
const sample = (id, lit, count, big) => `<div class="sample${big ? ' big' : ''}" data-skin="${id}"><div class="s-bars">${Array.from({ length: count }, (_, i) => `<i class="${count - 1 - i < lit ? '' : 'off'}"></i>`).join('')}</div><hr><div class="s-time">30:00</div></div>`;
function renderSkins() {
  document.documentElement.dataset.skin = skin;
  const [, name, detail] = skins.find(([id]) => id === previewSkin);
  $('#skin-preview').outerHTML = sample(previewSkin, 9, 14, true).replace('<div class="sample big"', '<div class="sample big" id="skin-preview"');
  $('#skin-name').textContent = name + (usable(previewSkin) ? '' : '（試着中）');
  $('#skin-detail').textContent = detail;
  $('#skin-grid').innerHTML = skins.map(([id, label]) => `<button class="skin-tile" data-id="${id}" aria-label="${label}" aria-current="${id === previewSkin}">${sample(id, 5, 7).replace('</div></div>', `</div>${usable(id) ? (id === skin ? '<span class="badge">✓</span>' : '') : '<span class="badge">🔒</span>'}</div>`)}${label}</button>`).join('');
  $('#skin-grid').querySelectorAll('button').forEach(b => b.onclick = () => { previewSkin = b.dataset.id; if (usable(previewSkin)) { skin = previewSkin; write('thirty.skin', skin); } renderSkins(); });
  $('#plus-card').hidden = hasPlus;
  $('#thanks').hidden = !hasPlus;
}
const save = () => write(key, JSON.stringify(state));
const remaining = () => state.phase === 'ready' ? state.configured : state.phase === 'finished' ? 0
  : state.phase === 'paused' ? state.remaining : Math.max(0, Math.min(state.configured, (state.deadline - Date.now()) / 1000));
const format = seconds => String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0');

const bars = $('.bars');
for (let i = 0; i < slats; i++) { const bar = document.createElement('span'); bar.className = 'bar'; bars.append(bar); }
const masks = [[0,1,2,4,5,6],[2,5],[0,2,3,4,6],[0,2,3,5,6],[1,2,3,5],[0,1,3,5,6],[0,1,3,4,5,6],[0,2,5],[0,1,2,3,4,5,6],[0,1,2,3,5,6]];
const paths = ['M3 0H15L17 2 15 4H3L1 2Z','M0 3L2 5V17L0 19 -2 17V5Z','M18 3L20 5V17L18 19 16 17V5Z','M3 18H15L17 20 15 22H3L1 20Z','M0 21L2 23V35L0 37 -2 35V23Z','M18 21L20 23V35L18 37 16 35V23Z','M3 36H15L17 38 15 40H3L1 38Z'];
let shownText = '';
function digits(text) {
  if (text === shownText) return;
  shownText = text;
  $('#time').classList.toggle('wide', text.length > 5);
  $('#time').innerHTML = [...text].map(c => c === ':'
    ? '<svg class="colon" viewBox="0 0 4 40" aria-hidden="true"><circle cx="2" cy="13" r="2"/><circle cx="2" cy="27" r="2"/></svg>'
    : `<svg viewBox="-2 0 22 40" aria-hidden="true">${paths.map((p, i) => `<path d="${p}" opacity="${masks[+c].includes(i) ? 1 : .07}"/>`).join('')}</svg>`).join('');
}

const alarm = $('#alarm');
function stopAlarm() { alarm.pause(); alarm.currentTime = 0; }
function playAlarm() { stopAlarm(); alarm.play().catch(() => { $('#status').textContent = '終了音を再生できませんでした。'; }); }

function wake() {
  clearTimeout(idleTimer);
  idle = false;
  if (state.phase === 'running' && !$('#help').open && !$('#time-picker').open && !$('#skins').open)
    idleTimer = setTimeout(() => { idle = true; render(false); }, idleAfter);
}

let previousPhase;
function render(announce = true) {
  const left = remaining();
  if (state.phase === 'running' && left <= 0) {
    state.phase = 'finished'; state.deadline = null; showHint = false; save(); wake();
    if (announce) playAlarm();
  }
  const seconds = Math.ceil(left), text = format(seconds);
  digits(text);
  $('#time').setAttribute('aria-valuetext', text);
  const count = state.configured > 0 ? Math.ceil(left / state.configured * slats) : 0;
  [...bars.children].forEach((b, i) => b.classList.toggle('off', i >= count));

  const land = forced || innerWidth > innerHeight, screen = $('#screen');
  screen.dataset.phase = state.phase;
  screen.classList.toggle('land', land);
  screen.classList.toggle('idle', idle && state.phase === 'running');
  document.body.classList.toggle('forced', forced);
  const action = state.phase === 'running' ? '一時停止' : state.phase === 'paused' ? '再開' : '開始';
  $('#action').setAttribute('aria-label', action);
  $('#action').innerHTML = icon(state.phase === 'running' ? 'pause' : 'play');
  $('#action').disabled = state.configured === 0;
  $('#stop').hidden = state.phase === 'ready';
  document.body.classList.toggle('dimmed', dimmed && ['running', 'paused'].includes(state.phase) && !document.hidden);
  $('#dim').setAttribute('aria-pressed', String(dimmed));
  $('#dim').innerHTML = icon(dimmed ? 'moonOn' : 'moon');
  $('#rotate').innerHTML = icon(land ? 'portrait' : 'rotate');
  $('#rotate').setAttribute('aria-label', land ? '縦向きに戻す' : '横向きにする');
  $('#rotate').hidden = land && !forced;
  $('#hint').hidden = !showHint || state.phase !== 'running' || $('#help').open;
  $('#hint').className = device === 'home' ? 'bottom' : device === 'top' || land ? 'top' : '';
  $('#hint-name').textContent = names[device];
  if (previousPhase !== state.phase) { $('#status').textContent = state.phase === 'finished' ? '終了' : action; previousPhase = state.phase; }
}

function apply(seconds) {
  stopAlarm();
  state.configured = Math.max(0, Math.min(max, seconds));
  state.remaining = state.configured;
  if (state.configured === 0 || state.phase === 'finished') { state.phase = 'ready'; state.deadline = null; showHint = false; }
  else if (state.phase === 'running') state.deadline = Date.now() + state.configured * 1000;
  save(); render();
}
function add(minutes) { render(); apply((state.phase === 'finished' ? state.configured : Math.ceil(remaining())) + minutes * 60); }

$('#action').onclick = () => {
  render(); stopAlarm();
  if (state.phase === 'running') { state.remaining = remaining(); state.phase = 'paused'; state.deadline = null; }
  else if (state.configured > 0) {
    state.deadline = Date.now() + (state.phase === 'paused' ? state.remaining : state.configured) * 1000;
    state.phase = 'running'; showHint = true;
  }
  save(); wake(); render();
};
$('#stop').onclick = () => { stopAlarm(); state.phase = 'ready'; state.deadline = null; state.remaining = state.configured; showHint = false; save(); wake(); render(); };
$('#add-one').onclick = () => add(1);
$('#add-ten').onclick = () => add(10);
$('#dim').onclick = () => { dimmed = !dimmed; write('thirty.dim', String(dimmed)); render(); };
$('#rotate').onclick = () => { forced = !forced; shownText = ''; render(); };
$('#close-hint').onclick = () => { showHint = false; render(); };
$('#lock').onclick = () => openGuide(1);
$('#skin').onclick = () => { previewSkin = skin; renderSkins(); $('#skins').showModal(); wake(); };
$('#close-skins').onclick = () => $('#skins').close();
$('#skins').addEventListener('close', () => { previewSkin = skin; renderSkins(); wake(); render(false); });
$('#buy').onclick = () => { hasPlus = true; write('thirty.plus', 'true'); skin = previewSkin; write('thirty.skin', skin); renderSkins(); };
$('#restore').onclick = () => { hasPlus = read('thirty.plus') === 'true'; renderSkins(); };
$('#lock').innerHTML = `<span class="pill">${icon('unlock')}<span>ロック</span></span>`;
for (const type of ['pointerdown', 'keydown']) document.addEventListener(type, () => { if (idle) { wake(); render(false); } else wake(); }, true);
addEventListener('resize', () => render(false));

// Time sheet: presets first, then exact minutes and seconds.
for (let i = 0; i < 1000; i++) $('#minutes').add(new Option(String(i).padStart(2, '0'), String(i)));
for (let i = 0; i < 60; i++) $('#seconds').add(new Option(String(i).padStart(2, '0'), String(i)));
$('#presets').innerHTML = [5, 15, 25, 30, 45, 60, 90, 120].map(m => `<button data-minutes="${m}" aria-label="${m}分">${m}</button>`).join('');
$('#presets').querySelectorAll('button').forEach(b => b.onclick = () => { apply(Number(b.dataset.minutes) * 60); $('#time-picker').close(); });
$('#time').onclick = () => {
  const n = state.phase === 'finished' ? state.configured : Math.ceil(remaining());
  $('#minutes').value = String(Math.floor(n / 60)); $('#seconds').value = String(n % 60);
  $('#time-picker').showModal(); wake();
};
$('#cancel-time').onclick = () => $('#time-picker').close();
$('#save-time').onclick = () => { apply(Number($('#minutes').value) * 60 + Number($('#seconds').value)); $('#time-picker').close(); };
$('#time-picker').addEventListener('close', () => { wake(); render(false); });

// Onboarding: what Thirty is, then the optional Guided Access setup.
const chev = `<b class="chev">›</b>`;
const crumbs = items => `<div class="crumbs">${items.map(t => `<span>${t}</span>`).join(icon('chevron'))}</div>`;
let demo = null;
function guide() {
  clearInterval(demo);
  const pages = [
    () => `<div class="visual"><div class="mini" aria-hidden="true"><div class="mbars">${'<i></i>'.repeat(18)}</div><div class="mtime">30:00</div></div></div>
      <p class="eyebrow">THIRTY</p><h2>スマホを、そのまま<br>タイマーに。</h2><p>考える前に、スタートを押す。<br>減っていくバーを横目に、<br>ひとつのことだけに取りかかる。</p>`,
    () => `<p class="eyebrow">STEP 1 ・ 任意</p><h2>ほかのアプリに<br>逃げられなくする</h2><p>iPhoneの「アクセスガイド」を使うと、<br>計測中はThirtyから出られなくなります。</p>
      <div class="visual">${crumbs(['設定', 'アクセシビリティ', 'アクセスガイド'])}
      <div class="ios"><div class="ios-row hi">アクセスガイド<span class="toggle"></span></div><div class="ios-note">設定アプリで、このスイッチをオンにします。</div><div class="ios-row">パスコード設定${chev}</div></div></div>
      <a class="small-link" href="https://support.apple.com/ja-jp/111795" target="_blank" rel="noopener">Appleの説明を見る</a>`,
    () => `<p class="eyebrow">STEP 2 ・ 任意</p><h2>解除は${device === 'home' ? 'Touch ID' : 'Face ID'}で</h2><p>パスコード設定で${device === 'home' ? 'Touch ID' : 'Face ID'}をオンにすると、<br>終わったあとの解除がかんたんです。</p>
      <div class="visual">${crumbs(['アクセスガイド', 'パスコード設定'])}
      <div class="ios"><div class="ios-row link">アクセスガイドのパスコードを設定</div><div class="ios-note">はじめてなら、ここで6桁のパスコードを決めます。</div><div class="ios-row hi">${device === 'home' ? 'Touch ID' : 'Face ID'}<span class="toggle"></span></div></div></div>`,
    () => `<p class="eyebrow">STEP 3</p><h2>始めたら、<br>${names[device]}を3回</h2><p>Thirtyの画面でカチカチカチ。<br>画面が固定され、他のアプリを開けません。</p>
      <div class="visual"><div class="phone ${device === 'top' ? 'ipad' : device}" aria-hidden="true"><span class="btn"></span><span class="taps"><b>×3</b></span></div></div>
      <p class="note">解除は同じボタンを3回 → 認証 → 「終了」。<br>iOS 18以前は2回押します。</p>
      <div class="device-type" aria-label="プレビューする端末">${[['side', 'iPhone'], ['top', 'iPad'], ['home', 'ホームボタンあり']].map(([kind, label]) => `<button data-device="${kind}" aria-pressed="${kind === device}">${label}</button>`).join('')}</div>`,
  ];
  $('#stage').innerHTML = pages[step]();
  const total = pages.length - firstStep;
  $('#steps').innerHTML = Array.from({ length: total }, (_, i) => `<span class="${i === step - firstStep ? 'selected' : ''}"></span>`).join('');
  $('#steps').setAttribute('aria-label', `${step - firstStep + 1} / ${total}`);
  $('#next-guide').textContent = step < 3 ? '次へ' : 'タイマーへ';
  $('#skip-guide').textContent = step === 0 ? 'すぐに始める' : step === 1 ? 'あとで設定する' : step === 2 ? 'スキップ' : '最初から見る';
  $('#back-guide').style.visibility = step > firstStep ? 'visible' : 'hidden';
  $('#stage').querySelectorAll('[data-device]').forEach(b => b.onclick = () => { device = b.dataset.device; write('thirty.preview.device', device); guide(); render(); });
  $('#stage').scrollTop = 0;
  const mini = $('#stage .mbars');
  if (mini) {
    let lit = 18;
    demo = setInterval(() => { lit = lit <= 0 ? 18 : lit - 1; [...mini.children].forEach((b, i) => b.classList.toggle('off', i >= lit)); }, 450);
  }
}
function openGuide(from) { firstStep = from; step = from; guide(); $('#help').showModal(); wake(); render(); }
function closeGuide() { write(seenKey, 'true'); clearInterval(demo); $('#help').close(); render(); }
$('#next-guide').onclick = () => { if (step < 3) { step++; guide(); } else closeGuide(); };
$('#skip-guide').onclick = () => {
  if (step <= 1) closeGuide();
  else if (step === 2) { step = 3; guide(); }
  else { step = firstStep; guide(); }
};
$('#close-guide').onclick = closeGuide;
$('#back-guide').onclick = () => { step = Math.max(firstStep, step - 1); guide(); };
$('#help').addEventListener('cancel', () => write(seenKey, 'true'));
$('#help').addEventListener('close', () => { wake(); render(); });

for (const [selector, name] of [['#skin', 'palette'], ['#close-skins', 'close'], ['#stop', 'stop'], ['#close-hint', 'close'], ['#back-guide', 'back'], ['#close-guide', 'close'], ['#cancel-time', 'close'], ['#save-time', 'check']])
  $(selector).innerHTML = icon(name);
document.addEventListener('visibilitychange', () => render(false));
setInterval(render, 250);
renderSkins(); render(false); wake();
if (!read(seenKey)) openGuide(0);
})();
