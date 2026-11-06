// /static/admin/js/header.js
// Ortak header'ı yükler, aktif linki vurgular, tema ve kullanıcı menüsünü bağlar.

(async function mountHeader(){
  const host = document.getElementById('site-header');
  if(!host) return;

  // parçayı çek
  const frag = await fetch('/static/admin/partials/header.html', { cache: 'no-store' });
  host.innerHTML = await frag.text();

  // aktif menü
  const active = host.dataset.active; // "home" | "books"
  if (active) {
    host.querySelectorAll('.hdr-link').forEach(a => {
      if (a.dataset.key === active) {
        a.classList.add('bg-gray-200','dark:bg-gray-700');
      } else {
        a.classList.remove('bg-gray-200','dark:bg-gray-700');
      }
    });
  }

  // tema: kaydedilmiş temayı uygula + toggle
  const saved = localStorage.getItem('theme');
  if (saved) document.documentElement.classList.toggle('dark', saved === 'dark');
  const themeBtn = host.querySelector('[data-action="toggle-theme"]');
  themeBtn?.addEventListener('click', () => {
    const isDark = document.documentElement.classList.toggle('dark');
    localStorage.setItem('theme', isDark ? 'dark' : 'light');
    if (typeof window.__onThemeToggle === 'function') window.__onThemeToggle(isDark);
  });

  // kullanıcı bilgisi doldur
  try {
    const token = localStorage.getItem('token');
    if (!token) throw new Error('no token');
    const res = await fetch('/api/auth/me', {
      headers: { Authorization: 'Bearer ' + token }
    });
    if (res.status === 401) {
      localStorage.removeItem('token');
      location.replace('/static/admin/login.html');
      return;
    }
    if (res.ok) {
      const me = await res.json();
      const nameEl = host.querySelector('[data-user-name]');
      const emailEl = host.querySelector('[data-user-email]');
      if (nameEl) nameEl.textContent = me?.display_name || me?.email || 'Kullanıcı';
      if (emailEl) emailEl.textContent = me?.email || '';
    }
  } catch (_) {
    // sessiz geç
  }

  // dropdown aç/kapa + dışına tıkla kapat + ESC
  const menuRoot = host.querySelector('[data-user-menu]');
  const toggleBtn = host.querySelector('[data-user-toggle]');
  const dd = host.querySelector('[data-user-dropdown]');
  const closeDD = () => dd && dd.classList.add('hidden');
  const openDD  = () => dd && dd.classList.remove('hidden');

  toggleBtn?.addEventListener('click', (e) => {
    e.stopPropagation();
    dd?.classList.toggle('hidden');
  });
  document.addEventListener('click', (e) => {
    if (!menuRoot?.contains(e.target)) closeDD();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeDD();
  });

  // logout
  const logoutBtn = host.querySelector('[data-logout]');
  logoutBtn?.addEventListener('click', () => {
    localStorage.removeItem('token');
    location.replace('/static/admin/login.html');
  });
})();
