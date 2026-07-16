import { m as createFileRoute, p as lazyRouteComponent } from "../_libs/@tanstack/react-router+[...].mjs";
import { c as searchProducts } from "./product.actions-DQCNBYrr.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/search-CaXqmPR2.js
var $$splitComponentImporter = () => import("./search-DUTeT1EW.mjs");
var Route = createFileRoute("/search")({
	head: () => ({ meta: [{ title: "بحث — اندكس ستور" }] }),
	loader: () => searchProducts(""),
	component: lazyRouteComponent($$splitComponentImporter, "component")
});
//#endregion
export { Route as t };
