globalThis.__nitro_main__ = import.meta.url;
import { a as FastResponse, i as defineLazyEventHandler, n as HTTPError, t as H3Core } from "./_libs/h3+rou3+srvx.mjs";
import { t as HookableCore } from "./_libs/hookable.mjs";
//#region #nitro-vite-setup
function lazyService(loader) {
	let promise, mod;
	return { fetch(req) {
		if (mod) return mod.fetch(req);
		if (!promise) promise = loader().then((_mod) => mod = _mod.default || _mod);
		return promise.then((mod) => mod.fetch(req));
	} };
}
var services = { ["ssr"]: lazyService(() => import("./_ssr/ssr.mjs")) };
globalThis.__nitro_vite_envs__ = services;
//#endregion
//#region #nitro/virtual/public-assets-data
var public_assets_data_default = {
	"/assets/account-DHP3D4lC.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"938-ZmRSGamlMRYhLxlefqB8HRbOm3Y\"",
		"mtime": "2026-07-15T15:04:50.130Z",
		"size": 2360,
		"path": "../public/assets/account-DHP3D4lC.js"
	},
	"/assets/admin-store-ChI9flUx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1e2-RhYRbE48SpN4sKuLLG5y0tHtvbU\"",
		"mtime": "2026-07-15T15:04:50.132Z",
		"size": 482,
		"path": "../public/assets/admin-store-ChI9flUx.js"
	},
	"/assets/admin-DYIRucf5.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"20d1-xqKhLgWUz2siQAoJ6icNCBhejlI\"",
		"mtime": "2026-07-15T15:04:50.131Z",
		"size": 8401,
		"path": "../public/assets/admin-DYIRucf5.js"
	},
	"/assets/admin.actions-Dx8sonoD.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7e9-xhfv/3JiQ2Utv+Wlj2NwgdwgG3Y\"",
		"mtime": "2026-07-15T15:04:50.133Z",
		"size": 2025,
		"path": "../public/assets/admin.actions-Dx8sonoD.js"
	},
	"/assets/admin.categories-D7NE1l0b.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"23bd-2JQhrcP9cHBluURijxEmYf3c2Zc\"",
		"mtime": "2026-07-15T15:04:50.134Z",
		"size": 9149,
		"path": "../public/assets/admin.categories-D7NE1l0b.js"
	},
	"/favicon.ico": {
		"type": "image/vnd.microsoft.icon",
		"etag": "\"4f95-3RXc3p2mhEAs1WBwaIvE0Y0uu0Y\"",
		"mtime": "2026-07-09T14:02:00.313Z",
		"size": 20373,
		"path": "../public/favicon.ico"
	},
	"/assets/admin.index-BV2MvBf9.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2085-s7bDs77L/jSSx9+G+kMozkCQRD4\"",
		"mtime": "2026-07-15T15:04:50.136Z",
		"size": 8325,
		"path": "../public/assets/admin.index-BV2MvBf9.js"
	},
	"/assets/admin.inventory-D53MQfO2.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1d2d-HrmEkaFgnGUn42eZ+S1+V9bHftc\"",
		"mtime": "2026-07-15T15:04:50.136Z",
		"size": 7469,
		"path": "../public/assets/admin.inventory-D53MQfO2.js"
	},
	"/assets/admin.platform-DTPKdaZu.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"18f9-Pt/hH1GFxS/p10xhcl1NBNQ73Vw\"",
		"mtime": "2026-07-15T15:04:50.137Z",
		"size": 6393,
		"path": "../public/assets/admin.platform-DTPKdaZu.js"
	},
	"/assets/admin.product._id-BcAhfGp4.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"91e7-BFVN7cKvaxsKBEkVQuBQg315Z8M\"",
		"mtime": "2026-07-15T15:04:50.138Z",
		"size": 37351,
		"path": "../public/assets/admin.product._id-BcAhfGp4.js"
	},
	"/assets/admin.sessions-B_SG5jcv.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"93f-/wV2r02K1nqSAcGz4f1sa1GRB+Q\"",
		"mtime": "2026-07-15T15:04:50.142Z",
		"size": 2367,
		"path": "../public/assets/admin.sessions-B_SG5jcv.js"
	},
	"/assets/admin.products-BAX2YGrV.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2158-+TgK26Ph0mZ4KIxTuLuXUFJkTkE\"",
		"mtime": "2026-07-15T15:04:50.140Z",
		"size": 8536,
		"path": "../public/assets/admin.products-BAX2YGrV.js"
	},
	"/assets/admin.studio-BQpdOOd_.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1f9a-JQWznrigzg7yyxl1akDMACGStAY\"",
		"mtime": "2026-07-15T15:04:50.144Z",
		"size": 8090,
		"path": "../public/assets/admin.studio-BQpdOOd_.js"
	},
	"/assets/admin.settings-b62yehEE.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"b7e-ex2bREo8vphm67r/xptcruMoMy0\"",
		"mtime": "2026-07-15T15:04:50.143Z",
		"size": 2942,
		"path": "../public/assets/admin.settings-b62yehEE.js"
	},
	"/assets/ai-3d-generator-CBgPXCnP.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"f6cd-ZA8mE2koNBRx+PDdoNoc+Gesu1E\"",
		"mtime": "2026-07-15T15:04:50.145Z",
		"size": 63181,
		"path": "../public/assets/ai-3d-generator-CBgPXCnP.js"
	},
	"/assets/AnimatePresence-DNkpRaW4.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"106b-W93knlxJL0pSx4HpXxHkWfYmid8\"",
		"mtime": "2026-07-15T15:04:50.128Z",
		"size": 4203,
		"path": "../public/assets/AnimatePresence-DNkpRaW4.js"
	},
	"/assets/auth-BMfqhB06.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2331-Ebl/N0KrBBLoRm1ugM9rAGbeYdI\"",
		"mtime": "2026-07-15T15:04:50.145Z",
		"size": 9009,
		"path": "../public/assets/auth-BMfqhB06.js"
	},
	"/assets/auth-middleware-paf7n6yA.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8f7f-qWnEq2bhWvnQnte/8GNGWELDVXQ\"",
		"mtime": "2026-07-15T15:04:50.146Z",
		"size": 36735,
		"path": "../public/assets/auth-middleware-paf7n6yA.js"
	},
	"/assets/cart-LxQy9bxN.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"143b-Uk4tEUkNklr6Zt7HLuWK04b73LE\"",
		"mtime": "2026-07-15T15:04:50.147Z",
		"size": 5179,
		"path": "../public/assets/cart-LxQy9bxN.js"
	},
	"/assets/catalog.functions-AE9_tLEx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"79e-Kl2f2iaYr1Bqd90gxei+tQSO2Vs\"",
		"mtime": "2026-07-15T15:04:50.149Z",
		"size": 1950,
		"path": "../public/assets/catalog.functions-AE9_tLEx.js"
	},
	"/assets/category._id-CtnTiHEg.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"142-4BsOAUesf0Jd20A+kbPgIphkF9Y\"",
		"mtime": "2026-07-15T15:04:50.151Z",
		"size": 322,
		"path": "../public/assets/category._id-CtnTiHEg.js"
	},
	"/assets/category._id-DQWz8GpW.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2ae-3tvdYDooARQqxPynC2g6e/RLTSc\"",
		"mtime": "2026-07-15T15:04:50.152Z",
		"size": 686,
		"path": "../public/assets/category._id-DQWz8GpW.js"
	},
	"/assets/category._id-C_9oQqpO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"cb-TTSVOCGrfraFFNkj+Gn6ecCBxfA\"",
		"mtime": "2026-07-15T15:04:50.149Z",
		"size": 203,
		"path": "../public/assets/category._id-C_9oQqpO.js"
	},
	"/assets/checkout-hlhF3LcP.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"ed0-FuO/VfEpp5dQnUaAQGY9uFm8Fv0\"",
		"mtime": "2026-07-15T15:04:50.153Z",
		"size": 3792,
		"path": "../public/assets/checkout-hlhF3LcP.js"
	},
	"/assets/demo.3d-viewer-DDj2oTyI.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"309-FwTk3TCj02VzyVsNUCZdGNINXqA\"",
		"mtime": "2026-07-15T15:04:50.154Z",
		"size": 777,
		"path": "../public/assets/demo.3d-viewer-DDj2oTyI.js"
	},
	"/assets/i18n-DHgAXKaP.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1073-Q+YFMglLwarxXtVcvXhs8swvI0Q\"",
		"mtime": "2026-07-15T15:04:50.155Z",
		"size": 4211,
		"path": "../public/assets/i18n-DHgAXKaP.js"
	},
	"/assets/immersive-store-D5hkw65i.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2da0-nw3YAWSC9i4eS+0vaV8iwBBxEok\"",
		"mtime": "2026-07-15T15:04:50.156Z",
		"size": 11680,
		"path": "../public/assets/immersive-store-D5hkw65i.js"
	},
	"/assets/invariant-DEEwAagU.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"3c-eVh/3DMi1s3cxf4N/OJar+ew1jA\"",
		"mtime": "2026-07-15T15:04:50.157Z",
		"size": 60,
		"path": "../public/assets/invariant-DEEwAagU.js"
	},
	"/assets/jsx-runtime-CZcjcDnw.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"4e3-jCOgwIq6oGNLw0tt5XnD3UYp7FI\"",
		"mtime": "2026-07-15T15:04:50.157Z",
		"size": 1251,
		"path": "../public/assets/jsx-runtime-CZcjcDnw.js"
	},
	"/assets/link-CgZewjgc.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"596f-EteD5tzsVJDe8gt237gL6JQPht0\"",
		"mtime": "2026-07-15T15:04:50.159Z",
		"size": 22895,
		"path": "../public/assets/link-CgZewjgc.js"
	},
	"/assets/model-viewer-Ca8DjIfX.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8e6-dTVI/rJFaVrcSUZSF08BU9+97+U\"",
		"mtime": "2026-07-15T15:04:50.161Z",
		"size": 2278,
		"path": "../public/assets/model-viewer-Ca8DjIfX.js"
	},
	"/assets/offers-C_9oQqpO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"cb-TTSVOCGrfraFFNkj+Gn6ecCBxfA\"",
		"mtime": "2026-07-15T15:04:50.162Z",
		"size": 203,
		"path": "../public/assets/offers-C_9oQqpO.js"
	},
	"/assets/offers-wAk5FH07.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"3df-s+rhE8fQszQjhQki6YJKfseaFnE\"",
		"mtime": "2026-07-15T15:04:50.163Z",
		"size": 991,
		"path": "../public/assets/offers-wAk5FH07.js"
	},
	"/assets/onboarding-BiDsELaY.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"17e4-XNxWzXv68+N2GA9JoMJR+5ZMphA\"",
		"mtime": "2026-07-15T15:04:50.164Z",
		"size": 6116,
		"path": "../public/assets/onboarding-BiDsELaY.js"
	},
	"/assets/product-card-CqEtRVUp.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"dae-t4x8ibmAgRz96grRLDEEusNWIGk\"",
		"mtime": "2026-07-15T15:04:50.166Z",
		"size": 3502,
		"path": "../public/assets/product-card-CqEtRVUp.js"
	},
	"/assets/product.actions-Dqqx2Gwa.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"94b-+ekdJJgzOEhNuuQCXBySjJHyvbc\"",
		"mtime": "2026-07-15T15:04:50.170Z",
		"size": 2379,
		"path": "../public/assets/product.actions-Dqqx2Gwa.js"
	},
	"/assets/product._slug-5Cfgdnyc.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"187-9DUySYlTAWro/0Au6xhsce/5RI4\"",
		"mtime": "2026-07-15T15:04:50.167Z",
		"size": 391,
		"path": "../public/assets/product._slug-5Cfgdnyc.js"
	},
	"/assets/product._slug-C_9oQqpO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"cb-TTSVOCGrfraFFNkj+Gn6ecCBxfA\"",
		"mtime": "2026-07-15T15:04:50.168Z",
		"size": 203,
		"path": "../public/assets/product._slug-C_9oQqpO.js"
	},
	"/assets/product._slug-i6N4U0n7.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2d85-HfYg7NUeSQsjK1VFvMmOysERyC4\"",
		"mtime": "2026-07-15T15:04:50.169Z",
		"size": 11653,
		"path": "../public/assets/product._slug-i6N4U0n7.js"
	},
	"/assets/react-dom-UJG8Qsxk.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"df6-0ClNN436wzqjrTzfAfXJqcuTS5Q\"",
		"mtime": "2026-07-15T15:04:50.173Z",
		"size": 3574,
		"path": "../public/assets/react-dom-UJG8Qsxk.js"
	},
	"/assets/react-DQyofxZ5.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1d67-snw2lFMbPwvGE1wpDHfmk1LKcs4\"",
		"mtime": "2026-07-15T15:04:50.172Z",
		"size": 7527,
		"path": "../public/assets/react-DQyofxZ5.js"
	},
	"/assets/proxy-DX4fs31U.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1d93a-CQhoncpuIY2vdETIA0IuJRm/Vz0\"",
		"mtime": "2026-07-15T15:04:50.171Z",
		"size": 121146,
		"path": "../public/assets/proxy-DX4fs31U.js"
	},
	"/assets/root-DLTE-HSj.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"20-vSYConOtSP6ciwr9zKsPixNwWmc\"",
		"mtime": "2026-07-15T15:04:50.174Z",
		"size": 32,
		"path": "../public/assets/root-DLTE-HSj.js"
	},
	"/assets/routes-C_9oQqpO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"cb-TTSVOCGrfraFFNkj+Gn6ecCBxfA\"",
		"mtime": "2026-07-15T15:04:50.175Z",
		"size": 203,
		"path": "../public/assets/routes-C_9oQqpO.js"
	},
	"/assets/search-BnRxgOmL.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"5bc-lWQorogRlzNWBbBWjFf4QNv7dl4\"",
		"mtime": "2026-07-15T15:04:50.178Z",
		"size": 1468,
		"path": "../public/assets/search-BnRxgOmL.js"
	},
	"/assets/store-data-lcQPPFg4.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"d14-MdIbivdwtROpwe5la0EvBhjDktM\"",
		"mtime": "2026-07-15T15:04:50.178Z",
		"size": 3348,
		"path": "../public/assets/store-data-lcQPPFg4.js"
	},
	"/assets/styles-Cq4Vjqr_.css": {
		"type": "text/css; charset=utf-8",
		"etag": "\"44878-4MvJ4dD/q516Ay/d0tLU6TwYBvY\"",
		"mtime": "2026-07-15T15:04:50.189Z",
		"size": 280696,
		"path": "../public/assets/styles-Cq4Vjqr_.css"
	},
	"/assets/noqta-logo-kd6fyWSj.png": {
		"type": "image/png",
		"etag": "\"aa42e-uN78tNReS0A3jyKsYYNxiPMjJoY\"",
		"mtime": "2026-07-15T15:04:50.188Z",
		"size": 697390,
		"path": "../public/assets/noqta-logo-kd6fyWSj.png"
	},
	"/assets/routes-XDPKEZAz.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"dd466-k616PNsivkBd21Ube1W2DN6h/wc\"",
		"mtime": "2026-07-15T15:04:50.176Z",
		"size": 906342,
		"path": "../public/assets/routes-XDPKEZAz.js"
	},
	"/assets/index-HhHRm5hm.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1191a9-D87cVKrl3Yn7b6/uL4nGRgasBUM\"",
		"mtime": "2026-07-15T15:04:50.127Z",
		"size": 1151401,
		"path": "../public/assets/index-HhHRm5hm.js"
	},
	"/assets/tajawal-arabic-400-normal-CyCXRvzh.woff2": {
		"type": "font/woff2",
		"etag": "\"22e4-htzAFQstcbuMF+wRaCzQur6CVr4\"",
		"mtime": "2026-07-15T15:04:50.190Z",
		"size": 8932,
		"path": "../public/assets/tajawal-arabic-400-normal-CyCXRvzh.woff2"
	},
	"/assets/tajawal-arabic-400-normal-DCQxawbB.woff": {
		"type": "font/woff",
		"etag": "\"2eec-vFoXwU3KrmLj8pnTxB6gXpwdzXs\"",
		"mtime": "2026-07-15T15:04:50.191Z",
		"size": 12012,
		"path": "../public/assets/tajawal-arabic-400-normal-DCQxawbB.woff"
	},
	"/assets/tajawal-arabic-500-normal-BZ8ojJNu.woff2": {
		"type": "font/woff2",
		"etag": "\"22ec-vUW6AbrjwdH09NeBbv0lv70nlRk\"",
		"mtime": "2026-07-15T15:04:50.192Z",
		"size": 8940,
		"path": "../public/assets/tajawal-arabic-500-normal-BZ8ojJNu.woff2"
	},
	"/assets/tajawal-arabic-500-normal-CbVEaYEW.woff": {
		"type": "font/woff",
		"etag": "\"2e68-NEGLI35Y/HpoOLimmjG8KJ0ApGg\"",
		"mtime": "2026-07-15T15:04:50.194Z",
		"size": 11880,
		"path": "../public/assets/tajawal-arabic-500-normal-CbVEaYEW.woff"
	},
	"/assets/tajawal-arabic-700-normal-9L7Zusdl.woff": {
		"type": "font/woff",
		"etag": "\"2f80-4RWf3CKpG924VXeRmL/sd+C9M1M\"",
		"mtime": "2026-07-15T15:04:50.196Z",
		"size": 12160,
		"path": "../public/assets/tajawal-arabic-700-normal-9L7Zusdl.woff"
	},
	"/assets/tajawal-arabic-800-normal-Bp_4IW2m.woff": {
		"type": "font/woff",
		"etag": "\"312c-aXWadQS2qEgdZwSePW37enhhb+0\"",
		"mtime": "2026-07-15T15:04:50.199Z",
		"size": 12588,
		"path": "../public/assets/tajawal-arabic-800-normal-Bp_4IW2m.woff"
	},
	"/assets/tajawal-arabic-700-normal-D2-eand5.woff2": {
		"type": "font/woff2",
		"etag": "\"2340-GPygwY9uCPibTwXPwIY4Le7OnYg\"",
		"mtime": "2026-07-15T15:04:50.198Z",
		"size": 9024,
		"path": "../public/assets/tajawal-arabic-700-normal-D2-eand5.woff2"
	},
	"/assets/tajawal-arabic-800-normal-TQp-UTiE.woff2": {
		"type": "font/woff2",
		"etag": "\"24e8-LpRwplN3A92ETy8OjLyrBXH07Rw\"",
		"mtime": "2026-07-15T15:04:50.199Z",
		"size": 9448,
		"path": "../public/assets/tajawal-arabic-800-normal-TQp-UTiE.woff2"
	},
	"/assets/tajawal-arabic-900-normal-CHO_pm7-.woff": {
		"type": "font/woff",
		"etag": "\"2e40-7qutE+85kzDH9ISHfuxrsjaLtto\"",
		"mtime": "2026-07-15T15:04:50.201Z",
		"size": 11840,
		"path": "../public/assets/tajawal-arabic-900-normal-CHO_pm7-.woff"
	},
	"/assets/tajawal-arabic-900-normal-MgmkhdPX.woff2": {
		"type": "font/woff2",
		"etag": "\"21fc-u9LGlvQFzr5unanNdZ+90AppPIw\"",
		"mtime": "2026-07-15T15:04:50.202Z",
		"size": 8700,
		"path": "../public/assets/tajawal-arabic-900-normal-MgmkhdPX.woff2"
	},
	"/assets/tajawal-latin-400-normal-BdYcZznU.woff": {
		"type": "font/woff",
		"etag": "\"3498-iGpQgKM9/eUtkdYYTHnFy/gjsxw\"",
		"mtime": "2026-07-15T15:04:50.206Z",
		"size": 13464,
		"path": "../public/assets/tajawal-latin-400-normal-BdYcZznU.woff"
	},
	"/assets/tajawal-latin-400-normal-BVNSOH3d.woff2": {
		"type": "font/woff2",
		"etag": "\"2810-qejpN8Wvwvn+tGv8uPqFRyiklKg\"",
		"mtime": "2026-07-15T15:04:50.206Z",
		"size": 10256,
		"path": "../public/assets/tajawal-latin-400-normal-BVNSOH3d.woff2"
	},
	"/assets/tajawal-latin-500-normal-CoYeBiSI.woff2": {
		"type": "font/woff2",
		"etag": "\"26ac-q+rBt4kKkDrJUcUivJswOexvofg\"",
		"mtime": "2026-07-15T15:04:50.208Z",
		"size": 9900,
		"path": "../public/assets/tajawal-latin-500-normal-CoYeBiSI.woff2"
	},
	"/assets/tajawal-latin-500-normal-DU9v6xgj.woff": {
		"type": "font/woff",
		"etag": "\"32dc-3ckxdMjhU2Iy658yk45a9qqTs9M\"",
		"mtime": "2026-07-15T15:04:50.209Z",
		"size": 13020,
		"path": "../public/assets/tajawal-latin-500-normal-DU9v6xgj.woff"
	},
	"/assets/tajawal-latin-700-normal-BypgxfGb.woff2": {
		"type": "font/woff2",
		"etag": "\"270c-q6QNFLVOk9VRJNpQl1sHXCiWmkE\"",
		"mtime": "2026-07-15T15:04:50.211Z",
		"size": 9996,
		"path": "../public/assets/tajawal-latin-700-normal-BypgxfGb.woff2"
	},
	"/assets/tajawal-latin-700-normal-CV3bxpHe.woff": {
		"type": "font/woff",
		"etag": "\"3368-4hCZuSAB62huCFeyxp0vpb3Nz4k\"",
		"mtime": "2026-07-15T15:04:50.212Z",
		"size": 13160,
		"path": "../public/assets/tajawal-latin-700-normal-CV3bxpHe.woff"
	},
	"/assets/tajawal-latin-800-normal-CmI34b-g.woff2": {
		"type": "font/woff2",
		"etag": "\"2958-C9p1cEvH2YX3uTS3T0M8UymeBrI\"",
		"mtime": "2026-07-15T15:04:50.213Z",
		"size": 10584,
		"path": "../public/assets/tajawal-latin-800-normal-CmI34b-g.woff2"
	},
	"/assets/tajawal-latin-800-normal-Dm5jVIIh.woff": {
		"type": "font/woff",
		"etag": "\"358c-m1pa5htn58QhxdpxPBK0GqPNmFc\"",
		"mtime": "2026-07-15T15:04:50.214Z",
		"size": 13708,
		"path": "../public/assets/tajawal-latin-800-normal-Dm5jVIIh.woff"
	},
	"/assets/tajawal-latin-900-normal-BsVXXeFR.woff": {
		"type": "font/woff",
		"etag": "\"33d8-QKNIZKhqRJWYxmxI46DOK+TPA1U\"",
		"mtime": "2026-07-15T15:04:50.215Z",
		"size": 13272,
		"path": "../public/assets/tajawal-latin-900-normal-BsVXXeFR.woff"
	},
	"/assets/tajawal-latin-900-normal-DURQZvFY.woff2": {
		"type": "font/woff2",
		"etag": "\"27f0-/vklOuMK2+4iSMU93VGTR+FF4Q4\"",
		"mtime": "2026-07-15T15:04:50.215Z",
		"size": 10224,
		"path": "../public/assets/tajawal-latin-900-normal-DURQZvFY.woff2"
	},
	"/assets/Tooltip-4h5TOeA2.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"765-J5Q9xNwhblW+jFdP5zeVP8+pkds\"",
		"mtime": "2026-07-15T15:04:50.129Z",
		"size": 1893,
		"path": "../public/assets/Tooltip-4h5TOeA2.js"
	},
	"/assets/types-C9ViVWBJ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"dc79-tn7FDZLEiI3wzhnDP836WUaOLic\"",
		"mtime": "2026-07-15T15:04:50.179Z",
		"size": 56441,
		"path": "../public/assets/types-C9ViVWBJ.js"
	},
	"/assets/use-transform-LFE0AlJR.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"211d-VPthwbX/o0gP98V3xqNufC09qRM\"",
		"mtime": "2026-07-15T15:04:50.181Z",
		"size": 8477,
		"path": "../public/assets/use-transform-LFE0AlJR.js"
	},
	"/assets/useMatch-DryTNfL5.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2d4-Csr/q+RF628CLQlz++ZIqfbXVz4\"",
		"mtime": "2026-07-15T15:04:50.182Z",
		"size": 724,
		"path": "../public/assets/useMatch-DryTNfL5.js"
	},
	"/assets/useMutation-DTi31wLQ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8ee-KKjK4gvVwvbSjFJxq8FL5WpUjCE\"",
		"mtime": "2026-07-15T15:04:50.183Z",
		"size": 2286,
		"path": "../public/assets/useMutation-DTi31wLQ.js"
	},
	"/assets/useRouter-B7YGYrEu.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"b3-Yz1DOI0MPBIWNRlLF4bglBmTd1g\"",
		"mtime": "2026-07-15T15:04:50.184Z",
		"size": 179,
		"path": "../public/assets/useRouter-B7YGYrEu.js"
	},
	"/assets/useServerFn-ChXxe4ZK.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1bb-cAvXaCkwUE8pna9CFalOH1rZHA0\"",
		"mtime": "2026-07-15T15:04:50.185Z",
		"size": 443,
		"path": "../public/assets/useServerFn-ChXxe4ZK.js"
	},
	"/assets/utils-Dk5T6iHk.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"27a-afQqEHn97jZ78NspFi/1X5hxPZw\"",
		"mtime": "2026-07-15T15:04:50.186Z",
		"size": 634,
		"path": "../public/assets/utils-Dk5T6iHk.js"
	},
	"/assets/vanilla-DZJGj1NY.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"140-BLNu/hF+zF5V++8ZWPh+DVgWh40\"",
		"mtime": "2026-07-15T15:04:50.187Z",
		"size": 320,
		"path": "../public/assets/vanilla-DZJGj1NY.js"
	}
};
//#endregion
//#region #nitro/virtual/public-assets
var publicAssetBases = {};
function isPublicAssetURL(id = "") {
	if (public_assets_data_default[id]) return true;
	for (const base in publicAssetBases) if (id.startsWith(base)) return true;
	return false;
}
//#endregion
//#region node_modules/nitro/dist/runtime/internal/route-rules.mjs
var headers = ((m) => function headersRouteRule(event) {
	for (const [key, value] of Object.entries(m.options || {})) event.res.headers.set(key, value);
});
//#endregion
//#region #nitro/virtual/routing
var findRouteRules = /* @__PURE__ */ (() => {
	const $0 = [{
		name: "headers",
		route: "/assets/**",
		handler: headers,
		options: { "cache-control": "public, max-age=31536000, immutable" }
	}];
	return (m, p) => {
		let r = [];
		if (p.charCodeAt(p.length - 1) === 47) p = p.slice(0, -1) || "/";
		let s = p.split("/");
		if (s.length > 1) {
			if (s[1] === "assets") r.unshift({
				data: $0,
				params: { "_": s.slice(2).join("/") }
			});
		}
		return r;
	};
})();
var _lazy_C2xEFr = defineLazyEventHandler(() => import("./_chunks/renderer-template.mjs"));
var findRoute = /* @__PURE__ */ (() => {
	const data = {
		route: "/**",
		handler: _lazy_C2xEFr
	};
	return ((_m, p) => {
		return {
			data,
			params: { "_": p.slice(1) }
		};
	});
})();
[].filter(Boolean);
//#endregion
//#region node_modules/nitro/dist/runtime/internal/error/prod.mjs
var errorHandler = (error, event) => {
	const res = defaultHandler(error, event);
	return new FastResponse(typeof res.body === "string" ? res.body : JSON.stringify(res.body, null, 2), res);
};
function defaultHandler(error, event) {
	const unhandled = error.unhandled ?? !HTTPError.isError(error);
	const { status = 500, statusText = "" } = unhandled ? {} : error;
	if (status === 404) {
		const url = event.url || new URL(event.req.url);
		const baseURL = "/";
		if (/^\/[^/]/.test(baseURL) && !url.pathname.startsWith(baseURL)) return {
			status: 302,
			headers: new Headers({ location: `${baseURL}${url.pathname.slice(1)}${url.search}` })
		};
	}
	const headers = new Headers(unhandled ? {} : error.headers);
	headers.set("content-type", "application/json; charset=utf-8");
	return {
		status,
		statusText,
		headers,
		body: {
			error: true,
			...unhandled ? {
				status,
				unhandled: true
			} : typeof error.toJSON === "function" ? error.toJSON() : {
				status,
				statusText,
				message: error.message
			}
		}
	};
}
//#endregion
//#region #nitro/virtual/error-handler
var errorHandlers = [errorHandler];
async function error_handler_default(error, event) {
	for (const handler of errorHandlers) try {
		const response = await handler(error, event, { defaultHandler });
		if (response) return response;
	} catch (error) {
		console.error(error);
	}
}
//#endregion
//#region #nitro/virtual/app
function createNitroApp() {
	const captureError = (error, errorCtx) => {
		if (errorCtx?.event) {
			const errors = errorCtx.event.req.context?.nitro?.errors;
			if (errors) errors.push({
				error,
				context: errorCtx
			});
		}
	};
	const h3App = createH3App({ onError(error, event) {
		return error_handler_default(error, event);
	} });
	let appHandler = (req) => {
		req.context ||= {};
		req.context.nitro = req.context.nitro || { errors: [] };
		return h3App.fetch(req);
	};
	return {
		fetch: appHandler,
		h3: h3App,
		hooks: void 0,
		captureError
	};
}
function createH3App(config) {
	const h3App = new H3Core(config);
	h3App["~findRoute"] = (event) => findRoute(event.req.method, event.url.pathname);
	h3App["~getMiddleware"] = (event, route) => {
		const pathname = event.url.pathname;
		const method = event.req.method;
		const middleware = [];
		const routeRules = getRouteRules(method, pathname);
		event.context.routeRules = routeRules?.routeRules;
		if (routeRules?.routeRuleMiddleware.length) middleware.push(...routeRules.routeRuleMiddleware);
		if (route?.data?.middleware?.length) middleware.push(...route.data.middleware);
		return middleware;
	};
	return h3App;
}
//#endregion
//#region node_modules/nitro/dist/runtime/internal/app.mjs
var APP_ID = "default";
function useNitroApp() {
	let instance = useNitroApp._instance;
	if (instance) return instance;
	instance = useNitroApp._instance = createNitroApp();
	globalThis.__nitro__ = globalThis.__nitro__ || {};
	globalThis.__nitro__[APP_ID] = instance;
	return instance;
}
function useNitroHooks() {
	const nitroApp = useNitroApp();
	const hooks = nitroApp.hooks;
	if (hooks) return hooks;
	return nitroApp.hooks = new HookableCore();
}
function getRouteRules(method, pathname) {
	const m = findRouteRules(method, pathname);
	if (!m?.length) return { routeRuleMiddleware: [] };
	const routeRules = {};
	for (const layer of m) for (const rule of layer.data) {
		const currentRule = routeRules[rule.name];
		if (currentRule) {
			if (rule.options === false) {
				delete routeRules[rule.name];
				continue;
			}
			if (typeof currentRule.options === "object" && typeof rule.options === "object") currentRule.options = {
				...currentRule.options,
				...rule.options
			};
			else currentRule.options = rule.options;
			currentRule.route = rule.route;
			currentRule.params = {
				...currentRule.params,
				...layer.params
			};
		} else if (rule.options !== false) routeRules[rule.name] = {
			...rule,
			params: layer.params
		};
	}
	const middleware = [];
	const orderedRules = Object.values(routeRules).sort((a, b) => (a.handler?.order || 0) - (b.handler?.order || 0));
	for (const rule of orderedRules) {
		if (rule.options === false || !rule.handler) continue;
		middleware.push(rule.handler(rule));
	}
	return {
		routeRules,
		routeRuleMiddleware: middleware
	};
}
//#endregion
//#region node_modules/nitro/dist/presets/cloudflare/runtime/_module-handler.mjs
function createHandler(hooks) {
	const nitroApp = useNitroApp();
	const nitroHooks = useNitroHooks();
	return {
		async fetch(request, env, context) {
			globalThis.__env__ = env;
			augmentReq(request, {
				env,
				context
			});
			const ctxExt = {};
			const url = new URL(request.url);
			if (hooks.fetch) {
				const res = await hooks.fetch(request, env, context, url, ctxExt);
				if (res) return res;
			}
			return await nitroApp.fetch(request);
		},
		scheduled(controller, env, context) {
			globalThis.__env__ = env;
			context.waitUntil(nitroHooks.callHook("cloudflare:scheduled", {
				controller,
				env,
				context
			}) || Promise.resolve());
		},
		email(message, env, context) {
			globalThis.__env__ = env;
			context.waitUntil(nitroHooks.callHook("cloudflare:email", {
				message,
				event: message,
				env,
				context
			}) || Promise.resolve());
		},
		queue(batch, env, context) {
			globalThis.__env__ = env;
			context.waitUntil(nitroHooks.callHook("cloudflare:queue", {
				batch,
				event: batch,
				env,
				context
			}) || Promise.resolve());
		},
		tail(traces, env, context) {
			globalThis.__env__ = env;
			context.waitUntil(nitroHooks.callHook("cloudflare:tail", {
				traces,
				env,
				context
			}) || Promise.resolve());
		},
		trace(traces, env, context) {
			globalThis.__env__ = env;
			context.waitUntil(nitroHooks.callHook("cloudflare:trace", {
				traces,
				env,
				context
			}) || Promise.resolve());
		}
	};
}
function augmentReq(cfReq, ctx) {
	const req = cfReq;
	req.ip = cfReq.headers.get("cf-connecting-ip") || void 0;
	req.runtime ??= { name: "cloudflare" };
	req.runtime.cloudflare = {
		...req.runtime.cloudflare,
		...ctx
	};
	req.waitUntil = ctx.context?.waitUntil.bind(ctx.context);
}
//#endregion
//#region node_modules/nitro/dist/presets/cloudflare/runtime/cloudflare-module.mjs
var cloudflare_module_default = createHandler({ fetch(cfRequest, env, context, url) {
	if (env.ASSETS && isPublicAssetURL(url.pathname)) return env.ASSETS.fetch(cfRequest);
} });
//#endregion
export { cloudflare_module_default as default };
