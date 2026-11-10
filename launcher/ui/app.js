/* All release metadata is rendered as text. Only fixed native commands cross IPC. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const invoke = (command, args = {}) => window.__TAURI__.core.invoke(command, args);
  let model = null, page = 'play', checking = false, requestInFlight = false;
  let autoPending = false, suppressAuto = false, pendingChoice = null, activeSelection = null;
  let listSignature = '', pollTimer;
  const name = r => !r ? 'Brak instalacji' : r.testing ? 'Test · ' + r.publishedAt.slice(0, 10) : r.version;
  const mib = n => (n / 1048576).toLocaleString('pl-PL', { maximumFractionDigits: 1 }) + ' MiB';
  const date = n => n ? new Date(n * 1000).toLocaleString('pl-PL') : 'Jeszcze nie sprawdzono';
  const target = (selection = model?.state.preferences.selection) => {
    const list = model?.state.releases || [];
    return selection === 'stable' ? list.find(r => !r.testing) : selection === 'testing' ? list.find(r => r.testing) : list.find(r => 'pin:' + r.key === selection);
  };
  function message(text, error = false) { $('notice').hidden = !text; $('notice').textContent = text || ''; $('notice').classList.toggle('error', error); }
  function show(value) { page = value; render(); }
  async function call(command, args, toast) {
    try {
      const result = await invoke(command, args);
      if (result?.state) { model = result; render(); }
      if (toast) message(toast);
      return result;
    } catch (error) { message(String(error), true); return null; }
  }
  async function refresh() {
    if (checking) return;
    checking = true; render();
    const result = await call('refresh');
    checking = false;
    if (result) { autoPending = true; suppressAuto = false; message(result.error, Boolean(result.error)); }
    render(); maybeAuto();
  }
  function maybeAuto() {
    if (!model || !autoPending || suppressAuto || requestInFlight || model.busy || model.gameRunning || !model.online) return;
    const pref = model.state.preferences, desired = target(), current = model.state.installed;
    if (!pref.autoUpdate || pref.selection.startsWith('pin:') || !current || !desired || current.key === desired.key) return;
    // Numbered releases changed in place require an explicit choice, never a silent update.
    if (!desired.testing && current.tag === desired.tag) {
      message('Paczka tego wydania została zmieniona na GitHubie. Sprawdź wydanie i wybierz Aktualizuj, aby ją zastąpić.'); return;
    }
    autoPending = false; start(desired, pref.selection, false);
  }
  async function start(release, selection, navigate = true) {
    if (!release || requestInFlight) return;
    requestInFlight = true;
    activeSelection = selection;
    const result = await call('install', { key: release.key, selection });
    requestInFlight = false;
    if (result && navigate) show('download');
    else render();
  }
  async function choose(release, selection) {
    if (!release || model.busy) return;
    if (model.state.installed?.key === release.key && model.healthy) {
      await call('preferences', { value: { ...model.state.preferences, selection } });
      autoPending = true; render(); return;
    }
    if (!model.state.installed) return start(release, selection);
    pendingChoice = { release, selection };
    $('confirm-title').textContent = 'Zastąpić ' + name(model.state.installed) + ' wersją ' + name(release) + '?';
    $('confirm-copy').textContent = selection.startsWith('pin:')
      ? 'Pozostanie jedna zainstalowana wersja. Wybrane wydanie zostanie przypięte i nie zaktualizuje się automatycznie.'
      : 'Pozostanie jedna zainstalowana wersja. Launcher będzie śledził kolejne ' + (selection === 'testing' ? 'buildy testowe.' : 'stabilne wydania.');
    $('confirm').showModal(); render();
  }
  function render() {
    document.querySelectorAll('[data-screen]').forEach(n => { n.hidden = n.dataset.screen !== page; });
    document.querySelectorAll('nav [data-page]').forEach(n => { if (n.dataset.page === page) n.setAttribute('aria-current', 'page'); else n.removeAttribute('aria-current'); });
    $('refresh').disabled = checking;
    $('refresh').textContent = checking ? 'Sprawdzanie…' : 'Sprawdź aktualizacje ↻';
    if (!model) return;
    const { state, progress: p, busy, healthy, gameRunning, online } = model;
    const current = state.installed, desired = target(), pref = state.preferences;
    const update = desired && desired.key !== current?.key;
    const selectionName = pref.selection === 'stable' ? 'Najnowsza stabilna' : pref.selection === 'testing' ? 'Kanał testowy' : 'Przypięta wersja';
    $('selection-label').textContent = selectionName;
    $('policy-label').textContent = pref.selection.startsWith('pin:') ? 'Wybrana wersja jest przypięta · bez auto-update' : pref.autoUpdate ? 'Śledzisz nowe wydania · auto-update włączony' : 'Automatyczne instalowanie wyłączone';
    $('installed-version').textContent = name(current);
    $('game-status').textContent = busy ? 'Trwa przygotowanie aktualizacji' : gameRunning ? 'Gra jest uruchomiona' : current && !healthy ? 'Pliki gry wymagają naprawy' : healthy ? 'Gotowa do gry' : 'Pobierz grę na ten komputer';
    $('play-action').textContent = busy ? 'ZOBACZ POSTĘP →' : gameRunning ? 'GRA DZIAŁA' : current && !healthy ? 'NAPRAW →' : !current ? 'ZAINSTALUJ →' : update && online ? 'AKTUALIZUJ →' : 'GRAJ →';
    $('play-action').disabled = gameRunning && !busy || !current && !desired || current && !healthy && !desired;
    $('play-existing').hidden = !healthy || busy || gameRunning || !update || !online;
    $('job-count').textContent = busy ? '●' : '03';
    $('footer-install').textContent = current ? 'Jedna zainstalowana wersja · ' + name(current) : 'Gra jeszcze nie jest zainstalowana';
    $('footer-network').textContent = (online ? 'Ostatnie sprawdzenie · ' : 'Offline / cache · ') + date(state.checkedAt);
    $('launcher-version').textContent = 'Launcher ' + model.launcherVersion;
    const latest = state.releases.find(r => !r.testing), testing = state.releases.find(r => r.testing);
    $('news-title').textContent = latest ? name(latest) + ' · ' + (latest.title || 'Stabilne wydanie') : 'Brak stabilnych wydań w katalogu';
    $('news-date').textContent = latest?.publishedAt.slice(0, 10) || '';
    $('news-notes').textContent = latest?.notes || 'Opisy i pliki gry są publikowane w GitHub Releases.';
    $('stable-label').textContent = latest ? name(latest) + ' · ' + mib(latest.size) + '. Pobieraj kolejne stabilne wydania.' : 'Brak gotowego wydania Windows x64';
    $('testing-label').textContent = testing ? testing.publishedAt.slice(0, 10) + ' · ' + mib(testing.size) + '. Śledź bieżący build „najnowsza”.' : 'Brak gotowego buildu testowego';
    document.querySelectorAll('[name="channel"]').forEach(n => { n.checked = n.value === pref.selection; n.disabled = busy || !target(n.value); });
    renderReleases();
    const phases = { idle: 'Gotowa', download: 'Pobieranie', verify: 'Weryfikacja', waiting: 'Oczekiwanie', install: 'Instalowanie', done: 'Gotowe', error: 'Błąd', cancelled: 'Anulowano' };
    const titles = { idle: update ? 'Nowa wersja czeka.' : 'Wszystko gotowe.', download: 'Następna wersja w drodze.', verify: 'Sprawdzamy plik gry.', waiting: 'Dokończ swoją rozgrywkę.', install: 'Zastępujemy obecną wersję.', done: 'Gotowe. Wracaj do gry.', error: 'Nie udało się zaktualizować.', cancelled: 'Pobieranie anulowane.' };
    $('download-title').textContent = titles[p.phase] || p.phase;
    $('download-subtitle').textContent = p.phase === 'done' ? 'Pozostała jedna wersja gry. Pliki tymczasowe usunięte.' : 'Nowa paczka zostanie sprawdzona przed podmianą gry.';
    $('transfer-version').textContent = p.target ? name(current) + (p.phase !== 'done' ? ' → ' + name(p.target) : '') : name(desired || current);
    $('transfer-phase').textContent = model.paused ? 'Wstrzymano' : phases[p.phase] || p.phase;
    const percent = p.total ? Math.min(100, Math.round(p.downloaded / p.total * 100)) : 0;
    $('progress-fill').style.width = percent + '%'; $('progress').setAttribute('aria-valuenow', String(percent));
    $('transfer-percent').textContent = p.total ? percent + '%' : '';
    $('transfer-bytes').textContent = p.total ? mib(p.downloaded) + ' / ' + mib(p.total) : desired ? 'Paczka: ' + mib(desired.size) : 'Brak oczekujących plików';
    $('transfer-message').textContent = p.message;
    const step = p.phase === 'download' ? 1 : p.phase === 'verify' ? 2 : ['waiting', 'install', 'done'].includes(p.phase) ? 3 : 0;
    document.querySelectorAll('[data-step]').forEach(n => { if (Number(n.dataset.step) <= step) n.setAttribute('data-active', ''); else n.removeAttribute('data-active'); });
    $('download-action').disabled = busy && p.phase !== 'download';
    $('download-action').textContent = busy && p.phase === 'download' ? model.paused ? 'Wznów' : 'Wstrzymaj' : busy ? phases[p.phase] + '…' : p.phase === 'done' ? 'Przejdź do gry' : p.phase === 'error' || p.phase === 'cancelled' ? 'Pobierz ponownie' : update || !healthy ? 'Zainstaluj wybraną wersję' : 'Sprawdź aktualizacje';
    $('cancel').hidden = !busy || p.phase === 'install';
    $('auto-update').checked = pref.autoUpdate; $('minimize').checked = pref.minimizeOnPlay;
    $('auto-update').disabled = busy; $('minimize').disabled = busy;
    $('install-path').textContent = model.installPath;
    $('storage-version').textContent = 'Corp Wars · ' + name(current);
    $('verify').disabled = !current || busy || gameRunning;
  }
  function renderReleases() {
    const signature = JSON.stringify([model.state.releases.map(r => r.key), model.state.installed?.key, model.state.preferences.selection, model.busy]);
    if (signature === listSignature) return; listSignature = signature;
    const list = $('release-list'); list.replaceChildren();
    for (const r of model.state.releases.filter(r => !r.testing)) {
      const row = document.createElement('div'); row.className = 'release';
      const info = document.createElement('div'), line = document.createElement('div'); line.className = 'release-title';
      const title = document.createElement('strong'); title.textContent = r.version; line.append(title);
      if (r.key === model.state.installed?.key) { const badge = document.createElement('span'); badge.className = 'badge'; badge.textContent = 'Zainstalowana'; line.append(badge); }
      const meta = document.createElement('p'); meta.className = 'muted'; meta.textContent = r.publishedAt.slice(0, 10) + ' · ' + mib(r.size);
      info.append(line, meta);
      const button = document.createElement('button'); button.type = 'button'; button.textContent = model.state.preferences.selection === 'pin:' + r.key ? 'Przypięta' : 'Wybierz';
      button.disabled = model.busy; button.addEventListener('click', () => choose(r, 'pin:' + r.key)); row.append(info, button); list.append(row);
    }
    if (!list.children.length) { const note = document.createElement('p'); note.className = 'muted'; note.textContent = 'Brak gotowych wydań Windows x64. Sprawdź połączenie i odśwież katalog.'; list.append(note); }
  }
  document.querySelectorAll('[data-page]').forEach(n => n.addEventListener('click', () => show(n.dataset.page)));
  document.querySelectorAll('[name="channel"]').forEach(n => n.addEventListener('change', () => choose(target(n.value), n.value)));
  $('confirm').addEventListener('close', () => { const choice = pendingChoice; pendingChoice = null; if ($('confirm').returnValue === 'install' && choice) start(choice.release, choice.selection); else render(); });
  $('play-action').addEventListener('click', () => {
    if (!model) return;
    if (model.busy) return show('download');
    const desired = target();
    if (!model.healthy || desired && model.state.installed?.key !== desired.key && model.online) return choose(desired, model.state.preferences.selection);
    call('play');
  });
  $('play-existing').addEventListener('click', () => call('play'));
  $('download-action').addEventListener('click', () => {
    if (!model) return;
    if (model.busy) return call('pause');
    if (model.progress.phase === 'done') return show('play');
    const desired = target();
    if (['error', 'cancelled'].includes(model.progress.phase) && model.progress.target) {
      const release = model.state.releases.find(r => r.key === model.progress.target.key);
      return choose(release, activeSelection || (release?.key === desired?.key ? model.state.preferences.selection : release?.testing ? 'testing' : 'pin:' + release?.key));
    }
    if (!model.healthy || desired && desired.key !== model.state.installed?.key) return choose(desired, model.state.preferences.selection);
    refresh();
  });
  $('cancel').addEventListener('click', () => { suppressAuto = true; autoPending = false; call('cancel'); });
  $('refresh').addEventListener('click', refresh);
  $('open-releases').addEventListener('click', () => call('open_releases'));
  for (const [id, key] of [['auto-update', 'autoUpdate'], ['minimize', 'minimizeOnPlay']]) {
    $(id).addEventListener('change', async () => { const checked = $(id).checked; await call('preferences', { value: { ...model.state.preferences, [key]: checked } }); render(); if (key === 'autoUpdate') { autoPending = true; maybeAuto(); } });
  }
  $('verify').addEventListener('click', async () => {
    $('verify').disabled = true;
    const result = await call('verify_files');
    if (result) $('integrity-status').textContent = 'Sprawdzono: rozmiar, SHA-256 i format Windows x64 są poprawne.';
    else { model = await invoke('snapshot'); render(); }
  });
  async function poll() {
    try {
      const old = model; model = await invoke('snapshot'); render();
      if (old?.busy && !model.busy && model.progress.phase === 'error') message(model.progress.message, true);
      if (old?.gameRunning && !model.gameRunning) maybeAuto();
    } catch (error) { message('Nie można odczytać stanu launchera: ' + String(error), true); }
    pollTimer = setTimeout(poll, document.hidden ? 4000 : model?.busy ? 700 : 2000);
  }
  async function boot() {
    if (!window.__TAURI__) { message('Ten interfejs uruchamia się w aplikacji Corp Wars Launcher. Pobierz instalator z GitHub Releases.', true); return; }
    await window.__TAURI__.event.listen('close-blocked', e => message(e.payload));
    model = await invoke('snapshot'); render();
    if (model.error) message(model.error, true);
    await refresh();
    if (model.error) message(model.error, true);
    pollTimer = setTimeout(poll, 1000);
    setInterval(() => { if (!document.hidden && !checking) refresh(); }, 30 * 60 * 1000);
  }
  window.addEventListener('beforeunload', () => clearTimeout(pollTimer));
  boot().catch(error => message('Nie można uruchomić launchera: ' + String(error), true));
})();
