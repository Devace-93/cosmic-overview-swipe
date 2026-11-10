// Language + theme for cosmic-swipe.3m4.net (same code as mouse.3m4.net).
// Generated into i18n.js with the catalogs by tools/site-i18n.py build.
// Mirrors the other 3m4.net pages: same
// locale list, same localStorage keys (3m4.lang / 3m4.theme), same picker UI.
// Catalogs are per base language ('es', 'en', …); a country locale ('es-MX')
// resolves to its base language, then to en.
window.CosmicSwipeI18n = (function () {
  const LANG_KEY = '3m4.lang';
  const THEME_KEY = '3m4.theme';

  const LANGS = [
    { code: 'es-MX', flag: '🇲🇽', name: 'Español (México)', alias: 'spanish espanol mexico' },
    { code: 'es-ES', flag: '🇪🇸', name: 'Español (España)', alias: 'spanish espanol espana spain' },
    { code: 'es-CO', flag: '🇨🇴', name: 'Español (Colombia)', alias: 'spanish espanol colombia' },
    { code: 'es-AR', flag: '🇦🇷', name: 'Español (Argentina)', alias: 'spanish espanol argentina' },
    { code: 'es-CL', flag: '🇨🇱', name: 'Español (Chile)', alias: 'spanish espanol chile' },
    { code: 'es-PE', flag: '🇵🇪', name: 'Español (Perú)', alias: 'spanish espanol peru' },
    { code: 'en-US', flag: '🇺🇸', name: 'English (US)', alias: 'english ingles estados unidos usa united states' },
    { code: 'en-GB', flag: '🇬🇧', name: 'English (UK)', alias: 'english ingles reino unido uk united kingdom' },
    { code: 'en-CA', flag: '🇨🇦', name: 'English (Canada)', alias: 'english ingles canada' },
    { code: 'en-AU', flag: '🇦🇺', name: 'English (Australia)', alias: 'english ingles australia' },
    { code: 'en-NZ', flag: '🇳🇿', name: 'English (New Zealand)', alias: 'english ingles nueva zelanda new zealand' },
    { code: 'fr-FR', flag: '🇫🇷', name: 'Français (France)', alias: 'french frances francia france' },
    { code: 'de-DE', flag: '🇩🇪', name: 'Deutsch (Deutschland)', alias: 'german aleman alemania germany' },
    { code: 'de-AT', flag: '🇦🇹', name: 'Deutsch (Österreich)', alias: 'german aleman austria' },
    { code: 'it-IT', flag: '🇮🇹', name: 'Italiano (Italia)', alias: 'italian italiano italia italy' },
    { code: 'pt-BR', flag: '🇧🇷', name: 'Português (Brasil)', alias: 'portuguese portugues brasil brazil' },
    { code: 'pt-PT', flag: '🇵🇹', name: 'Português (Portugal)', alias: 'portuguese portugues portugal' },
    { code: 'nl-NL', flag: '🇳🇱', name: 'Nederlands (Nederland)', alias: 'dutch neerlandes holandes paises bajos netherlands' },
    { code: 'sv-SE', flag: '🇸🇪', name: 'Svenska (Sverige)', alias: 'swedish sueco suecia sweden' },
    { code: 'pl-PL', flag: '🇵🇱', name: 'Polski (Polska)', alias: 'polish polaco polonia poland' },
    { code: 'cs-CZ', flag: '🇨🇿', name: 'Čeština (Česko)', alias: 'czech checo chequia czechia' },
    { code: 'ro-RO', flag: '🇷🇴', name: 'Română (România)', alias: 'romanian rumano rumania romania' },
    { code: 'el-GR', flag: '🇬🇷', name: 'Ελληνικά (Ελλάδα)', alias: 'greek griego grecia greece' },
    { code: 'uk-UA', flag: '🇺🇦', name: 'Українська (Україна)', alias: 'ukrainian ucraniano ucrania ukraine' },
    { code: 'ru-RU', flag: '🇷🇺', name: 'Русский (Россия)', alias: 'russian ruso rusia russia' },
    { code: 'tr-TR', flag: '🇹🇷', name: 'Türkçe (Türkiye)', alias: 'turkish turco turquia turkey' },
    { code: 'ar-SA', flag: '🇸🇦', name: 'العربية (السعودية)', alias: 'arabic arabe arabia saudita saudi arabia' },
    { code: 'hi-IN', flag: '🇮🇳', name: 'हिन्दी (भारत)', alias: 'hindi india' },
    { code: 'zh-CN', flag: '🇨🇳', name: '中文（中国）', alias: 'chinese chino china mandarin' },
    { code: 'ja-JP', flag: '🇯🇵', name: '日本語（日本）', alias: 'japanese japones japon japan' },
    { code: 'ko-KR', flag: '🇰🇷', name: '한국어 (대한민국)', alias: 'korean coreano corea korea' },
    { code: 'vi-VN', flag: '🇻🇳', name: 'Tiếng Việt (Việt Nam)', alias: 'vietnamese vietnamita vietnam' },
    { code: 'id-ID', flag: '🇮🇩', name: 'Bahasa Indonesia (Indonesia)', alias: 'indonesian indonesio indonesia' },
    { code: 'th-TH', flag: '🇹🇭', name: 'ไทย (ประเทศไทย)', alias: 'thai tailandes tailandia thailand' },
  ];
  const RTL_LANGS = ['ar'];
  const CATALOG = {};

  function store(get, key, value) {
    try { return get ? localStorage.getItem(key) : localStorage.setItem(key, value); } catch (e) { return null; }
  }

  // --- language ---------------------------------------------------------
  function getLang() {
    const saved = store(true, LANG_KEY);
    if (saved) {
      if (LANGS.some((l) => l.code === saved)) return saved;
      const migrated = LANGS.find((l) => l.code.startsWith(saved));
      if (migrated) return migrated.code;
    }
    const nav = navigator.language || 'en-US';
    if (LANGS.some((l) => l.code === nav)) return nav;
    const base = nav.slice(0, 2);
    return (LANGS.find((l) => l.code.startsWith(base)) || {}).code || 'en-US';
  }

  function t(key) {
    const lang = getLang();
    const base = lang.slice(0, 2);
    const c = CATALOG[lang] || CATALOG[base] || CATALOG.en;
    return (c && c[key]) != null ? c[key] : (CATALOG.en[key] != null ? CATALOG.en[key] : key);
  }

  function setMeta(selector, content) {
    const el = document.querySelector(selector);
    if (el) el.setAttribute('content', content);
  }

  function apply() {
    const lang = getLang();
    document.documentElement.lang = lang;
    document.documentElement.dir = RTL_LANGS.includes(lang.slice(0, 2)) ? 'rtl' : 'ltr';
    document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
    // Strings with inline markup (<code>, <a>, <strong>): all authored in this
    // file, never user input, so innerHTML is fine.
    document.querySelectorAll('[data-i18n-html]').forEach((el) => { el.innerHTML = t(el.dataset.i18nHtml); });
    document.querySelectorAll('[data-i18n-alt]').forEach((el) => { el.alt = t(el.dataset.i18nAlt); });
    const title = t('metaTitle');
    const desc = t('metaDescription');
    document.title = title;
    setMeta('meta[name="description"]', desc);
    setMeta('meta[property="og:title"]', title);
    setMeta('meta[property="og:description"]', desc);
    setMeta('meta[name="twitter:title"]', title);
    setMeta('meta[name="twitter:description"]', desc);
    document.querySelectorAll('.copy').forEach((b) => { if (!b.classList.contains('done')) b.textContent = t('copy'); });
  }

  function setLang(code) {
    store(false, LANG_KEY, code);
    apply();
  }

  const norm = (s) => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

  function mountLangSelector(container) {
    container.classList.add('lang-sel');
    const current = LANGS.find((l) => l.code === getLang()) || LANGS.find((l) => l.code === 'en-US');
    container.innerHTML = `
      <button type="button" aria-haspopup="listbox" aria-label="Language">
        <span>${current.flag}</span><span class="lname">${current.name}</span><span class="caret">▾</span>
      </button>
      <div class="panel" hidden>
        <input type="search" aria-label="Search" />
        <div class="list" role="listbox"></div>
      </div>`;
    const toggle = container.querySelector(':scope > button');
    const panel = container.querySelector('.panel');
    const search = panel.querySelector('input');
    const list = panel.querySelector('.list');
    const render = (query) => {
      const q = norm(query);
      list.innerHTML = LANGS
        .filter((l) => norm(`${l.name} ${l.code} ${l.alias}`).includes(q))
        .map((l) => `<button type="button" role="option" data-code="${l.code}" class="${l.code === current.code ? 'active' : ''}">${l.flag} ${l.name}</button>`)
        .join('');
    };
    render('');
    toggle.addEventListener('click', (e) => {
      e.stopPropagation();
      panel.hidden = !panel.hidden;
      if (!panel.hidden) { search.value = ''; render(''); search.focus(); }
    });
    panel.addEventListener('click', (e) => e.stopPropagation());
    document.addEventListener('click', () => { panel.hidden = true; });
    search.addEventListener('input', () => render(search.value));
    search.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') panel.hidden = true;
      if (e.key === 'Enter') { const first = list.querySelector('[data-code]'); if (first) first.click(); }
    });
    list.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-code]');
      if (!btn) return;
      setLang(btn.dataset.code);
      mountLangSelector(container);
    });
  }

  // --- theme --------------------------------------------------------------
  function getTheme() {
    const saved = store(true, THEME_KEY);
    if (saved === 'light' || saved === 'dark') return saved;
    return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function initThemeToggle() {
    const btn = document.getElementById('theme-toggle');
    if (!btn) return;
    const render = () => { btn.textContent = getTheme() === 'light' ? '☀️' : '🌙'; };
    render();
    btn.addEventListener('click', () => {
      const next = getTheme() === 'light' ? 'dark' : 'light';
      store(false, THEME_KEY, next);
      document.documentElement.dataset.theme = next;
      render();
    });
  }

  function init() {
    apply();
    const slot = document.getElementById('lang-sel');
    if (slot) mountLangSelector(slot);
    initThemeToggle();
  }

  return { LANGS, RTL_LANGS, CATALOG, getLang, setLang, t, init };
})();
