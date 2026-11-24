/* Merco Plus — service worker : ouverture de l'application SANS Internet.
 *
 * - Fichiers de l'application (même origine) : réseau d'abord (toujours à jour
 *   quand on est en ligne), copie locale si le réseau est coupé ou trop lent.
 * - Moteur Flutter (CanvasKit), polices Google et photos : copie locale d'abord.
 * - Données Firestore / authentification : jamais interceptées (gérées par Firebase).
 */
const CACHE = 'mp-cache-v2';

const CORE = [
  './', 'index.html', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js',
  'manifest.json', 'favicon.png', 'version.json',
  'icons/Icon-192.png', 'icons/Icon-512.png',
  'assets/AssetManifest.bin.json', 'assets/FontManifest.json',
];

// Hébergeurs dont on garde une copie locale (jamais les API Firebase).
const CACHE_FIRST_HOSTS = [
  'www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com', 'images.pexels.com',
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await Promise.all(CORE.map((u) => cache.add(new Request(u, { cache: 'reload' })).catch(() => {})));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const k of await caches.keys()) {
      if (k !== CACHE) await caches.delete(k);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET' || req.headers.has('range')) return; // vidéos, écritures
  const url = new URL(req.url);

  if (url.origin === self.location.origin) {
    if (url.pathname.startsWith('/__/')) return; // services Firebase Hosting (auth...)
    event.respondWith(networkFirst(req));
  } else if (CACHE_FIRST_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(req));
  }
});

function withTimeout(promise, ms) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout')), ms);
    promise.then((v) => { clearTimeout(t); resolve(v); }, (e) => { clearTimeout(t); reject(e); });
  });
}

async function networkFirst(req) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req);
  try {
    // Si une copie locale existe, on n'attend pas plus de 4 s le réseau.
    const res = await withTimeout(fetch(req), cached ? 4000 : 30000);
    if (res && res.ok) cache.put(req, res.clone());
    return res;
  } catch (err) {
    if (cached) return cached;
    if (req.mode === 'navigate') {
      const index = (await cache.match('index.html')) || (await cache.match('./'));
      if (index) return index;
    }
    throw err;
  }
}

async function cacheFirst(req) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req);
  if (cached) return cached;
  const res = await fetch(req);
  if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
  return res;
}
