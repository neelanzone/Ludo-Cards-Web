'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "dfc3692eb4dbf462f1c5ec9ad6c52fa6",
"assets/AssetManifest.bin.json": "c5d77d1fc63d9f094ec32fcf7b3b18b8",
"assets/assets/board.png": "92a7245fec25f39e7653c143230570f8",
"assets/assets/cards/Attack01.png": "2a288111952a62c0d235280fe129780d",
"assets/assets/cards/Attack02.png": "9274454e81ff464a29e83b705d10a1ae",
"assets/assets/cards/Attack03.png": "742ea996e32b6d2f6656682f6adc9483",
"assets/assets/cards/Attack04.png": "2cc1e8928c8fbc6e9643c5233e82291c",
"assets/assets/cards/Attack05.png": "0c30257ec762f7ccec3f08217ee563b9",
"assets/assets/cards/Attack06.png": "69a5bb74e46015a666e475b0b2230de7",
"assets/assets/cards/Board01.png": "948ded587c966a70b28171c1de182812",
"assets/assets/cards/Board02.png": "115c41e3d02e0cb4157cfefa67984fbb",
"assets/assets/cards/Board03.png": "d153a23e2c9330a9a39637616fe4392b",
"assets/assets/cards/Board04.png": "0b578facfd84ceeae95e2f0dfd075ec4",
"assets/assets/cards/Board05.png": "56c63a737d8361a0a307221460e9bbc2",
"assets/assets/cards/Board06.png": "885fe46527094794420e449d3fd91df2",
"assets/assets/cards/Board07.png": "2b5a36cbfcb68f0fc514a698a3d834f7",
"assets/assets/cards/Board08.png": "51ca8551696194be544ce0716ed44c09",
"assets/assets/cards/Board09.png": "da2d2abb42d9fb1a70b5059c24f7b3a1",
"assets/assets/cards/Board10.png": "a25491162231da8299ff3968c42db2f5",
"assets/assets/cards/Board11.png": "99dc844ca3a3e06d09914b27abe1f087",
"assets/assets/cards/Board12.png": "a76db2514d5bc513aacc44ec052e2582",
"assets/assets/cards/card_back.png": "70ce4144bc429f5f326c4b718ab2a81c",
"assets/assets/cards/Defence01.png": "1dc3acc200269e051a1708420ce0522f",
"assets/assets/cards/Defence02.png": "a3ce5fb6909bbef855b141355cacf7d8",
"assets/assets/cards/Defence03.png": "f5be49b659ba7b96cf1054473b71672a",
"assets/assets/cards/Defence04.png": "7710178a17ac3ce793ff76a2b9430691",
"assets/assets/cards/Defence05.png": "3bfbf4eac25695446d3de85b81ba947f",
"assets/assets/cards/Defence06.png": "b6fa3c0ece662cad262ff4d5222b3e50",
"assets/assets/cards/Defence07.png": "ee36bebef764e08741b4bd84b9922f06",
"assets/assets/cards/Movement01.png": "b3a646c553475811352a52907808c6a5",
"assets/assets/cards/Movement02.png": "e892d403a8f651c14ef49a80ada0dfc2",
"assets/assets/cards/Movement03.png": "01c64922cb3469e72622a98685d0615e",
"assets/assets/cards/Movement04.png": "752ab969f89e198947bd5045bef4dc6d",
"assets/assets/cards/Movement05.png": "423f79fe69e2f7f8d46452baa1957cf7",
"assets/assets/cards/Movement06.png": "cee8283522799fcbf7fbe59f741bd893",
"assets/assets/cards/Movement07.png": "d395bef79d83723bed25862bfa02ae24",
"assets/assets/cards/Movement08.png": "21c7d0d6cca9c6f0a5a0fb75f08c1ada",
"assets/assets/cards/Movement09.png": "752ab969f89e198947bd5045bef4dc6d",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "acb48176b95abf294a885384496f81b5",
"assets/NOTICES": "76de408b7d41cc9dd47e2297a8a80bb3",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "baa986fd68b87f6d27e51842c4cffbf8",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "98f366ea1c6022e4480c5783212ce0ee",
"/": "98f366ea1c6022e4480c5783212ce0ee",
"main.dart.js": "951af8554697e5e07a973169c329c547",
"manifest.json": "8310a3518d048f8b2c76624934a568d9",
"version.json": "b33856641fea6ae979ec6741462c4fb9"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
