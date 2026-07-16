import { F as notFound, m as createFileRoute, p as lazyRouteComponent } from "../_libs/@tanstack/react-router+[...].mjs";
import { o as fetchProductsByCategory } from "./product.actions-DQCNBYrr.mjs";
import { n as fetchCategoryBySlug } from "./category.actions-BVHpPEnb.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/category._id-DZecuC7j.js
var $$splitComponentImporter = () => import("./category._id-CdoO4V73.mjs");
var $$splitNotFoundComponentImporter = () => import("./category._id-CoOlNIS2.mjs");
var $$splitErrorComponentImporter = () => import("./category._id-BC7Qp-ET.mjs");
var Route = createFileRoute("/category/$id")({
	loader: async ({ params }) => {
		const cat = await fetchCategoryBySlug(params.id);
		if (!cat) throw notFound();
		return {
			cat,
			items: await fetchProductsByCategory(params.id)
		};
	},
	head: ({ loaderData }) => ({ meta: [{ title: loaderData ? `${loaderData.cat.name} — اندكس ستور` : "تصنيف — اندكس ستور" }] }),
	errorComponent: lazyRouteComponent($$splitErrorComponentImporter, "errorComponent"),
	notFoundComponent: lazyRouteComponent($$splitNotFoundComponentImporter, "notFoundComponent"),
	component: lazyRouteComponent($$splitComponentImporter, "component")
});
//#endregion
export { Route as t };
