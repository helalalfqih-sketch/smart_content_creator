import { o as __toESM } from "../_runtime.mjs";
import { a as Text, c as require_jsx_runtime, i as Button, l as require_react, n as Card, o as VStack, r as IconButton, s as HStack, t as Heading } from "../_libs/@astryxdesign/core+[...].mjs";
import { E as RotateCw, H as LoaderCircle, _ as Sparkles, ct as CircleCheck, n as ZoomOut, r as ZoomIn, v as ShoppingCart } from "../_libs/lucide-react.mjs";
import { n as toast } from "../_libs/sonner.mjs";
import { i as useMounted, r as useModelViewer } from "./model-viewer-CBb3o8sM.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/ai-3d-generator-Q9ujjqlR.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
/**
* Product3DViewerCard — standalone, Astryx-styled 3D product viewer.
*
* Uses the <model-viewer> web component (loaded on-demand via
* `useModelViewer`) so it stays framework-agnostic, works with SSR,
* and doesn't drag react-three-fiber into the bundle.
*
* Layout/controls are built with Astryx primitives (VStack/HStack/Button/
* IconButton/Text) so it lives cleanly beside the existing shadcn +
* Tailwind UI without conflicting.
*/
var DEMO_MODEL_URL = "https://modelviewer.dev/shared-assets/models/NeilArmstrong.glb";
var DEMO_POSTER_URL = "https://modelviewer.dev/assets/ShopifyModels/Chair.webp";
function Product3DViewerCard({ modelSrc = DEMO_MODEL_URL, poster = DEMO_POSTER_URL, title = "Sample Product", subtitle = "Interactive 3D preview", price = "$129.00", onAddToCart }) {
	const mounted = useMounted();
	useModelViewer();
	const mvRef = (0, import_react.useRef)(null);
	const [autoRotate, setAutoRotate] = (0, import_react.useState)(true);
	const zoom = (delta) => {
		const el = mvRef.current;
		if (!el?.getCameraOrbit) return;
		const orbit = el.getCameraOrbit();
		const next = Math.max(.5, Math.min(20, orbit.radius + delta));
		el.cameraOrbit = `${orbit.theta}rad ${orbit.phi}rad ${next}m`;
	};
	const mvStyle = {
		width: "100%",
		height: "100%",
		background: "transparent",
		["--poster-color"]: "transparent"
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Card, {
		padding: 4,
		maxWidth: 520,
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(VStack, {
			gap: 3,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(VStack, {
					gap: .5,
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Heading, {
						level: 3,
						children: title
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Text, {
						type: "supporting",
						children: subtitle
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					style: {
						position: "relative",
						width: "100%",
						aspectRatio: "1 / 1",
						borderRadius: 16,
						overflow: "hidden",
						background: "linear-gradient(135deg, var(--color-surface-subdued, #f3f4f6), var(--color-surface, #fafafa))"
					},
					children: mounted ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("model-viewer", {
						ref: (node) => {
							mvRef.current = node;
						},
						src: modelSrc,
						poster,
						alt: title,
						"camera-controls": "",
						"touch-action": "pan-y",
						...autoRotate ? { "auto-rotate": "" } : {},
						"rotation-per-second": "30deg",
						"interaction-prompt": "none",
						exposure: "1",
						"shadow-intensity": "1",
						"environment-image": "neutral",
						style: mvStyle
					}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
						src: poster,
						alt: title,
						style: {
							width: "100%",
							height: "100%",
							objectFit: "cover"
						}
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(HStack, {
					gap: 2,
					wrap: "wrap",
					vAlign: "center",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							label: autoRotate ? "Stop rotate" : "Rotate 360",
							variant: autoRotate ? "primary" : "secondary",
							size: "sm",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RotateCw, { size: 14 }),
							onClick: () => setAutoRotate((v) => !v)
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(IconButton, {
							label: "Zoom in",
							variant: "secondary",
							size: "sm",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ZoomIn, { size: 14 }),
							onClick: () => zoom(-.5)
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(IconButton, {
							label: "Zoom out",
							variant: "secondary",
							size: "sm",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ZoomOut, { size: 14 }),
							onClick: () => zoom(.5)
						})
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(HStack, {
					gap: 3,
					vAlign: "center",
					justify: "between",
					wrap: "wrap",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Text, {
						type: "large",
						weight: "bold",
						children: price
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
						label: "Add to Cart",
						variant: "primary",
						size: "md",
						icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShoppingCart, { size: 16 }),
						onClick: onAddToCart
					})]
				})
			]
		})
	});
}
/**
* AI 2D→3D Generator panel.
*
* Frontend-only architecture for the "generate 3D model from images"
* workflow. The actual call to an external provider (Meshy / Luma /
* Tripo / …) is stubbed in `generate3DFromImage` below — swap the
* setTimeout for a real fetch when the API key is wired up.
*/
/**
* ⚠️ DEV STUB — replace with a real 3D-generation API call.
*
* Example (Meshy v2):
*   const res = await fetch("https://api.meshy.ai/v2/image-to-3d", {
*     method: "POST",
*     headers: {
*       Authorization: `Bearer ${process.env.MESHY_API_KEY}`,
*       "Content-Type": "application/json",
*     },
*     body: JSON.stringify({ image_url: images[0], enable_pbr: true }),
*   });
*   const { model_urls } = await res.json();
*   return { modelUrl: model_urls.glb };
*
* Do NOT call the provider directly from the browser in production —
* proxy through a server function (createServerFn) so the API key
* stays on the server. This helper only exists to unblock UI work.
*/
async function generate3DFromImage(images) {
	if (!images.length) throw new Error("At least one image is required");
	await new Promise((r) => setTimeout(r, 3e3));
	if (Math.random() < .05) throw new Error("Generation failed (stub)");
	return { modelUrl: "https://modelviewer.dev/shared-assets/models/NeilArmstrong.glb" };
}
function Ai3dGeneratorPanel({ images, currentModelUrl, onGenerated }) {
	const [status, setStatus] = (0, import_react.useState)(currentModelUrl ? "done" : "idle");
	const [modelUrl, setModelUrl] = (0, import_react.useState)(currentModelUrl);
	const [progress, setProgress] = (0, import_react.useState)(0);
	const canGenerate = images.length > 0 && status !== "generating";
	const run = async () => {
		setStatus("generating");
		setProgress(5);
		toast.info("AI is processing your images into a 3D model. This may take a minute...");
		const timer = setInterval(() => {
			setProgress((p) => p < 90 ? p + 5 : p);
		}, 200);
		try {
			const { modelUrl: url } = await generate3DFromImage(images);
			clearInterval(timer);
			setProgress(100);
			setModelUrl(url);
			setStatus("done");
			toast.success("3D model generated successfully");
			onGenerated?.(url);
		} catch (err) {
			clearInterval(timer);
			setStatus("error");
			const msg = err instanceof Error ? err.message : "Unknown error";
			toast.error(`3D generation failed: ${msg}`);
		}
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "rounded-2xl border border-primary/30 bg-gradient-to-br from-primary/5 to-fuchsia-500/5 p-5",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex items-start justify-between gap-3",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex items-center gap-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "h-4 w-4 text-primary" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
						className: "text-sm font-black",
						children: "AI 3D Generator"
					})]
				}), status === "done" && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
					className: "inline-flex items-center gap-1 rounded-full bg-emerald-500/15 px-2 py-0.5 text-[10px] font-bold text-emerald-600",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CircleCheck, { className: "h-3 w-3" }), " Ready"]
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "mt-1 text-xs text-muted-foreground",
				children: "Turn your uploaded product photos into an interactive 3D model."
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
				type: "button",
				onClick: run,
				disabled: !canGenerate,
				className: "mt-3 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-primary to-fuchsia-500 px-4 py-2.5 text-sm font-bold text-white shadow-brand transition disabled:cursor-not-allowed disabled:opacity-50",
				children: status === "generating" ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoaderCircle, { className: "h-4 w-4 animate-spin" }), " Generating..."] }) : status === "done" ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(RotateCw, { className: "h-4 w-4" }), " Regenerate 3D Model"] }) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "h-4 w-4" }), " Generate 3D Model with AI"] })
			}),
			images.length === 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "mt-2 text-[11px] text-muted-foreground",
				children: "Upload at least one product image to enable this action."
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mt-4 overflow-hidden rounded-xl border border-border/60 bg-surface",
				children: [
					status === "generating" && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "p-4",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "aspect-square w-full animate-pulse rounded-lg bg-gradient-to-br from-muted via-muted/60 to-muted" }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "mt-3 h-1.5 w-full overflow-hidden rounded-full bg-muted",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
									className: "h-full bg-gradient-to-r from-primary to-fuchsia-500 transition-all",
									style: { width: `${progress}%` }
								})
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
								className: "mt-2 text-center text-[11px] font-bold text-muted-foreground",
								children: [
									"Rendering meshes · ",
									progress,
									"%"
								]
							})
						]
					}),
					status !== "generating" && modelUrl && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "p-2",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Product3DViewerCard, {
							modelSrc: modelUrl,
							poster: images[0] ?? "",
							title: "Generated preview",
							subtitle: "Review before saving",
							price: ""
						})
					}),
					status === "idle" && !modelUrl && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "grid aspect-square place-items-center p-6 text-center",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Sparkles, { className: "mx-auto h-8 w-8 text-primary/40" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-2 text-xs font-bold text-muted-foreground",
							children: "No 3D model yet"
						})] })
					}),
					status === "error" && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "grid aspect-square place-items-center p-6 text-center",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "text-xs font-bold text-destructive",
							children: "Generation failed. Try again."
						}) })
					})
				]
			})
		]
	});
}
//#endregion
export { Product3DViewerCard as n, Ai3dGeneratorPanel as t };
