import { m as createFileRoute, p as lazyRouteComponent } from "../_libs/@tanstack/react-router+[...].mjs";
import { r as fetchOffers } from "./product.actions-DQCNBYrr.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/offers-D32qT6b0.js
var $$splitComponentImporter = () => import("./offers-BTuGTOQ6.mjs");
var $$splitErrorComponentImporter = () => import("./offers-CFyoTrs-.mjs");
var Route = createFileRoute("/offers")({
	head: () => ({ meta: [{ title: "العروض — اندكس ستور" }] }),
	loader: async () => fetchOffers(),
	errorComponent: lazyRouteComponent($$splitErrorComponentImporter, "errorComponent"),
	component: lazyRouteComponent($$splitComponentImporter, "component")
});
//#endregion
export { Route as t };
