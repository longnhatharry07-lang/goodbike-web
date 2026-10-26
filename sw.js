// Service Worker cho GOODBIKE PWA
// Tăng số phiên bản này mỗi khi bạn cập nhật app để buộc làm mới cache.
const VERSION = 'goodbike-2026-10-26-ipad';
const APP_SHELL = [
  './',
  './index.html',
  './nhanvien.html',
  './manifest.json',
  './manifest-nv.json',
  './icon-192-v3.png',
  './icon-512-v3.png',
  './icon-512-maskable-v3.png',
  './apple-touch-icon-v3.png',
  './favicon-v3.png',
  './icon-nv-192.png',
  './icon-nv-512.png',
  './icon-nv-512-maskable.png',
  './apple-touch-icon-nv.png',
  './favicon-nv.png'
];

// Cài đặt: nạp sẵn app shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(VERSION).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

// Kích hoạt: xóa cache cũ
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Chỉ xử lý GET cùng origin. Bỏ qua Supabase / API bên ngoài để không phá realtime.
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) {
    return;
  }

  // version.json phải LUÔN lấy từ mạng, không bao giờ lấy từ cache —
  // nếu không thì máy chạy bản cũ sẽ không bao giờ biết là có bản mới.
  if (new URL(req.url).pathname.endsWith('/version.json')) {
    event.respondWith(fetch(req, { cache: 'no-store' }).catch(() => new Response('{}', { headers: { 'Content-Type': 'application/json' } })));
    return;
  }

  // HTML (điều hướng): network-first để luôn lấy bản mới, offline thì dùng cache.
  if (req.mode === 'navigate' || (req.headers.get('accept') || '').includes('text/html')) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(VERSION).then((c) => c.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req).then((r) => r || caches.match(/nhanvien\.html$/i.test(new URL(req.url).pathname) ? './nhanvien.html' : './index.html')))
    );
    return;
  }

  // Tài nguyên tĩnh khác: cache-first.
  event.respondWith(
    caches.match(req).then((cached) =>
      cached ||
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(VERSION).then((c) => c.put(req, copy));
        return res;
      })
    )
  );
});

// ===== Thông báo đẩy "đơn mới hôm nay" (gửi từ Supabase Edge Function thong-bao-don) =====
self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { title: 'GOODBIKE', body: event.data ? event.data.text() : '' }; }
  event.waitUntil(self.registration.showNotification(d.title || 'GOODBIKE · Đơn mới', {
    body: d.body || '',
    tag: d.tag || 'gb-don',
    renotify: true,
    requireInteraction: true,
    silent: false,
    vibrate: [300, 120, 300, 120, 500],
    icon: './icon-nv-192.png',
    badge: './icon-nv-192.png',
    data: { url: d.url || './nhanvien.html' }
  }));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || './nhanvien.html', self.registration.scope).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) { if (/nhanvien\.html/.test(c.url) && 'focus' in c) { c.navigate && c.navigate(url).catch(() => {}); return c.focus(); } }
    return self.clients.openWindow(url);
  }));
});
