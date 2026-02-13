'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "ab597619d3b66f19671d4d40f519d693",
".git/config": "c2d249854c2c430aa5f56794ba22d90c",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "cf7dd3ce51958c5f13fece957cc417fb",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "646b3b09bbe5b68f1d0d20e9b3626c54",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "ba9c2d400446a5845e369e9357667662",
".git/logs/refs/heads/main": "ebb42f72c853ceef353805d0746c37c9",
".git/logs/refs/remotes/origin/main": "790888e14d74efa0205e3a061e1a9ae2",
".git/objects/04/38af187a6054cc8561d8c55951514f47f7a8da": "5297550d9fc3b4d0fa5051fc837a71be",
".git/objects/05/b85f27b164535fc5bed32bc518ca4f1c871ed2": "e1bdf3823eaab7eadf270f3052dbcdb8",
".git/objects/08/27c17254fd3959af211aaf91a82d3b9a804c2f": "360dc8df65dabbf4e7f858711c46cc09",
".git/objects/08/6582f28014149ca167fe7aa76f84bda6ccf1c5": "d20d2159b4119c083c38255d572f54f0",
".git/objects/0e/d0d51a1c98a89bddf9f3476c6ea5a3cf65d8d4": "4cb1f9403b558cf3b5461d829ee13599",
".git/objects/0f/2d437703d133ee9c0f76663fe7c593043f7e75": "3f7607b2198a2d461062efbf6d8500d1",
".git/objects/1d/1d40408c09dccefb74c274c783c80d090f840b": "f10964222eff6ed7e980f182b3919667",
".git/objects/1d/af1a6c747d37f0105e79a0e10cbcd865794056": "e5cc32cbda7677fee1d68484b234d1f7",
".git/objects/20/39f2bf616d825e56f3efe9225669de04d8cb6c": "73843d5f319b31b07af3d8b151cbd5a7",
".git/objects/29/f68a6dcfb9f51f6c6885fec4d3cf3cdcabc0f9": "ccb21de5ca22ea15d339a45a4787cbc1",
".git/objects/2e/10b8c1411b444155625a515056950dceffb3ef": "4390bf1e255902537011e00cca4f38b0",
".git/objects/2e/d0cf6650c3ef55f657e8db914549fd8fd52495": "d2ceae5e12d954890611d9bec11da76e",
".git/objects/2f/296b9cebafcb9e56fb36c249b34474fc071a96": "643aa445caeed59ccf96c3c3dd1d3ff2",
".git/objects/31/08f00858a01a09763492ab1c1843a699308936": "0f01b9cbfdf5de958d7cde7f06f2ad50",
".git/objects/31/19d093edb27e7218d51bbc42620758bc6f7ba6": "d45dd92061073d8d4671be7858dedc23",
".git/objects/36/c32c39f058b94f7ed32dbeb90908a1cc71ed35": "6abfca3bb29f6438be3c6cc9c1ed4743",
".git/objects/3a/8cda5335b4b2a108123194b84df133bac91b23": "1636ee51263ed072c69e4e3b8d14f339",
".git/objects/3a/bf18c41c58c933308c244a875bf383856e103e": "30790d31a35e3622fd7b3849c9bf1894",
".git/objects/46/7ac6ec81a488fd92314743cc1da0d573e156d0": "0c3e2f891c1202e0cd8f7bd0d1b79661",
".git/objects/4b/cb25a676630a0fc2090d95f67942badda9ee7a": "08f1b6fe26fabdd4630a0d3b1b660ba3",
".git/objects/4c/b0951ad5901c059f40f36f715347613d2ea2e9": "13c7b4b56d87bf9f6ae56d36dd1472b2",
".git/objects/51/03e757c71f2abfd2269054a790f775ec61ffa4": "d437b77e41df8fcc0c0e99f143adc093",
".git/objects/56/e19354484d90d791f1a1c223146fc02c127b96": "9a83c47f6eb95355e349939924089427",
".git/objects/5e/8316716feec9bcae2e168edd2fa2666f6d58dc": "b254bf55cb6e4976ca7e26a74d1e5819",
".git/objects/5e/aa742354bd950e055c4cdf5e0b1c8d4da2b8ba": "ad86f32bc62bc4aa770fecb926b87a57",
".git/objects/62/b2f333fd89204b3447c4f5bbeb2908588d3980": "d9499031733027ff2f5b0a477080ab12",
".git/objects/68/43fddc6aef172d5576ecce56160b1c73bc0f85": "2a91c358adf65703ab820ee54e7aff37",
".git/objects/6f/7661bc79baa113f478e9a717e0c4959a3f3d27": "985be3a6935e9d31febd5205a9e04c4e",
".git/objects/7c/3463b788d022128d17b29072564326f1fd8819": "37fee507a59e935fc85169a822943ba2",
".git/objects/81/b4e3a55c51fb1682d561ec1a03028702cdf780": "6a8ec6871c45a1c6f07c48eaa1fd44c8",
".git/objects/83/7f0198b9fc9dda74d7c04b81ab4f707990e879": "37ec34db8ce139a945ce9887d0f47d50",
".git/objects/85/63aed2175379d2e75ec05ec0373a302730b6ad": "997f96db42b2dde7c208b10d023a5a8e",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/8e/21753cdb204192a414b235db41da6a8446c8b4": "1e467e19cabb5d3d38b8fe200c37479e",
".git/objects/90/c30caa88e047d0491375a55a1add34758e361b": "31a40d647466a37a4f3718f978a37ca1",
".git/objects/92/a77694a2411a0aea848437df539024eb07abe3": "b2669a9da6fc2fb79cfead6096f2af85",
".git/objects/93/b363f37b4951e6c5b9e1932ed169c9928b1e90": "c8d74fb3083c0dc39be8cff78a1d4dd5",
".git/objects/96/a182b26bc1b92cf0efec380857438acee5286a": "3b840be97b4b63521625efe1e10dfb23",
".git/objects/98/eb131c11f830cda88c0fbfeeaf62966ef1f65f": "f5d2fd3318012f85358b124e82682a3d",
".git/objects/a5/241e068888831c286e316738ce1bf597ba1925": "8d304bed1790b05e1a24001b20f03f5c",
".git/objects/a5/4924fac937962a794ccd50176eee533d08a7c6": "5b2c43e98bceb16aa80d94442e848ddf",
".git/objects/a7/3f4b23dde68ce5a05ce4c658ccd690c7f707ec": "ee275830276a88bac752feff80ed6470",
".git/objects/ab/b4eb49768f1e3f36c8e57962089bed23f3a837": "0e5df89940519c6b187bbdb0196490a0",
".git/objects/ac/55f5e6f995acd250f0c48b8f95efcacea915de": "6e276af75fce5efd4b331680f1a7f0b8",
".git/objects/ad/ced61befd6b9d30829511317b07b72e66918a1": "37e7fcca73f0b6930673b256fac467ae",
".git/objects/b3/2d6b8bce36faf01e476320dbbff44419b82a7b": "c28dcddd3ef6ebe702c03258fc288591",
".git/objects/b5/85d1f5b10b192d86b343c9d200c73a90ebcc62": "7a9de47217c146f198a0b1612fef0377",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/b9/3e39bd49dfaf9e225bb598cd9644f833badd9a": "666b0d595ebbcc37f0c7b61220c18864",
".git/objects/c6/234579227c05b00d50df0e92efd332490373b6": "ab02ab424b3c2e021a22b4444f495665",
".git/objects/c7/2159b8e6c62819062addcc62f9ff5bcd045c52": "72ae2c2da4c2147feb9848899e91ab4c",
".git/objects/c8/3af99da428c63c1f82efdcd11c8d5297bddb04": "144ef6d9a8ff9a753d6e3b9573d5242f",
".git/objects/cb/f55ea9041a50176f9ece41b300f2984ca7e7d3": "c2f3b3a944aad20ccd41f2f679dfdb89",
".git/objects/cc/c80af2e5dddfd63355cdac2b9099fb6dbad68d": "e9804756ea573c38f1fe08e3e54c2eb1",
".git/objects/cf/724218095278344311bd01380be4f95c3c3e65": "166f3d6690d91252b827d0de78f7ed19",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/d6/ca91a15ef974bfa5904598d92f36eb2cfceb2b": "c46bb8234179fac12841c21484ac5775",
".git/objects/d6/f76ac464c3fd0b7a9e18870b87d0ce20a4b699": "4c2873737e0d328fab9cb452a8a502c3",
".git/objects/d9/5b1d3499b3b3d3989fa2a461151ba2abd92a07": "a072a09ac2efe43c8d49b7356317e52e",
".git/objects/dd/bb74989daa78b2a133441f4295d89c73954d71": "ae68b90f21d0f8c06cdbbd91413ec86e",
".git/objects/df/338ce5c2443cb2cf6e86ce2cf7b2b9d5df66ca": "16076803762ed803a3022c84979e2c7b",
".git/objects/e1/4cd896003970413c8c2ddd21b50999f284a877": "1b2c113efd21dab566f8bac91e763b54",
".git/objects/e1/cd1dada0f6d464eeefd71ddfc579a00b49fd3d": "3f9e4324846d469fa6e2ee9ca404c0eb",
".git/objects/e2/a131684729a332072c694733bfca33dba31b34": "947ecdc8140712a5e1ef02ec70a8472a",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/ef/72329064cb1767f21d649e0e0faf662cba15b6": "75a898e5d1f9603e67da8e1a27c2950f",
".git/objects/f0/fda35d921bf53ced8f531c53e1939d9a29b236": "6ab19f4e63733266ff7b572d29dbeeb7",
".git/objects/f3/3e0726c3581f96c51f862cf61120af36599a32": "afcaefd94c5f13d3da610e0defa27e50",
".git/objects/f4/91ec4f094432d84fef9d37cc397290255a6673": "c662878f8ed8fda16cc27702e9ea452c",
".git/objects/f6/e6c75d6f1151eeb165a90f04b4d99effa41e83": "95ea83d65d44e4c524c6d51286406ac8",
".git/objects/fa/ed8e880653a4958369af9642be1b41e677d275": "842581cfb805371217773af3d3230b90",
".git/objects/fd/05cfbc927a4fedcbe4d6d4b62e2c1ed8918f26": "5675c69555d005a1a244cc8ba90a402c",
".git/objects/fd/7fa8ea8ee6d533ffb5f31bd4966fa4b0178a67": "c346ec7ad852395779f72bbc7a833bd1",
".git/objects/ff/28b3cd99a4fc6878add121a0cb212ec53d360f": "598c053cc95bb3a89af0984ae65e4077",
".git/refs/heads/main": "0d4f426cfb8bff150dfb4e676f4cb1a0",
".git/refs/remotes/origin/main": "0d4f426cfb8bff150dfb4e676f4cb1a0",
"assets/AssetManifest.bin": "dfc3692eb4dbf462f1c5ec9ad6c52fa6",
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
"flutter_bootstrap.js": "a542dd3736216f2899eb7595b4a8e68b",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "5a103ef58c8f3a1ab890e6e195239c4f",
"/": "5a103ef58c8f3a1ab890e6e195239c4f",
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
