import { o as __toESM } from "../_runtime.mjs";
import { c as require_jsx_runtime, l as require_react } from "../_libs/@astryxdesign/core+[...].mjs";
import { g as Link, v as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { G as Layers, H as LoaderCircle, I as Minus, J as Image, P as Package, T as Save, U as Link$1, Y as ImagePlus, _ as Sparkles, _t as ArrowLeft, a as X, at as Copy, dt as Check, et as Eye, f as Trash2, g as Star, j as Plus, k as RefreshCw, mt as ArrowUp, o as WandSparkles, ot as Clock, p as Tag, pt as Boxes, q as Info, rt as DollarSign, ut as ChevronDown, vt as ArrowDown, w as Search } from "../_libs/lucide-react.mjs";
import { n as useI18n } from "./i18n-ut2VIwHl.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
import { a as getAdminProduct, f as updateAdminProduct, i as deleteAdminProduct, l as listInventoryMovements, n as createAdminProduct, s as listAdminCategories, u as recordInventoryMovement } from "./admin.actions-Buk2_Af3.mjs";
import { n as toast } from "../_libs/sonner.mjs";
import { t as Route } from "./admin.product._id-jDxr4oX7.mjs";
import { t as Ai3dGeneratorPanel } from "./ai-3d-generator-Q9ujjqlR.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/admin.product._id-CY7shl3Y.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var STORAGE_PREFIX = "admin-product-card:";
function CollapsibleCard({ id, title, subtitle, icon, right, defaultOpen = true, children }) {
	const [open, setOpen] = (0, import_react.useState)(defaultOpen);
	const [ready, setReady] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		try {
			const v = localStorage.getItem(STORAGE_PREFIX + id);
			if (v === "0") setOpen(false);
			else if (v === "1") setOpen(true);
		} catch {}
		setReady(true);
	}, [id]);
	(0, import_react.useEffect)(() => {
		if (!ready) return;
		try {
			localStorage.setItem(STORAGE_PREFIX + id, open ? "1" : "0");
		} catch {}
	}, [
		open,
		id,
		ready
	]);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
		className: "rounded-2xl glass overflow-hidden",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
			className: "flex items-center gap-3 px-5 py-4",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
				type: "button",
				onClick: () => setOpen((v) => !v),
				"aria-expanded": open,
				"aria-controls": `card-body-${id}`,
				className: "flex min-w-0 flex-1 items-center gap-3 text-start",
				children: [
					icon ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
						className: "grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary",
						children: icon
					}) : null,
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
						className: "min-w-0 flex-1",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "block truncate text-sm font-black",
							children: title
						}), subtitle ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "block truncate text-xs text-muted-foreground",
							children: subtitle
						}) : null]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ChevronDown, { className: `h-4 w-4 shrink-0 text-muted-foreground transition-transform ${open ? "rotate-180" : ""}` })
				]
			}), right ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "shrink-0",
				children: right
			}) : null]
		}), open && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			id: `card-body-${id}`,
			className: "border-t border-border/60 px-5 py-4",
			children
		})]
	});
}
function ChipInput({ value, onChange, placeholder = "أضف عنصر ثم Enter", suggestions = [], ariaLabel }) {
	const [draft, setDraft] = (0, import_react.useState)("");
	const add = (raw) => {
		const v = raw.trim();
		if (!v) return;
		if (value.some((x) => x.toLowerCase() === v.toLowerCase())) {
			setDraft("");
			return;
		}
		onChange([...value, v]);
		setDraft("");
	};
	const remove = (i) => onChange(value.filter((_, idx) => idx !== i));
	const onKey = (e) => {
		if (e.key === "Enter" || e.key === "," || e.key === "Tab") {
			if (draft.trim()) {
				e.preventDefault();
				add(draft);
			}
		} else if (e.key === "Backspace" && !draft && value.length) onChange(value.slice(0, -1));
	};
	const availableSuggestions = suggestions.filter((s) => !value.some((v) => v.toLowerCase() === s.toLowerCase()));
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		role: "group",
		"aria-label": ariaLabel,
		className: "flex flex-wrap items-center gap-1.5 rounded-xl border border-border bg-surface p-2 focus-within:border-primary",
		children: [value.map((tag, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
			className: "inline-flex items-center gap-1 rounded-lg bg-primary/10 px-2 py-1 text-xs font-bold text-primary",
			children: [tag, /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
				type: "button",
				onClick: () => remove(i),
				className: "rounded-full p-0.5 hover:bg-primary/20",
				"aria-label": `إزالة ${tag}`,
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(X, { className: "h-3 w-3" })
			})]
		}, `${tag}-${i}`)), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
			value: draft,
			onChange: (e) => setDraft(e.target.value),
			onKeyDown: onKey,
			onBlur: () => draft.trim() && add(draft),
			placeholder,
			className: "min-w-[120px] flex-1 bg-transparent px-1 py-0.5 text-sm outline-none"
		})]
	}), availableSuggestions.length > 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: "mt-2 flex flex-wrap gap-1.5",
		children: availableSuggestions.slice(0, 8).map((s) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
			type: "button",
			onClick: () => add(s),
			className: "inline-flex items-center gap-1 rounded-lg border border-dashed border-border px-2 py-0.5 text-[11px] font-bold text-muted-foreground hover:border-primary hover:text-primary",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "h-3 w-3" }),
				" ",
				s
			]
		}, s))
	})] });
}
var isProbablyUrl = (s) => /^https?:\/\//i.test(s.trim());
function ImageManager({ value, onChange }) {
	const [urlDraft, setUrlDraft] = (0, import_react.useState)("");
	const [dragIndex, setDragIndex] = (0, import_react.useState)(null);
	const inputRef = (0, import_react.useRef)(null);
	const addUrl = (raw) => {
		const v = raw.trim();
		if (!v) return;
		if (!isProbablyUrl(v)) {
			toast.error("رابط صورة غير صالح");
			return;
		}
		if (value.includes(v)) {
			toast.info("الصورة موجودة بالفعل");
			return;
		}
		onChange([...value, v]);
		setUrlDraft("");
	};
	const addFromPaste = (text) => {
		text.split(/[\n\s,]+/).map((s) => s.trim()).filter(isProbablyUrl).forEach((u) => !value.includes(u) && onChange([...value, u]));
	};
	const remove = (i) => onChange(value.filter((_, idx) => idx !== i));
	const move = (from, to) => {
		if (to < 0 || to >= value.length) return;
		const next = value.slice();
		const [item] = next.splice(from, 1);
		next.splice(to, 0, item);
		onChange(next);
	};
	const setFeatured = (i) => move(i, 0);
	const onDragStart = (i) => setDragIndex(i);
	const onDragOver = (e) => e.preventDefault();
	const onDrop = (e, i) => {
		e.preventDefault();
		if (dragIndex === null || dragIndex === i) return;
		move(dragIndex, i);
		setDragIndex(null);
	};
	const onFileDrop = async (e) => {
		e.preventDefault();
		const items = e.dataTransfer?.items;
		if (!items) return;
		const urls = [];
		for (const item of items) {
			if (item.kind === "string" && item.type === "text/uri-list") await new Promise((res) => item.getAsString((s) => {
				if (isProbablyUrl(s) && !value.includes(s)) urls.push(s);
				res();
			}));
			if (item.kind === "string" && item.type === "text/plain") await new Promise((res) => item.getAsString((s) => {
				s.split(/[\n\s,]+/).forEach((u) => {
					if (isProbablyUrl(u) && !value.includes(u)) urls.push(u);
				});
				res();
			}));
		}
		if (urls.length) {
			onChange([...value, ...urls]);
			toast.success(`تمت إضافة ${urls.length} صورة`);
		} else if (Array.from(e.dataTransfer.files ?? []).some((f) => f.type.startsWith("image/"))) toast.error("رفع الملفات يحتاج إلى تفعيل التخزين. الصق رابط الصورة بدلاً من ذلك.");
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "space-y-4",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				onDragOver: (e) => e.preventDefault(),
				onDrop: onFileDrop,
				className: "rounded-xl border-2 border-dashed border-border p-4 text-center",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ImagePlus, { className: "mx-auto h-6 w-6 text-muted-foreground" }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "mt-1 text-xs font-bold text-muted-foreground",
						children: "اسحب رابط صورة هنا، أو ألصق روابط متعددة"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-3 flex flex-wrap items-center gap-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "relative flex-1 min-w-[200px]",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link$1, { className: "absolute start-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
								ref: inputRef,
								value: urlDraft,
								onChange: (e) => setUrlDraft(e.target.value),
								onKeyDown: (e) => {
									if (e.key === "Enter") {
										e.preventDefault();
										addUrl(urlDraft);
									}
								},
								onPaste: (e) => {
									const text = e.clipboardData.getData("text");
									if (text.includes("\n") || text.split(/\s+/).length > 1) {
										e.preventDefault();
										addFromPaste(text);
									}
								},
								placeholder: "https://...",
								className: "w-full rounded-lg border border-border bg-surface py-2 ps-9 pe-3 text-xs outline-none focus:border-primary"
							})]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
							type: "button",
							onClick: () => addUrl(urlDraft),
							className: "rounded-lg bg-primary px-3 py-2 text-xs font-bold text-primary-foreground",
							children: "إضافة"
						})]
					})
				]
			}),
			value.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "rounded-xl bg-surface p-4 text-center text-xs text-muted-foreground",
				children: "لا توجد صور بعد. أضف روابط للصور لعرضها في المتجر."
			}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
				className: "grid grid-cols-2 gap-3 sm:grid-cols-3",
				children: value.map((src, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
					draggable: true,
					onDragStart: () => onDragStart(i),
					onDragOver,
					onDrop: (e) => onDrop(e, i),
					className: `group relative overflow-hidden rounded-xl border border-border bg-surface ${dragIndex === i ? "opacity-50" : ""}`,
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "aspect-square bg-muted",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
								src,
								alt: "",
								className: "h-full w-full object-cover",
								loading: "lazy",
								onError: (e) => {
									e.currentTarget.style.opacity = "0.3";
								}
							})
						}),
						i === 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
							className: "absolute start-2 top-2 inline-flex items-center gap-1 rounded-full bg-warning/90 px-2 py-0.5 text-[10px] font-black text-warning-foreground",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Star, { className: "h-3 w-3" }), " رئيسية"]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "absolute inset-x-0 bottom-0 flex items-center justify-between gap-1 bg-gradient-to-t from-black/70 to-transparent p-2 opacity-0 transition group-hover:opacity-100",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "flex gap-1",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
										type: "button",
										onClick: () => move(i, i - 1),
										disabled: i === 0,
										className: "grid h-7 w-7 place-items-center rounded-md bg-black/50 text-white disabled:opacity-30",
										"aria-label": "تحريك للأعلى",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ArrowUp, { className: "h-3.5 w-3.5" })
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
										type: "button",
										onClick: () => move(i, i + 1),
										disabled: i === value.length - 1,
										className: "grid h-7 w-7 place-items-center rounded-md bg-black/50 text-white disabled:opacity-30",
										"aria-label": "تحريك للأسفل",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ArrowDown, { className: "h-3.5 w-3.5" })
									}),
									i !== 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
										type: "button",
										onClick: () => setFeatured(i),
										className: "grid h-7 w-7 place-items-center rounded-md bg-black/50 text-white",
										"aria-label": "تعيين كصورة رئيسية",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Star, { className: "h-3.5 w-3.5" })
									})
								]
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								type: "button",
								onClick: () => remove(i),
								className: "grid h-7 w-7 place-items-center rounded-md bg-destructive/90 text-destructive-foreground",
								"aria-label": "حذف",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "h-3.5 w-3.5" })
							})]
						})
					]
				}, `${src}-${i}`))
			}),
			value.length > 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
				className: "text-[11px] text-muted-foreground",
				children: [value.length, " صورة · الصورة الأولى هي الصورة الرئيسية"]
			})
		]
	});
}
function GooglePreview({ slug, title, description, origin }) {
	const url = `${origin ?? (typeof window !== "undefined" ? window.location.origin : "https://example.com")}/product/${slug || "product-slug"}`;
	const displayTitle = (title || "Product title").slice(0, 60);
	const displayDesc = (description || "Product description shown in search results.").slice(0, 160);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "rounded-xl border border-border bg-white p-4 text-black shadow-sm",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex items-center gap-2 text-xs text-[#5f6368]",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "h-3.5 w-3.5" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "truncate",
					children: url
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "mt-1 truncate text-lg font-medium text-[#1a0dab]",
				children: displayTitle
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "mt-1 line-clamp-2 text-sm text-[#4d5156]",
				children: displayDesc
			})
		]
	});
}
async function callAnalyze(hint, images) {
	const res = await fetch("/api/ai/analyze-product", {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify({
			hint,
			language: "ar",
			images: images.slice(0, 6)
		})
	});
	if (!res.ok) {
		const err = await res.json().catch(() => ({}));
		throw new Error(err?.error || `AI error (${res.status})`);
	}
	return res.json();
}
var ACTIONS = [
	{
		key: "title",
		label: "توليد اسم",
		description: "اسم منتج جذاب من الصور",
		needsImages: true
	},
	{
		key: "improveTitle",
		label: "تحسين الاسم",
		description: "إعادة صياغة الاسم الحالي",
		needsText: true
	},
	{
		key: "description",
		label: "توليد وصف",
		description: "وصف تسويقي كامل"
	},
	{
		key: "improveDescription",
		label: "تحسين الوصف",
		description: "تنقيح الوصف الحالي",
		needsText: true
	},
	{
		key: "tags",
		label: "توليد وسوم",
		description: "كلمات مفتاحية للبحث"
	},
	{
		key: "seoTitle",
		label: "عنوان SEO",
		description: "عنوان محرك بحث محسّن"
	},
	{
		key: "seoDescription",
		label: "وصف SEO",
		description: "وصف Meta للمتاجر"
	},
	{
		key: "category",
		label: "اقتراح تصنيف",
		description: "أنسب تصنيف من الصور"
	},
	{
		key: "brand",
		label: "اقتراح ماركة",
		description: "استخراج الماركة من الصور",
		needsImages: true
	},
	{
		key: "price",
		label: "اقتراح سعر",
		description: "سعر بيع تقديري"
	},
	{
		key: "features",
		label: "استخراج مزايا",
		description: "قائمة مزايا رئيسية"
	},
	{
		key: "highlights",
		label: "نقاط تسويقية",
		description: "3 نقاط بيع قوية"
	},
	{
		key: "specs",
		label: "المواصفات",
		description: "مواصفات تقنية منظمة"
	}
];
function buildHint(action, ctx) {
	const parts = [];
	if (ctx.name) parts.push(`الاسم الحالي: ${ctx.name}`);
	if (ctx.brand) parts.push(`الماركة: ${ctx.brand}`);
	if (ctx.description) parts.push(`الوصف الحالي: ${ctx.description.slice(0, 400)}`);
	switch (action) {
		case "improveTitle":
			parts.push("المطلوب: إعادة صياغة الاسم ليكون أكثر جاذبية وقصر (< 60 حرف).");
			break;
		case "improveDescription":
			parts.push("المطلوب: تحسين الوصف الحالي مع إبراز الفوائد.");
			break;
		case "features":
			parts.push("المطلوب: استخراج 4-6 مزايا رئيسية على شكل نقاط.");
			break;
		case "highlights":
			parts.push("المطلوب: 3 نقاط بيع قوية للتسويق.");
			break;
		case "specs":
			parts.push("المطلوب: مواصفات تقنية بصيغة قائمة (المفتاح: القيمة).");
			break;
		default: break;
	}
	return parts.join("\n");
}
function extractValue(action, data, ctx) {
	switch (action) {
		case "title":
		case "improveTitle": return data.title;
		case "description":
		case "improveDescription": return data.description;
		case "features":
		case "highlights":
		case "specs": return data.description;
		case "tags": return data.tags;
		case "seoTitle": return data.seoTitle;
		case "seoDescription": return data.seoDescription;
		case "category": return data.category;
		case "brand": return data.tags[0] ?? ctx.brand ?? "";
		case "price":
			data.priceEstimate?.currency || ctx.currency;
			return Math.round(((data.priceEstimate?.min ?? 0) + (data.priceEstimate?.max ?? 0)) / 2) || 0;
		default: return "";
	}
}
function AiAssistantPanel({ context, onApply }) {
	const [busy, setBusy] = (0, import_react.useState)(null);
	const [done, setDone] = (0, import_react.useState)({});
	const run = async (action) => {
		const meta = ACTIONS.find((a) => a.key === action);
		if (meta.needsImages && context.images.length === 0) {
			toast.error("أضف صورة واحدة على الأقل أولاً");
			return;
		}
		if (meta.needsText && !context.name.trim()) {
			toast.error("أدخل اسم المنتج أولاً");
			return;
		}
		setBusy(action);
		try {
			onApply(action, extractValue(action, await callAnalyze(buildHint(action, context), context.images), context));
			setDone((d) => ({
				...d,
				[action]: Date.now()
			}));
			toast.success(`تم: ${meta.label}`);
		} catch (e) {
			const msg = e instanceof Error ? e.message : "خطأ";
			toast.error(`${meta.label}: ${msg}`);
		} finally {
			setBusy(null);
		}
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "space-y-3",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "rounded-xl bg-gradient-to-br from-primary/10 to-fuchsia-500/10 p-3",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex items-center gap-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "h-4 w-4 text-primary" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "text-xs font-bold",
						children: "المساعد الذكي يولّد المحتوى من الصور والاسم الحالي"
					})]
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "grid grid-cols-1 gap-2 sm:grid-cols-2",
				children: ACTIONS.map((a) => {
					const isBusy = busy === a.key;
					const wasDone = done[a.key];
					return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						onClick: () => run(a.key),
						disabled: busy !== null,
						className: "group relative flex items-start gap-3 rounded-xl border border-border bg-surface p-3 text-start transition hover:border-primary hover:bg-primary/5 disabled:cursor-not-allowed disabled:opacity-50",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary",
								children: isBusy ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-4 w-4 animate-spin" }) : wasDone ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "h-4 w-4 text-success" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "h-4 w-4" })
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
								className: "min-w-0 flex-1",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "block text-xs font-black",
									children: a.label
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "block truncate text-[11px] text-muted-foreground",
									children: a.description
								})]
							}),
							wasDone && !isBusy && /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RefreshCw, { className: "h-3 w-3 shrink-0 text-muted-foreground opacity-0 transition group-hover:opacity-100" })
						]
					}, a.key);
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "text-[11px] text-muted-foreground",
				children: "كل إجراء يعمل بشكل مستقل. تكلفة صغيرة لكل تنفيذ."
			})
		]
	});
}
var emptyForm = {
	slug: "",
	name: "",
	description: "",
	price: 0,
	old_price: null,
	currency: "YER",
	category_id: "",
	brand: "",
	images: [],
	model_url: "",
	stock: 0,
	tags: [],
	badge: "",
	is_published: true
};
var slugify = (s) => s.toLowerCase().trim().replace(/[^\p{L}\p{N}\s-]/gu, "").replace(/\s+/g, "-").replace(/-+/g, "-").replace(/^-+|-+$/g, "").slice(0, 80);
var NAME_MAX = 120;
var DESC_MAX = 4e3;
var SEO_TITLE_MAX = 60;
var SEO_DESC_MAX = 160;
var TAG_SUGGESTIONS = [
	"جديد",
	"عرض",
	"الأكثر مبيعاً",
	"حصري",
	"توصيل مجاني"
];
function ProductDetailPage() {
	const { id } = Route.useParams();
	const { t, dir } = useI18n();
	const qc = useQueryClient();
	const navigate = useNavigate();
	const isNew = id === "new";
	const productQ = useQuery({
		queryKey: ["admin-product", id],
		queryFn: () => getAdminProduct(id),
		enabled: !isNew
	});
	const categoriesQ = useQuery({
		queryKey: ["admin-categories"],
		queryFn: () => listAdminCategories()
	});
	const [form, setForm] = (0, import_react.useState)(emptyForm);
	const [initial, setInitial] = (0, import_react.useState)(emptyForm);
	const [slugTouched, setSlugTouched] = (0, import_react.useState)(false);
	const [categorySearch, setCategorySearch] = (0, import_react.useState)("");
	(0, import_react.useEffect)(() => {
		if (isNew || !productQ.data) return;
		const p = productQ.data;
		const next = {
			slug: p.slug,
			name: p.name,
			description: p.description ?? "",
			price: Number(p.price),
			old_price: null,
			currency: p.currency,
			category_id: p.category_id ?? "",
			brand: p.brand ?? "",
			images: p.images ?? [],
			model_url: p.model_url ?? "",
			stock: p.stock,
			tags: p.tags ?? [],
			badge: "",
			is_published: p.is_published
		};
		setForm(next);
		setInitial(next);
		setSlugTouched(true);
	}, [productQ.data, isNew]);
	(0, import_react.useEffect)(() => {
		if (slugTouched) return;
		if (!form.name) return;
		setForm((f) => ({
			...f,
			slug: slugify(f.name)
		}));
	}, [form.name, slugTouched]);
	const dirty = (0, import_react.useMemo)(() => JSON.stringify(form) !== JSON.stringify(initial), [form, initial]);
	(0, import_react.useEffect)(() => {
		if (!dirty) return;
		const handler = (e) => {
			e.preventDefault();
			e.returnValue = "";
		};
		window.addEventListener("beforeunload", handler);
		return () => window.removeEventListener("beforeunload", handler);
	}, [dirty]);
	const buildPayload = (0, import_react.useCallback)(() => ({
		slug: form.slug.trim(),
		name: form.name.trim(),
		description: form.description,
		price: Number(form.price),
		old_price: form.old_price != null && form.old_price > 0 ? Number(form.old_price) : null,
		currency: form.currency,
		category_id: form.category_id || void 0,
		brand: form.brand || void 0,
		images: form.images.filter(Boolean),
		model_url: form.model_url || void 0,
		stock: Number(form.stock),
		tags: form.tags.filter(Boolean),
		is_published: form.is_published
	}), [form]);
	const validate = () => {
		if (!form.name.trim()) return "اسم المنتج مطلوب";
		if (!form.slug.trim()) return "الرابط (slug) مطلوب";
		if (!/^[a-z0-9-]+$/i.test(form.slug)) return "الرابط يجب أن يحوي أحرف وأرقام و - فقط";
		if (!(form.price >= 0)) return "السعر غير صالح";
		return null;
	};
	const saveMut = useMutation({
		mutationFn: async () => {
			const err = validate();
			if (err) throw new Error(err);
			const payload = buildPayload();
			if (isNew) return createAdminProduct(payload);
			return updateAdminProduct({
				id,
				...payload
			});
		},
		onSuccess: (res) => {
			toast.success(isNew ? "تم إنشاء المنتج" : "تم حفظ التغييرات");
			qc.invalidateQueries({ queryKey: ["admin-products"] });
			qc.invalidateQueries({ queryKey: ["admin-product", id] });
			if (isNew && res && "id" in res) navigate({
				to: "/admin/product/$id",
				params: { id: res.id },
				replace: true
			});
			else setInitial(form);
		},
		onError: (e) => toast.error(e.message)
	});
	const deleteMut = useMutation({
		mutationFn: () => deleteAdminProduct(id),
		onSuccess: () => {
			toast.success("تم الحذف");
			qc.invalidateQueries({ queryKey: ["admin-products"] });
			navigate({
				to: "/admin/products",
				replace: true
			});
		},
		onError: (e) => toast.error(e.message)
	});
	(0, import_react.useEffect)(() => {
		const handler = (e) => {
			if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") {
				e.preventDefault();
				if (!saveMut.isPending && dirty) saveMut.mutate();
			}
		};
		window.addEventListener("keydown", handler);
		return () => window.removeEventListener("keydown", handler);
	}, [saveMut, dirty]);
	const autosaveTimer = (0, import_react.useRef)(null);
	(0, import_react.useEffect)(() => {
		if (isNew || !dirty || saveMut.isPending) return;
		if (validate() !== null) return;
		if (autosaveTimer.current) clearTimeout(autosaveTimer.current);
		autosaveTimer.current = setTimeout(() => {
			saveMut.mutate();
		}, 3500);
		return () => {
			if (autosaveTimer.current) clearTimeout(autosaveTimer.current);
		};
	}, [
		form,
		dirty,
		isNew
	]);
	if (!isNew && productQ.isLoading) return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProductSkeleton, {});
	if (!isNew && productQ.isError) return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "rounded-2xl glass p-12 text-center",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
			className: "text-sm text-destructive",
			children: "تعذّر تحميل المنتج"
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
			to: "/admin/products",
			className: "mt-4 inline-flex text-sm font-bold text-primary",
			children: ["← ", t("nav.products")]
		})]
	});
	if (!isNew && !productQ.data) return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "rounded-2xl glass p-12 text-center",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
			className: "text-sm text-muted-foreground",
			children: "المنتج غير موجود"
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
			to: "/admin/products",
			className: "mt-4 inline-flex text-sm font-bold text-primary",
			children: ["← ", t("nav.products")]
		})]
	});
	const categories = categoriesQ.data ?? [];
	const filteredCategories = categorySearch ? categories.filter((c) => c.name.toLowerCase().includes(categorySearch.toLowerCase())) : categories;
	const discountPct = form.old_price && form.old_price > 0 && form.price < form.old_price ? Math.round((1 - form.price / form.old_price) * 100) : 0;
	const updatedAt = productQ.data?.updated_at;
	const applyAi = (action, value) => {
		setForm((f) => {
			switch (action) {
				case "title":
				case "improveTitle": return {
					...f,
					name: String(value)
				};
				case "description":
				case "improveDescription":
				case "features":
				case "highlights":
				case "specs": return {
					...f,
					description: String(value)
				};
				case "tags": return {
					...f,
					tags: Array.isArray(value) ? value : f.tags
				};
				case "seoTitle":
				case "seoDescription":
					toast.info("SEO: يتم توليد المحتوى فقط (لا يوجد حقل SEO منفصل بعد)");
					return f;
				case "category": {
					const name = String(value);
					const match = categories.find((c) => c.name.toLowerCase() === name.toLowerCase());
					if (match) return {
						...f,
						category_id: match.id
					};
					toast.info(`اقتراح التصنيف: ${name}`);
					return f;
				}
				case "brand": return {
					...f,
					brand: String(value)
				};
				case "price": return {
					...f,
					price: Number(value) || f.price
				};
				default: return f;
			}
		});
	};
	const copyPublicUrl = async () => {
		const url = `${window.location.origin}/product/${form.slug}`;
		try {
			await navigator.clipboard.writeText(url);
			toast.success("تم نسخ الرابط");
		} catch {
			toast.error("تعذّر النسخ");
		}
	};
	const duplicateProduct = () => {
		if (isNew) return;
		createAdminProduct({
			...buildPayload(),
			slug: `${form.slug}-copy`,
			is_published: false
		}).then((res) => {
			toast.success("تم إنشاء نسخة");
			if (res && "id" in res) navigate({
				to: "/admin/product/$id",
				params: { id: res.id }
			});
		}).catch((e) => toast.error(e.message));
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "space-y-6 pb-32",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex min-w-0 items-center gap-3",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/admin/products",
						className: "grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-border hover:border-primary",
						"aria-label": t("common.back"),
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ArrowLeft, { className: `h-4 w-4 ${dir === "rtl" ? "rotate-180" : ""}` })
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "min-w-0",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
							className: "truncate text-lg font-black sm:text-xl",
							children: isNew ? "منتج جديد" : form.name || "بدون اسم"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground",
							children: [dirty ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
								className: "inline-flex items-center gap-1 text-warning",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "h-1.5 w-1.5 rounded-full bg-warning" }), "تغييرات غير محفوظة"]
							}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
								className: "inline-flex items-center gap-1 text-success",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "h-1.5 w-1.5 rounded-full bg-success" }), "محفوظ"]
							}), updatedAt && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
								className: "inline-flex items-center gap-1",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Clock, { className: "h-3 w-3" }), new Date(updatedAt).toLocaleString("ar")]
							})]
						})]
					})]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "hidden gap-2 sm:flex",
					children: !isNew && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						onClick: copyPublicUrl,
						className: "inline-flex items-center gap-2 rounded-xl border border-border px-3 py-2 text-xs font-bold hover:border-primary",
						title: "نسخ رابط المنتج",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Copy, { className: "h-3.5 w-3.5" }), " نسخ الرابط"]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						onClick: duplicateProduct,
						className: "inline-flex items-center gap-2 rounded-xl border border-border px-3 py-2 text-xs font-bold hover:border-primary",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Layers, { className: "h-3.5 w-3.5" }), " نسخ المنتج"]
					})] })
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "grid gap-6 lg:grid-cols-5",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "space-y-4 lg:col-span-3",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "info",
							title: "معلومات المنتج",
							subtitle: "الاسم والوصف والرابط",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Info, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-4",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
										label: "اسم المنتج",
										required: true,
										counter: `${form.name.length}/${NAME_MAX}`,
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
											value: form.name,
											onChange: (e) => setForm({
												...form,
												name: e.target.value.slice(0, NAME_MAX)
											}),
											placeholder: "مثال: سماعات لاسلكية عالية الجودة",
											className: inputCls,
											"aria-required": "true"
										})
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(FormField, {
										label: "الرابط (Slug)",
										hint: "يُستخدم في URL المنتج",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
											className: "flex gap-2",
											children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
												value: form.slug,
												onChange: (e) => {
													setSlugTouched(true);
													setForm({
														...form,
														slug: e.target.value
													});
												},
												className: `${inputCls} font-mono`,
												dir: "ltr"
											}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
												type: "button",
												onClick: () => {
													setSlugTouched(true);
													setForm({
														...form,
														slug: slugify(form.name)
													});
												},
												className: "shrink-0 rounded-xl border border-border px-3 text-xs font-bold hover:border-primary",
												title: "إعادة توليد من الاسم",
												children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(WandSparkles, { className: "h-3.5 w-3.5" })
											})]
										}), form.slug && !/^[a-z0-9-]+$/i.test(form.slug) && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
											className: "mt-1 text-[11px] text-destructive",
											children: "الأحرف المسموحة: a-z, 0-9, -"
										})]
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
										label: "الوصف",
										counter: `${form.description.length}/${DESC_MAX}`,
										hint: "يدعم Markdown (**bold**, - list)",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("textarea", {
											value: form.description,
											onChange: (e) => setForm({
												...form,
												description: e.target.value.slice(0, DESC_MAX)
											}),
											rows: 6,
											placeholder: "اكتب وصفاً واضحاً يبرز مزايا المنتج...",
											className: inputCls
										})
									})
								]
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "media",
							title: "الصور والوسائط",
							subtitle: `${form.images.length} صورة`,
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Image, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ImageManager, {
								value: form.images,
								onChange: (next) => setForm({
									...form,
									images: next
								})
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "pricing",
							title: "التسعير",
							subtitle: "السعر ونسبة الخصم",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(DollarSign, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-4",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "grid grid-cols-2 gap-3 sm:grid-cols-3",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
											label: "سعر البيع",
											required: true,
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
												type: "number",
												step: "0.01",
												min: "0",
												value: form.price,
												onChange: (e) => setForm({
													...form,
													price: Number(e.target.value)
												}),
												className: inputCls,
												dir: "ltr"
											})
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
											label: "السعر قبل الخصم",
											hint: "اختياري",
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
												type: "number",
												step: "0.01",
												min: "0",
												value: form.old_price ?? "",
												onChange: (e) => setForm({
													...form,
													old_price: e.target.value ? Number(e.target.value) : null
												}),
												className: inputCls,
												dir: "ltr"
											})
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
											label: "العملة",
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
												value: form.currency,
												onChange: (e) => setForm({
													...form,
													currency: e.target.value
												}),
												className: inputCls,
												dir: "ltr"
											})
										})
									]
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "grid grid-cols-2 gap-3 rounded-xl bg-surface p-3 text-xs sm:grid-cols-4",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
											label: "السعر",
											value: `${form.price} ${form.currency}`
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
											label: "قبل الخصم",
											value: form.old_price ? `${form.old_price} ${form.currency}` : "—"
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
											label: "التوفير",
											value: form.old_price && form.old_price > form.price ? `${(form.old_price - form.price).toFixed(2)} ${form.currency}` : "—"
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
											label: "نسبة الخصم",
											value: discountPct ? `${discountPct}%` : "—",
											highlight: discountPct > 0
										})
									]
								})]
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "inventory",
							title: "المخزون",
							subtitle: `${form.stock} وحدة متوفرة`,
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Boxes, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-3",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
										label: "الكمية المتوفرة",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
											type: "number",
											min: "0",
											value: form.stock,
											onChange: (e) => setForm({
												...form,
												stock: Number(e.target.value)
											}),
											className: inputCls,
											dir: "ltr"
										})
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "grid grid-cols-3 gap-2 rounded-xl bg-surface p-3 text-xs",
										children: [
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
												label: "الحالة",
												value: form.stock > 0 ? "متوفر" : "نفد",
												highlight: form.stock > 0,
												danger: form.stock === 0
											}),
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
												label: "المخزون",
												value: String(form.stock)
											}),
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Stat, {
												label: "المحجوز",
												value: String(productQ.data?.reserved_stock ?? 0)
											})
										]
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
										className: "text-[11px] text-muted-foreground",
										children: "استخدم لوحة \"إدارة المخزون\" على اليمين لتسجيل حركات دقيقة (إضافة/سحب/تلف)."
									})
								]
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "cat",
							title: "التصنيف والماركة",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Tag, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-3",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(FormField, {
									label: "التصنيف",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "relative",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "absolute start-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
											value: categorySearch,
											onChange: (e) => setCategorySearch(e.target.value),
											placeholder: "ابحث في التصنيفات...",
											className: `${inputCls} ps-9`
										})]
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "mt-2 max-h-56 overflow-y-auto rounded-xl border border-border bg-surface",
										children: [
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
												type: "button",
												onClick: () => setForm({
													...form,
													category_id: ""
												}),
												className: `w-full px-3 py-2 text-start text-xs ${!form.category_id ? "bg-primary/10 font-bold text-primary" : "hover:bg-muted"}`,
												children: "— بدون تصنيف —"
											}),
											filteredCategories.map((c) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
												type: "button",
												onClick: () => setForm({
													...form,
													category_id: c.id
												}),
												className: `flex w-full items-center justify-between px-3 py-2 text-start text-xs ${form.category_id === c.id ? "bg-primary/10 font-bold text-primary" : "hover:bg-muted"}`,
												children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: c.name }), c.parent_id && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
													className: "text-[10px] text-muted-foreground",
													children: "فرعي"
												})]
											}, c.id)),
											filteredCategories.length === 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
												className: "p-3 text-center text-xs text-muted-foreground",
												children: "لا نتائج"
											})
										]
									})]
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
									label: "الماركة",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
										value: form.brand,
										onChange: (e) => setForm({
											...form,
											brand: e.target.value
										}),
										className: inputCls,
										placeholder: "مثال: Sony"
									})
								})]
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "tags",
							title: "الوسوم",
							subtitle: "كلمات مفتاحية للبحث",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Tag, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ChipInput, {
								value: form.tags,
								onChange: (tags) => setForm({
									...form,
									tags
								}),
								suggestions: TAG_SUGGESTIONS,
								placeholder: "أضف وسم ثم Enter",
								ariaLabel: "وسوم المنتج"
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "seo",
							title: "تحسين محركات البحث",
							subtitle: "معاينة نتيجة Google",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "h-4 w-4" }),
							defaultOpen: false,
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-4",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "grid grid-cols-2 gap-3 text-[11px]",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "rounded-lg bg-surface p-2",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "text-muted-foreground",
											children: "عنوان SEO: "
										}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
											className: form.name.length > SEO_TITLE_MAX ? "text-destructive" : "",
											children: [
												form.name.length,
												"/",
												SEO_TITLE_MAX
											]
										})]
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "rounded-lg bg-surface p-2",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "text-muted-foreground",
											children: "وصف SEO: "
										}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
											className: form.description.length > SEO_DESC_MAX ? "text-destructive" : "",
											children: [
												form.description.length,
												"/",
												SEO_DESC_MAX
											]
										})]
									})]
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "mb-2 text-xs font-bold text-muted-foreground",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Eye, { className: "me-1 inline h-3 w-3" }), " معاينة نتيجة البحث"]
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(GooglePreview, {
									slug: form.slug,
									title: form.name,
									description: form.description
								})] })]
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "publish",
							title: "النشر والحالة",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Eye, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-3",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "grid grid-cols-2 gap-2",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
											type: "button",
											onClick: () => setForm({
												...form,
												is_published: true
											}),
											className: `rounded-xl border p-3 text-start ${form.is_published ? "border-success bg-success/10" : "border-border bg-surface"}`,
											children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "block text-xs font-black",
												children: "منشور"
											}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "block text-[11px] text-muted-foreground",
												children: "ظاهر في المتجر"
											})]
										}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
											type: "button",
											onClick: () => setForm({
												...form,
												is_published: false
											}),
											className: `rounded-xl border p-3 text-start ${!form.is_published ? "border-warning bg-warning/10" : "border-border bg-surface"}`,
											children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "block text-xs font-black",
												children: "مسودة"
											}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "block text-[11px] text-muted-foreground",
												children: "غير ظاهر للعملاء"
											})]
										})]
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)(FormField, {
										label: "شارة (اختياري)",
										hint: "مثال: جديد، عرض",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
											value: form.badge,
											onChange: (e) => setForm({
												...form,
												badge: e.target.value
											}),
											className: inputCls
										})
									}),
									updatedAt && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
										className: "text-[11px] text-muted-foreground",
										children: ["آخر تعديل: ", new Date(updatedAt).toLocaleString("ar")]
									})
								]
							})
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "space-y-4 lg:col-span-2",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "ai",
							title: "المساعد الذكي",
							subtitle: "توليد المحتوى بالذكاء الاصطناعي",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(AiAssistantPanel, {
								context: {
									name: form.name,
									description: form.description,
									images: form.images,
									brand: form.brand,
									price: form.price,
									currency: form.currency
								},
								onApply: applyAi
							})
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CollapsibleCard, {
							id: "model3d",
							title: "نموذج 3D",
							subtitle: "مولّد من الصور",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Package, { className: "h-4 w-4" }),
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Ai3dGeneratorPanel, {
								images: form.images,
								currentModelUrl: form.model_url || void 0,
								onGenerated: (url) => setForm((f) => ({
									...f,
									model_url: url
								}))
							}), form.model_url && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-3 flex flex-wrap gap-2",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
									href: form.model_url,
									target: "_blank",
									rel: "noreferrer",
									className: "rounded-lg border border-border px-3 py-1.5 text-[11px] font-bold hover:border-primary",
									children: "فتح الملف"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
									type: "button",
									onClick: () => setForm((f) => ({
										...f,
										model_url: ""
									})),
									className: "rounded-lg bg-destructive/10 px-3 py-1.5 text-[11px] font-bold text-destructive",
									children: "حذف النموذج"
								})]
							})]
						}),
						!isNew && /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CollapsibleCard, {
							id: "inv-manage",
							title: "إدارة المخزون",
							subtitle: "تسجيل الحركات",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Boxes, { className: "h-4 w-4" }),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(InventoryPanel, {
								productId: id,
								onChanged: () => qc.invalidateQueries({ queryKey: ["admin-product", id] })
							})
						})
					]
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "fixed inset-x-0 bottom-0 z-40 border-t border-border/60 bg-background/95 backdrop-blur",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mx-auto flex max-w-7xl items-center justify-between gap-3 px-4 py-3",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "min-w-0 text-xs text-muted-foreground",
						children: saveMut.isPending ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
							className: "inline-flex items-center gap-1",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-3 w-3 animate-spin" }), " جاري الحفظ..."]
						}) : dirty ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "تغييرات غير محفوظة · Ctrl+S للحفظ" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "لا تغييرات" })
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "flex items-center gap-2",
						children: [!isNew && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
							type: "button",
							onClick: () => {
								if (confirm(`حذف "${form.name}"؟`)) deleteMut.mutate();
							},
							disabled: deleteMut.isPending,
							className: "inline-flex items-center gap-2 rounded-xl bg-destructive/10 px-3 py-2 text-xs font-bold text-destructive hover:bg-destructive/20 sm:px-4 sm:text-sm",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "h-4 w-4" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "hidden sm:inline",
								children: "حذف"
							})]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
							type: "button",
							onClick: () => saveMut.mutate(),
							disabled: saveMut.isPending || !dirty && !isNew,
							className: "inline-flex items-center gap-2 rounded-xl gradient-brand px-4 py-2 text-sm font-bold text-primary-foreground shadow-brand disabled:opacity-60",
							children: [saveMut.isPending ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-4 w-4 animate-spin" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Save, { className: "h-4 w-4" }), isNew ? "إنشاء المنتج" : "حفظ"]
						})]
					})]
				})
			})
		]
	});
}
var inputCls = "w-full rounded-xl border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-primary transition";
function FormField({ label, children, required, counter, hint }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("label", {
		className: "block",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
				className: "flex items-center justify-between gap-2",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
					className: "text-xs font-bold text-muted-foreground",
					children: [label, required && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
						className: "text-destructive",
						children: " *"
					})]
				}), counter && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-[10px] text-muted-foreground",
					children: counter
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "mt-1",
				children
			}),
			hint && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "mt-1 block text-[11px] text-muted-foreground",
				children: hint
			})
		]
	});
}
function Stat({ label, value, highlight, danger }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
		className: "text-[10px] text-muted-foreground",
		children: label
	}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
		className: `font-black ${danger ? "text-destructive" : highlight ? "text-success" : "text-foreground"}`,
		children: value
	})] });
}
function ProductSkeleton() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "space-y-4",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-8 w-1/3 animate-pulse rounded-lg bg-muted" }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "grid gap-4 lg:grid-cols-5",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "space-y-4 lg:col-span-3",
				children: [
					1,
					2,
					3,
					4
				].map((i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-40 animate-pulse rounded-2xl bg-muted/50" }, i))
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "space-y-4 lg:col-span-2",
				children: [1, 2].map((i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-64 animate-pulse rounded-2xl bg-muted/50" }, i))
			})]
		})]
	});
}
function InventoryPanel({ productId, onChanged }) {
	const qc = useQueryClient();
	const [delta, setDelta] = (0, import_react.useState)(1);
	const [reason, setReason] = (0, import_react.useState)("restock");
	const [note, setNote] = (0, import_react.useState)("");
	const movementsQ = useQuery({
		queryKey: ["inventory-movements", productId],
		queryFn: () => listInventoryMovements(productId)
	});
	const recordMut = useMutation({
		mutationFn: (signedDelta) => recordInventoryMovement({
			product_id: productId,
			delta: signedDelta,
			reason,
			note: note || null
		}),
		onSuccess: () => {
			toast.success("تم تعديل المخزون");
			setNote("");
			qc.invalidateQueries({ queryKey: ["inventory-movements", productId] });
			onChanged();
		},
		onError: (e) => toast.error(e.message)
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "space-y-3",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex items-center gap-2",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
						type: "button",
						onClick: () => setDelta(Math.max(1, delta - 1)),
						className: "grid h-9 w-9 place-items-center rounded-lg border border-border",
						"aria-label": "إنقاص",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Minus, { className: "h-4 w-4" })
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
						type: "number",
						min: 1,
						value: delta,
						onChange: (e) => setDelta(Math.max(1, Number(e.target.value))),
						className: "flex-1 rounded-lg border border-border bg-surface px-3 py-2 text-center text-sm"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
						type: "button",
						onClick: () => setDelta(delta + 1),
						className: "grid h-9 w-9 place-items-center rounded-lg border border-border",
						"aria-label": "زيادة",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "h-4 w-4" })
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("select", {
				value: reason,
				onChange: (e) => setReason(e.target.value),
				className: inputCls,
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
						value: "restock",
						children: "إضافة مخزون"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
						value: "adjustment",
						children: "تسوية"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
						value: "damage",
						children: "تلف"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
						value: "return",
						children: "مرتجع"
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
				value: note,
				onChange: (e) => setNote(e.target.value),
				placeholder: "ملاحظة (اختياري)",
				className: inputCls
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "grid grid-cols-2 gap-2",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
					type: "button",
					onClick: () => recordMut.mutate(delta),
					disabled: recordMut.isPending,
					className: "inline-flex items-center justify-center gap-1 rounded-lg bg-success py-2 text-xs font-bold text-success-foreground disabled:opacity-60",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "h-3.5 w-3.5" }),
						" إضافة ",
						delta
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
					type: "button",
					onClick: () => {
						if (confirm(`سحب ${delta} من المخزون؟`)) recordMut.mutate(-Math.abs(delta));
					},
					disabled: recordMut.isPending,
					className: "inline-flex items-center justify-center gap-1 rounded-lg bg-destructive/10 py-2 text-xs font-bold text-destructive disabled:opacity-60",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Minus, { className: "h-3.5 w-3.5" }),
						" سحب ",
						delta
					]
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
				className: "mb-2 text-xs font-bold text-muted-foreground",
				children: "آخر الحركات"
			}), movementsQ.isLoading ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-4 w-4 animate-spin text-muted-foreground" }) : (movementsQ.data ?? []).length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "text-xs text-muted-foreground",
				children: "لا توجد حركات"
			}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
				className: "space-y-1.5 text-xs",
				children: (movementsQ.data ?? []).slice(0, 10).map((m) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
					className: "flex items-center justify-between rounded-lg bg-surface px-3 py-2",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
							className: `font-bold ${m.delta > 0 ? "text-success" : "text-destructive"}`,
							children: [m.delta > 0 ? "+" : "", m.delta]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-muted-foreground",
							children: m.reason
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-muted-foreground",
							children: new Date(m.created_at).toLocaleDateString("ar")
						})
					]
				}, m.id))
			})] })
		]
	});
}
//#endregion
export { ProductDetailPage as component };
