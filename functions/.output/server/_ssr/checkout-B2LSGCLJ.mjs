import { o as __toESM } from "../_runtime.mjs";
import { c as require_jsx_runtime, l as require_react } from "../_libs/@astryxdesign/core+[...].mjs";
import { g as Link, v as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { H as LoaderCircle, lt as CircleAlert, y as ShoppingBag } from "../_libs/lucide-react.mjs";
import { t as useCart } from "./cart-store-CNi_4HlM.mjs";
import { t as Route } from "./checkout-BwImLLRa.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/checkout-B2LSGCLJ.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
/**
* Parse the Meta Commerce `products` query parameter.
* Format: "id1:qty1,id2:qty2" — quantities default to 1 when omitted or invalid.
* Returns an empty array for a missing or blank param (not an error).
*/
function CheckoutBridgePage() {
	const { products: productsParam, coupon: couponParam } = Route.useSearch();
	const { resolvedProducts, parsedItems } = Route.useLoaderData();
	const navigate = useNavigate();
	const add = useCart((s) => s.add);
	const clear = useCart((s) => s.clear);
	const items = useCart((s) => s.items);
	const [errorMsg, setErrorMsg] = (0, import_react.useState)(null);
	const [missingIds, setMissingIds] = (0, import_react.useState)([]);
	const cartPopulated = (0, import_react.useRef)(false);
	(0, import_react.useEffect)(() => {
		if (!productsParam) return;
		const missing = parsedItems.filter((parsedItem) => !resolvedProducts.some((product) => product.id === parsedItem.id || product.external_id === parsedItem.id || product.slug === parsedItem.id));
		if (missing.length > 0) {
			const missingIdsList = missing.map((m) => m.id);
			console.warn("Meta checkout integration - Some requested products were not resolved:", missingIdsList);
			setMissingIds(missingIdsList);
			setErrorMsg("بعض المنتجات المطلوبة غير موجودة أو لم تتم مزامنتها مع الكتالوج.");
			return;
		}
		if (!cartPopulated.current) {
			cartPopulated.current = true;
			clear();
			parsedItems.forEach((parsedItem) => {
				const product = resolvedProducts.find((p) => p.id === parsedItem.id || p.external_id === parsedItem.id || p.slug === parsedItem.id);
				if (product) add(product, parsedItem.qty);
			});
			navigate({
				to: "/cart",
				search: couponParam ? { coupon: couponParam } : void 0
			});
		}
	}, [
		productsParam,
		parsedItems,
		resolvedProducts,
		add,
		clear,
		navigate,
		couponParam
	]);
	if (!productsParam) {
		if (items.length > 0) {
			navigate({
				to: "/cart",
				search: couponParam ? { coupon: couponParam } : void 0
			});
			return null;
		}
		return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "flex flex-col items-center justify-center gap-4 px-6 py-20 text-center text-white",
			dir: "rtl",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "grid h-16 w-16 place-items-center rounded-full bg-white/5 border border-white/10 text-primary",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShoppingBag, { className: "h-8 w-8" })
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
					className: "text-lg font-black",
					children: "سلتك فارغة"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-white/60 max-w-xs",
					children: "لم يتم تحديد أي منتجات في الرابط. ابدأ التسوق وأضف المنتجات لسلتك."
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
					to: "/",
					className: "mt-2 inline-flex items-center gap-2 rounded-xl gradient-brand px-5 py-2.5 text-sm font-bold text-white shadow-brand transition hover:scale-[1.02]",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "تصفح المنتجات" })
				})
			]
		});
	}
	if (errorMsg) return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "flex flex-col items-center justify-center gap-6 px-6 py-20 text-center text-white",
		dir: "rtl",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "grid h-16 w-16 place-items-center rounded-full bg-destructive/15 border border-destructive/30 text-destructive",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CircleAlert, { className: "h-8 w-8" })
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex flex-col gap-2 max-w-md",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
						className: "text-lg font-black text-destructive",
						children: errorMsg
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "text-xs text-white/50 leading-relaxed",
						children: "الرجاء التأكد من مزامنة كتالوج منتجات Meta مع المتجر الإلكتروني وتطابق معرّفات المنتجات (Content IDs / External IDs / Slugs)."
					}),
					missingIds.length > 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-2 rounded-xl bg-white/5 p-3 text-start border border-white/10",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-[10px] uppercase font-bold tracking-wider text-white/40",
							children: "المعرفات غير الموجودة:"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
							className: "mt-1 list-inside list-disc text-xs font-mono text-white/70",
							children: missingIds.map((id) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: id }, id))
						})]
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
				to: "/",
				className: "inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-5 py-2.5 text-sm font-bold text-white hover:bg-white/10 transition",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "العودة للمتجر" })
			})
		]
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "flex flex-col items-center justify-center gap-4 px-6 py-20 text-center text-white",
		dir: "rtl",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-8 w-8 animate-spin text-primary" }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
				className: "text-sm font-bold",
				children: "جاري معالجة وتجهيز عربة التسوق..."
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "text-xs text-white/60",
				children: "سيتم تحويلك إلى صفحة السلة تلقائياً لإتمام الطلب."
			})
		]
	});
}
//#endregion
export { CheckoutBridgePage as component };
