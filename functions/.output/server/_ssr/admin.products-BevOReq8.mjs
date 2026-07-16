import { o as __toESM } from "../_runtime.mjs";
import { c as require_jsx_runtime, l as require_react } from "../_libs/@astryxdesign/core+[...].mjs";
import { g as Link, v as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { H as LoaderCircle, P as Package, _ as Sparkles, at as Copy, ct as CircleCheck, et as Eye, f as Trash2, j as Plus, nt as Download, tt as EyeOff, w as Search } from "../_libs/lucide-react.mjs";
import { n as useI18n } from "./i18n-ut2VIwHl.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
import { c as listAdminProducts, f as updateAdminProduct, i as deleteAdminProduct, n as createAdminProduct, o as importCatalogFromUrl, s as listAdminCategories } from "./admin.actions-Buk2_Af3.mjs";
import { n as toast } from "../_libs/sonner.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/admin.products-BevOReq8.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var DEFAULT_CATALOG_URL = "https://firebasestorage.googleapis.com/v0/b/smartcontentcreator-d49f2.firebasestorage.app/o/catalogs%2F3oZWFXysr6h1hzSkyICRwSX1lfs1%2Fcatalog.csv?alt=media&token=202b424d-4ce4-42cc-ad1b-830de692c7ba&ext=.csv";
function ProductsPage() {
	const { t } = useI18n();
	const qc = useQueryClient();
	const navigate = useNavigate();
	const [search, setSearch] = (0, import_react.useState)("");
	const [categoryId, setCategoryId] = (0, import_react.useState)("");
	const [filter, setFilter] = (0, import_react.useState)("all");
	const query = (0, import_react.useMemo)(() => ({
		search: search.trim() || void 0,
		categoryId: categoryId || void 0,
		publishedOnly: filter === "published" || void 0,
		unpublishedOnly: filter === "unpublished" || void 0,
		outOfStock: filter === "out" || void 0
	}), [
		search,
		categoryId,
		filter
	]);
	const productsQ = useQuery({
		queryKey: ["admin-products", query],
		queryFn: () => listAdminProducts(query)
	});
	const categoriesQ = useQuery({
		queryKey: ["admin-categories"],
		queryFn: () => listAdminCategories()
	});
	const invalidate = () => qc.invalidateQueries({ queryKey: ["admin-products"] });
	const togglePublish = useMutation({
		mutationFn: (p) => updateAdminProduct({
			id: p.id,
			is_published: p.is_published
		}),
		onSuccess: (_d, v) => {
			toast.success(v.is_published ? "تم النشر" : "تم إلغاء النشر");
			invalidate();
		},
		onError: (e) => toast.error(e.message)
	});
	const removeMut = useMutation({
		mutationFn: (id) => deleteAdminProduct(id),
		onSuccess: () => {
			toast.success("تم حذف المنتج");
			invalidate();
		},
		onError: (e) => toast.error(e.message)
	});
	const duplicateMut = useMutation({
		mutationFn: async (id) => {
			const src = (productsQ.data ?? []).find((p) => p.id === id);
			if (!src) throw new Error("Product not found");
			const suffix = `-copy-${Math.random().toString(36).slice(2, 6)}`;
			return createAdminProduct({
				slug: (src.slug + suffix).slice(0, 60),
				name: src.name + " (نسخة)",
				description: src.description,
				price: src.price,
				currency: src.currency,
				category_id: src.category_id ?? void 0,
				brand: src.brand ?? void 0,
				images: src.images,
				model_url: src.model_url ?? void 0,
				stock: src.stock,
				tags: src.tags,
				is_published: false
			});
		},
		onSuccess: () => {
			toast.success("تم إنشاء نسخة");
			invalidate();
		},
		onError: (e) => toast.error(e.message)
	});
	const importMut = useMutation({
		mutationFn: (url) => importCatalogFromUrl({
			url,
			publish: true
		}),
		onSuccess: (r) => {
			toast.success(`تم الاستيراد: ${r.processed}/${r.total}`);
			invalidate();
		},
		onError: (e) => toast.error(e.message)
	});
	const products = productsQ.data ?? [];
	const categories = categoriesQ.data ?? [];
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "space-y-6",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex flex-wrap items-center justify-between gap-3",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "text-3xl font-black lg:text-4xl",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
						className: "neon-text",
						children: t("products.title")
					})
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-1 text-sm text-muted-foreground",
					children: productsQ.isLoading ? "جارٍ التحميل..." : `${products.length} منتج`
				})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex flex-wrap gap-2",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
							onClick: () => {
								const url = window.prompt("رابط ملف CSV للاستيراد:", DEFAULT_CATALOG_URL);
								if (url && url.trim()) importMut.mutate(url.trim());
							},
							disabled: importMut.isPending,
							className: "inline-flex items-center gap-2 rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-bold hover:bg-accent disabled:opacity-60",
							children: [importMut.isPending ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-4 w-4 animate-spin" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Download, { className: "h-4 w-4" }), "استيراد CSV"]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
							onClick: () => navigate({
								to: "/admin/product/$id",
								params: { id: "new" }
							}),
							className: "inline-flex items-center gap-2 rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-bold hover:bg-accent",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "h-4 w-4" }), "منتج جديد"]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
							to: "/admin/studio",
							className: "inline-flex items-center gap-2 rounded-xl gradient-brand px-4 py-2.5 text-sm font-bold text-primary-foreground shadow-brand",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "h-4 w-4" }), t("nav.studio")]
						})
					]
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "rounded-2xl glass p-4 flex flex-wrap items-center gap-3",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "relative flex-1 min-w-[200px]",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "absolute top-1/2 -translate-y-1/2 start-3 h-4 w-4 text-muted-foreground" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
							type: "text",
							value: search,
							onChange: (e) => setSearch(e.target.value),
							placeholder: "بحث بالاسم...",
							className: "w-full rounded-xl border border-border bg-surface ps-9 pe-3 py-2 text-sm outline-none focus:border-primary"
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("select", {
						value: categoryId,
						onChange: (e) => setCategoryId(e.target.value),
						className: "rounded-xl border border-border bg-surface px-3 py-2 text-sm",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
							value: "",
							children: "كل التصنيفات"
						}), categories.map((c) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
							value: c.id,
							children: c.name
						}, c.id))]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "flex gap-1 rounded-xl border border-border bg-surface p-1",
						children: [
							"all",
							"published",
							"unpublished",
							"out"
						].map((f) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
							onClick: () => setFilter(f),
							className: `rounded-lg px-3 py-1.5 text-xs font-bold ${filter === f ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"}`,
							children: f === "all" ? "الكل" : f === "published" ? "منشور" : f === "unpublished" ? "غير منشور" : "نفد"
						}, f))
					})
				]
			}),
			productsQ.isError ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "rounded-2xl glass p-8 text-center text-destructive",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
					className: "text-sm",
					children: ["تعذّر تحميل المنتجات: ", productsQ.error.message]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
					onClick: () => productsQ.refetch(),
					className: "mt-3 inline-flex rounded-lg bg-surface px-3 py-1.5 text-xs font-bold",
					children: "إعادة المحاولة"
				})]
			}) : productsQ.isLoading ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "rounded-2xl glass p-12 text-center",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "mx-auto h-6 w-6 animate-spin text-primary" })
			}) : products.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "rounded-2xl glass p-12 text-center",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-primary/10",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Package, { className: "h-7 w-7 text-primary" })
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-4 text-sm text-muted-foreground",
					children: "لا توجد منتجات"
				})]
			}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4",
				children: products.map((p) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "tilt-3d group relative overflow-hidden rounded-2xl glass",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "relative aspect-[4/3] overflow-hidden bg-muted",
						children: [
							p.images[0] ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
								src: p.images[0],
								alt: p.name,
								className: "h-full w-full object-cover transition group-hover:scale-105"
							}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "grid h-full place-items-center text-muted-foreground",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Package, { className: "h-8 w-8" })
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: `absolute top-3 end-3 rounded-full px-2.5 py-1 text-[10px] font-bold ${p.is_published ? "bg-success text-success-foreground" : "bg-muted text-muted-foreground"}`,
								children: p.is_published ? "منشور" : "مسودة"
							}),
							p.stock <= 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "absolute top-3 start-3 rounded-full bg-destructive px-2.5 py-1 text-[10px] font-bold text-destructive-foreground",
								children: "نفد"
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "p-4",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "truncate text-sm font-black",
								children: p.name
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "mt-1 text-xs text-muted-foreground",
								children: categories.find((c) => c.id === p.category_id)?.name ?? "بدون تصنيف"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-2 flex items-center justify-between",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "text-sm font-black text-primary",
									children: [
										p.price,
										" ",
										p.currency
									]
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "text-xs text-muted-foreground",
									children: ["مخزون: ", p.stock]
								})]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-3 flex items-center gap-1.5",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
										to: "/admin/product/$id",
										params: { id: p.id },
										className: "inline-flex flex-1 items-center justify-center gap-1.5 rounded-lg border border-border bg-surface py-2 text-xs font-bold hover:bg-accent",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Eye, { className: "h-3.5 w-3.5" }), "تفاصيل"]
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
										onClick: () => togglePublish.mutate({
											id: p.id,
											is_published: !p.is_published
										}),
										disabled: togglePublish.isPending,
										className: `inline-flex items-center justify-center rounded-lg p-2 hover:opacity-80 ${p.is_published ? "bg-muted text-muted-foreground" : "bg-success text-success-foreground"}`,
										title: p.is_published ? "إلغاء النشر" : "نشر",
										children: p.is_published ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(EyeOff, { className: "h-3.5 w-3.5" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CircleCheck, { className: "h-3.5 w-3.5" })
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
										onClick: () => duplicateMut.mutate(p.id),
										disabled: duplicateMut.isPending,
										className: "inline-flex items-center justify-center rounded-lg bg-accent p-2 hover:opacity-80",
										title: "نسخ",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Copy, { className: "h-3.5 w-3.5" })
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
										onClick: () => {
											if (confirm(`حذف "${p.name}"؟`)) removeMut.mutate(p.id);
										},
										disabled: removeMut.isPending,
										className: "inline-flex items-center justify-center rounded-lg bg-destructive/10 p-2 text-destructive hover:bg-destructive/20",
										title: "حذف",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "h-3.5 w-3.5" })
									})
								]
							})
						]
					})]
				}, p.id))
			})
		]
	});
}
//#endregion
export { ProductsPage as component };
