import { f as getRequest, l as createServerFn } from "./esm-9EjmF9OT.mjs";
import { t as requireSupabaseAuth } from "./auth-middleware-DZO41X7i.mjs";
import { t as createServerRpc } from "./createServerRpc-TAUNrjZd.mjs";
import { Ot as objectType, Tt as booleanType, kt as stringType } from "../_libs/@ai-sdk/gateway+[...].mjs";
import { r as resolveTenantId } from "./tenant-context-Cu_IxbLU.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/catalog-import.functions-BAllU0IA.js
/**
* Admin-only server function: import products from a remote CSV catalog.
* Upserts on (tenant_id, external_id). Uses context.supabase (RLS as admin/tenant member).
*/
function parseCsv(text) {
	const rows = [];
	let row = [];
	let cur = "";
	let inQuotes = false;
	for (let i = 0; i < text.length; i++) {
		const c = text[i];
		if (inQuotes) if (c === "\"") if (text[i + 1] === "\"") {
			cur += "\"";
			i++;
		} else inQuotes = false;
		else cur += c;
		else if (c === "\"") inQuotes = true;
		else if (c === ",") {
			row.push(cur);
			cur = "";
		} else if (c === "\n" || c === "\r") {
			if (c === "\r" && text[i + 1] === "\n") i++;
			row.push(cur);
			cur = "";
			if (row.length > 1 || row[0] !== "") rows.push(row);
			row = [];
		} else cur += c;
	}
	if (cur.length > 0 || row.length > 0) {
		row.push(cur);
		rows.push(row);
	}
	return rows;
}
function slugify(input, fallback) {
	return input.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9\u0600-\u06FF\s-]/g, "").trim().replace(/\s+/g, "-").slice(0, 60) || fallback;
}
function parsePrice(raw) {
	const s = (raw || "").trim();
	if (!s) return {
		price: 0,
		currency: "YER"
	};
	const m = s.match(/([\d.,]+)\s*([A-Za-z]{3})?/);
	const price = m ? Number(m[1].replace(/,/g, "")) : 0;
	return {
		price: Number.isFinite(price) ? price : 0,
		currency: (m?.[2] || "YER").toUpperCase()
	};
}
var resolveAdminTenant = async (ctx, override) => {
	let headers = null;
	try {
		headers = getRequest().headers;
	} catch {}
	return resolveTenantId(ctx.supabase, {
		override,
		headers,
		userId: ctx.userId
	});
};
var adminImportCatalogFromUrl_createServerFn_handler = createServerRpc({
	id: "8ae08d24bb70d4ee9ba8202e7020595dd46284e97fa09673fcd53730fcdc7d39",
	name: "adminImportCatalogFromUrl",
	filename: "src/lib/catalog-import.functions.ts"
}, (opts) => adminImportCatalogFromUrl.__executeServer(opts));
var adminImportCatalogFromUrl = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => objectType({
	url: stringType().url(),
	tenantId: stringType().uuid().optional(),
	publish: booleanType().default(true)
}).parse(raw)).handler(adminImportCatalogFromUrl_createServerFn_handler, async ({ data, context }) => {
	const { data: isAdmin, error: roleErr } = await context.supabase.rpc("has_role", {
		_user_id: context.userId,
		_role: "admin"
	});
	if (roleErr) throw roleErr;
	if (!isAdmin) throw new Error("Forbidden: admin required");
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	const res = await fetch(data.url);
	if (!res.ok) throw new Error(`Failed to fetch CSV (${res.status})`);
	const rows = parseCsv(await res.text());
	if (rows.length < 2) throw new Error("CSV is empty");
	const header = rows[0].map((h) => h.trim());
	const col = (name) => header.indexOf(name);
	const idIdx = col("id");
	const titleIdx = col("title");
	const descIdx = col("description");
	const availIdx = col("availability");
	const condIdx = col("condition");
	const priceIdx = col("price");
	const linkIdx = col("link");
	const imageIdx = col("image_link");
	const brandIdx = col("brand");
	const qtyIdx = col("quantity_to_sell_on_facebook");
	if (titleIdx < 0 || priceIdx < 0 || imageIdx < 0) throw new Error("CSV missing required columns (title, price, image_link)");
	const seenSlugs = /* @__PURE__ */ new Set();
	const records = [];
	for (let r = 1; r < rows.length; r++) {
		const row = rows[r];
		if (!row || row.every((c) => !c?.trim())) continue;
		const title = (row[titleIdx] || "").trim();
		if (!title) continue;
		const externalId = idIdx >= 0 ? (row[idIdx] || "").trim() || null : null;
		const { price, currency } = parsePrice(row[priceIdx] || "");
		const image = (row[imageIdx] || "").trim();
		const stockRaw = qtyIdx >= 0 ? Number((row[qtyIdx] || "").trim()) : NaN;
		const stock = Number.isFinite(stockRaw) && stockRaw >= 0 ? Math.floor(stockRaw) : 0;
		let slug = slugify(title, externalId ?? `product-${r}`);
		let uniq = slug;
		let i = 2;
		while (seenSlugs.has(uniq)) uniq = `${slug}-${i++}`.slice(0, 60);
		seenSlugs.add(uniq);
		slug = uniq;
		records.push({
			tenant_id: tenantId,
			slug,
			name: title,
			description: (descIdx >= 0 ? row[descIdx] : "") || "",
			price,
			currency,
			images: image ? [image] : [],
			stock,
			brand: (brandIdx >= 0 ? (row[brandIdx] || "").trim() : "") || null,
			is_published: data.publish,
			external_id: externalId,
			availability: (availIdx >= 0 ? (row[availIdx] || "").trim() : "") || null,
			condition: (condIdx >= 0 ? (row[condIdx] || "").trim() : "") || null,
			source_url: (linkIdx >= 0 ? (row[linkIdx] || "").trim() : "") || null
		});
	}
	if (records.length === 0) return {
		inserted: 0,
		updated: 0,
		total: 0
	};
	const withExt = records.filter((r) => r.external_id);
	const withoutExt = records.filter((r) => !r.external_id);
	let processed = 0;
	if (withExt.length) {
		const { error, count } = await context.supabase.from("products").upsert(withExt, {
			onConflict: "tenant_id,external_id",
			count: "exact"
		});
		if (error) throw error;
		processed += count ?? withExt.length;
	}
	if (withoutExt.length) {
		const { error, count } = await context.supabase.from("products").upsert(withoutExt, {
			onConflict: "tenant_id,slug",
			ignoreDuplicates: true,
			count: "exact"
		});
		if (error) throw error;
		processed += count ?? 0;
	}
	return {
		total: records.length,
		processed
	};
});
//#endregion
export { adminImportCatalogFromUrl_createServerFn_handler };
