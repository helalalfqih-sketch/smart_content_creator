import { f as getRequest, l as createServerFn } from "./esm-9EjmF9OT.mjs";
import { t as createClient } from "../_libs/supabase__supabase-js.mjs";
import { t as requireSupabaseAuth } from "./auth-middleware-DZO41X7i.mjs";
import { t as createServerRpc } from "./createServerRpc-TAUNrjZd.mjs";
import { Dt as numberType, Ot as objectType, Tt as booleanType, kt as stringType, wt as arrayType } from "../_libs/@ai-sdk/gateway+[...].mjs";
import { a as productUpdateSchema, i as productInputSchema, n as categoryUpdateSchema, r as inventoryMovementSchema, t as categoryInputSchema } from "./catalog-oIutAB_A.mjs";
import { r as resolveTenantId } from "./tenant-context-Cu_IxbLU.mjs";
import processModule from "node:process";
//#region node_modules/.nitro/vite/services/ssr/assets/catalog.functions-CbAK4D2i.js
var toDTO$2 = (r) => ({
	id: r.id,
	slug: r.slug,
	name: r.name,
	description: r.description ?? "",
	price: Number(r.price),
	currency: r.currency,
	category_id: r.category_id,
	brand: r.brand,
	images: r.images ?? [],
	model_url: r.model_url,
	stock: r.stock,
	reserved_stock: r.reserved_stock,
	rating: Number(r.rating),
	reviews_count: r.reviews_count,
	tags: r.tags ?? [],
	is_published: r.is_published,
	created_at: r.created_at,
	updated_at: r.updated_at
});
var productsRepo = {
	async list(db, filters = {}) {
		let q = db.from("products").select("*").order("created_at", { ascending: false });
		if (filters.tenantId) q = q.eq("tenant_id", filters.tenantId);
		if (!filters.includeUnpublished) q = q.eq("is_published", true);
		if (filters.categoryId) q = q.eq("category_id", filters.categoryId);
		if (filters.search) q = q.ilike("name", `%${filters.search}%`);
		if (filters.limit) q = q.limit(filters.limit);
		if (filters.offset != null && filters.limit) q = q.range(filters.offset, filters.offset + filters.limit - 1);
		const { data, error } = await q;
		if (error) throw error;
		return (data ?? []).map(toDTO$2);
	},
	async getBySlug(db, slug, tenantId) {
		let q = db.from("products").select("*").eq("slug", slug);
		if (tenantId) q = q.eq("tenant_id", tenantId);
		const { data, error } = await q.maybeSingle();
		if (error) throw error;
		return data ? toDTO$2(data) : null;
	},
	async getById(db, id, tenantId) {
		let q = db.from("products").select("*").eq("id", id);
		if (tenantId) q = q.eq("tenant_id", tenantId);
		const { data, error } = await q.maybeSingle();
		if (error) throw error;
		return data ? toDTO$2(data) : null;
	},
	async create(db, tenantId, input) {
		if (!tenantId) throw new Error("productsRepo.create: tenantId required");
		const { data, error } = await db.from("products").insert({
			...input,
			tenant_id: tenantId
		}).select("*").single();
		if (error) throw error;
		return toDTO$2(data);
	},
	async update(db, tenantId, id, patch) {
		if (!tenantId) throw new Error("productsRepo.update: tenantId required");
		const { data, error } = await db.from("products").update(patch).eq("id", id).eq("tenant_id", tenantId).select("*").single();
		if (error) throw error;
		return toDTO$2(data);
	},
	async remove(db, tenantId, id) {
		if (!tenantId) throw new Error("productsRepo.remove: tenantId required");
		const { error } = await db.from("products").delete().eq("id", id).eq("tenant_id", tenantId);
		if (error) throw error;
	},
	async count(db, filters = {}) {
		let q = db.from("products").select("*", {
			count: "exact",
			head: true
		});
		if (filters.tenantId) q = q.eq("tenant_id", filters.tenantId);
		if (!filters.includeUnpublished) q = q.eq("is_published", true);
		if (filters.categoryId) q = q.eq("category_id", filters.categoryId);
		const { count, error } = await q;
		if (error) throw error;
		return count ?? 0;
	}
};
var toDTO$1 = (r) => ({
	id: r.id,
	slug: r.slug,
	name: r.name,
	description: r.description,
	image_url: r.image_url,
	parent_id: r.parent_id,
	sort: r.sort,
	icon: r.icon,
	color: r.color,
	is_active: r.is_active
});
var categoriesRepo = {
	async list(db, opts = {}) {
		let q = db.from("categories").select("*").order("sort", { ascending: true });
		if (opts.tenantId) q = q.eq("tenant_id", opts.tenantId);
		if (!opts.includeInactive) q = q.eq("is_active", true);
		const { data, error } = await q;
		if (error) throw error;
		return (data ?? []).map(toDTO$1);
	},
	async getBySlug(db, slug, tenantId) {
		let q = db.from("categories").select("*").eq("slug", slug);
		if (tenantId) q = q.eq("tenant_id", tenantId);
		const { data, error } = await q.maybeSingle();
		if (error) throw error;
		return data ? toDTO$1(data) : null;
	},
	async getById(db, id, tenantId) {
		let q = db.from("categories").select("*").eq("id", id);
		if (tenantId) q = q.eq("tenant_id", tenantId);
		const { data, error } = await q.maybeSingle();
		if (error) throw error;
		return data ? toDTO$1(data) : null;
	},
	async create(db, tenantId, input) {
		if (!tenantId) throw new Error("categoriesRepo.create: tenantId required");
		const { data, error } = await db.from("categories").insert({
			...input,
			tenant_id: tenantId
		}).select("*").single();
		if (error) throw error;
		return toDTO$1(data);
	},
	async update(db, tenantId, id, patch) {
		if (!tenantId) throw new Error("categoriesRepo.update: tenantId required");
		const { data, error } = await db.from("categories").update(patch).eq("id", id).eq("tenant_id", tenantId).select("*").single();
		if (error) throw error;
		return toDTO$1(data);
	},
	async remove(db, tenantId, id) {
		if (!tenantId) throw new Error("categoriesRepo.remove: tenantId required");
		const { error } = await db.from("categories").delete().eq("id", id).eq("tenant_id", tenantId);
		if (error) throw error;
	}
};
var toDTO = (r) => ({
	id: r.id,
	product_id: r.product_id,
	delta: r.delta,
	reason: r.reason,
	reference: r.reference,
	note: r.note,
	created_by: r.created_by,
	created_at: r.created_at
});
var inventoryRepo = {
	async listByProduct(db, tenantId, productId, limit = 50) {
		if (!tenantId) throw new Error("inventoryRepo.listByProduct: tenantId required");
		const { data, error } = await db.from("inventory_movements").select("*").eq("tenant_id", tenantId).eq("product_id", productId).order("created_at", { ascending: false }).limit(limit);
		if (error) throw error;
		return (data ?? []).map(toDTO);
	},
	async record(db, tenantId, input) {
		if (!tenantId) throw new Error("inventoryRepo.record: tenantId required");
		const { data, error } = await db.from("inventory_movements").insert({
			...input,
			tenant_id: tenantId
		}).select("*").single();
		if (error) throw error;
		return toDTO(data);
	}
};
/**
* Catalog Server Functions — thin RPC wrappers over repositories.
* - Public reads use the server publishable client (respects RLS as anon)
*   and are scoped to the resolved tenant (subdomain / header / default).
* - Admin writes use requireSupabaseAuth + admin role check and require
*   an explicit tenant context (or fall back to the user's tenant).
*/
var publicClient = () => createClient(processModule.env.SUPABASE_URL, processModule.env.SUPABASE_PUBLISHABLE_KEY, { auth: {
	storage: void 0,
	persistSession: false,
	autoRefreshToken: false
} });
var readHeaders = () => {
	try {
		return getRequest().headers;
	} catch {
		return null;
	}
};
var resolvePublicTenant = async (db, override) => resolveTenantId(db, {
	override,
	headers: readHeaders()
});
var assertAdmin = async (ctx) => {
	const { data, error } = await ctx.supabase.rpc("has_role", {
		_user_id: ctx.userId,
		_role: "admin"
	});
	if (error) throw error;
	if (!data) throw new Error("Forbidden: admin required");
};
var resolveAdminTenant = async (ctx, override) => resolveTenantId(ctx.supabase, {
	override,
	headers: readHeaders(),
	userId: ctx.userId
});
var listProducts_createServerFn_handler = createServerRpc({
	id: "ec305e715d428bd5a056174d65530dc3f73a4aae7224baa7e85f3de5db811249",
	name: "listProducts",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => listProducts.__executeServer(opts));
var listProducts = createServerFn({ method: "GET" }).inputValidator((raw) => objectType({
	tenantId: stringType().uuid().optional(),
	categoryId: stringType().uuid().optional(),
	search: stringType().optional(),
	limit: numberType().int().min(1).max(100).optional(),
	offset: numberType().int().min(0).optional()
}).parse(raw ?? {})).handler(listProducts_createServerFn_handler, async ({ data }) => {
	const db = publicClient();
	const tenantId = await resolvePublicTenant(db, data.tenantId);
	return productsRepo.list(db, {
		...data,
		tenantId
	});
});
var getProductBySlug_createServerFn_handler = createServerRpc({
	id: "338e414efdb61533c60e3c1671e7aea82e763a0409c4afad4a1f474e3d8c65ce",
	name: "getProductBySlug",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => getProductBySlug.__executeServer(opts));
var getProductBySlug = createServerFn({ method: "GET" }).inputValidator((raw) => objectType({
	slug: stringType(),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(getProductBySlug_createServerFn_handler, async ({ data }) => {
	const db = publicClient();
	const tenantId = await resolvePublicTenant(db, data.tenantId);
	return productsRepo.getBySlug(db, data.slug, tenantId);
});
var getProductsByIds_createServerFn_handler = createServerRpc({
	id: "4fa5c2a98931b84edff5daf4ea734d250404d1a8e87ce63abf9cef47224b27f9",
	name: "getProductsByIds",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => getProductsByIds.__executeServer(opts));
var getProductsByIds = createServerFn({ method: "GET" }).inputValidator((raw) => objectType({
	ids: arrayType(stringType().min(1)).min(1).max(50),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(getProductsByIds_createServerFn_handler, async ({ data }) => {
	const db = publicClient();
	const tenantId = await resolvePublicTenant(db, data.tenantId ?? null);
	const ids = data.ids;
	const rowToDTO = (r) => ({
		id: r.id,
		slug: r.slug,
		name: r.name,
		description: r.description ?? "",
		price: Number(r.price),
		currency: r.currency,
		category_id: r.category_id,
		brand: r.brand,
		images: r.images ?? [],
		model_url: r.model_url,
		stock: r.stock,
		reserved_stock: r.reserved_stock,
		rating: Number(r.rating),
		reviews_count: r.reviews_count,
		tags: r.tags ?? [],
		is_published: r.is_published,
		created_at: r.created_at,
		updated_at: r.updated_at
	});
	const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
	const uuids = ids.filter((id) => UUID_RE.test(id));
	const nonUuids = ids.filter((id) => !UUID_RE.test(id));
	const [byId, byExtId, bySlug] = await Promise.all([
		uuids.length > 0 ? db.from("products").select("*").eq("tenant_id", tenantId).eq("is_published", true).in("id", uuids) : Promise.resolve({
			data: [],
			error: null
		}),
		nonUuids.length > 0 ? db.from("products").select("*").eq("tenant_id", tenantId).eq("is_published", true).in("external_id", nonUuids) : Promise.resolve({
			data: [],
			error: null
		}),
		nonUuids.length > 0 ? db.from("products").select("*").eq("tenant_id", tenantId).eq("is_published", true).in("slug", nonUuids) : Promise.resolve({
			data: [],
			error: null
		})
	]);
	if (byId.error) throw byId.error;
	if (byExtId.error) throw byExtId.error;
	if (bySlug.error) throw bySlug.error;
	const collected = /* @__PURE__ */ new Map();
	for (const r of [
		...byId.data ?? [],
		...byExtId.data ?? [],
		...bySlug.data ?? []
	]) if (!collected.has(r.id)) collected.set(r.id, rowToDTO(r));
	const missingIds = ids.filter((id) => !Array.from(collected.values()).some((p) => p.id.toLowerCase() === id.toLowerCase() || p.slug && p.slug.toLowerCase() === id.toLowerCase()));
	if (missingIds.length > 0) {
		const docToDTO = (pId, doc) => {
			const fields = doc.fields || {};
			let priceVal = 0;
			if (fields.price) {
				if (fields.price.doubleValue !== void 0) priceVal = Number(fields.price.doubleValue);
				else if (fields.price.integerValue !== void 0) priceVal = Number(fields.price.integerValue);
			}
			const images = [];
			if (fields.image_link?.stringValue) images.push(fields.image_link.stringValue);
			if (fields.additional_image_links?.stringValue) {
				const additional = fields.additional_image_links.stringValue.split(",").map((s) => s.trim()).filter(Boolean);
				images.push(...additional);
			}
			return {
				id: pId,
				slug: pId,
				name: fields.title?.stringValue || "منتج غير معروف",
				description: fields.description?.stringValue || "",
				price: priceVal,
				currency: fields.currency?.stringValue || "YER",
				category_id: fields.category_id?.stringValue || null,
				brand: fields.brand?.stringValue || null,
				images,
				model_url: null,
				stock: 99,
				reserved_stock: 0,
				rating: 5,
				reviews_count: 0,
				tags: [],
				is_published: true,
				created_at: fields.created_at?.stringValue || (/* @__PURE__ */ new Date()).toISOString(),
				updated_at: fields.updated_at?.stringValue || (/* @__PURE__ */ new Date()).toISOString()
			};
		};
		const firestoreLookups = missingIds.map(async (missingId) => {
			if (!missingId.startsWith("prd_")) return;
			try {
				const url = `https://firestore.googleapis.com/v1/projects/smartcontentcreator-d49f2/databases/(default)/documents/catalog_products/${missingId}`;
				const res = await fetch(url);
				if (res.status === 200) {
					const doc = await res.json();
					const dto = docToDTO(missingId, doc);
					collected.set(dto.id, dto);
				}
			} catch (err) {
				console.error(`Error fetching missing product ${missingId} from Firestore REST API:`, err);
			}
		});
		await Promise.all(firestoreLookups);
	}
	const results = Array.from(collected.values());
	const idOrder = /* @__PURE__ */ new Map();
	ids.forEach((id, i) => idOrder.set(id.toLowerCase(), i));
	results.sort((a, b) => {
		const rank = (p) => Math.min(idOrder.get(p.id.toLowerCase()) ?? 999, idOrder.get(p.slug.toLowerCase()) ?? 999);
		return rank(a) - rank(b);
	});
	return results;
});
var listCategories_createServerFn_handler = createServerRpc({
	id: "9093087a4fde30e7cbeefd735d6dccc2718ef5ec811563a10f9b01884489c6f6",
	name: "listCategories",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => listCategories.__executeServer(opts));
var listCategories = createServerFn({ method: "GET" }).inputValidator((raw) => objectType({ tenantId: stringType().uuid().optional() }).parse(raw ?? {})).handler(listCategories_createServerFn_handler, async ({ data }) => {
	const db = publicClient();
	const tenantId = await resolvePublicTenant(db, data.tenantId);
	return categoriesRepo.list(db, { tenantId });
});
var getCategoryBySlug_createServerFn_handler = createServerRpc({
	id: "5488941a246672c11e7e731b5355bc6486887024c8f5ad9aee9839ae4866f700",
	name: "getCategoryBySlug",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => getCategoryBySlug.__executeServer(opts));
var getCategoryBySlug = createServerFn({ method: "GET" }).inputValidator((raw) => objectType({
	slug: stringType(),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(getCategoryBySlug_createServerFn_handler, async ({ data }) => {
	const db = publicClient();
	const tenantId = await resolvePublicTenant(db, data.tenantId);
	return categoriesRepo.getBySlug(db, data.slug, tenantId);
});
var tenantScope = objectType({ tenantId: stringType().uuid().optional() });
var adminListProducts_createServerFn_handler = createServerRpc({
	id: "e6e21352e939db3a5ba878cfadec63257aac0498924c61464adabf0555eb43e3",
	name: "adminListProducts",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminListProducts.__executeServer(opts));
var adminListProducts = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).inputValidator((raw) => objectType({
	tenantId: stringType().uuid().optional(),
	search: stringType().trim().max(120).optional(),
	categoryId: stringType().uuid().optional(),
	publishedOnly: booleanType().optional(),
	unpublishedOnly: booleanType().optional(),
	outOfStock: booleanType().optional()
}).parse(raw ?? {})).handler(adminListProducts_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	let filtered = await productsRepo.list(context.supabase, {
		tenantId,
		includeUnpublished: true,
		categoryId: data.categoryId,
		search: data.search,
		limit: 500
	});
	if (data.publishedOnly) filtered = filtered.filter((r) => r.is_published);
	if (data.unpublishedOnly) filtered = filtered.filter((r) => !r.is_published);
	if (data.outOfStock) filtered = filtered.filter((r) => r.stock <= 0);
	return filtered;
});
var adminGetProduct_createServerFn_handler = createServerRpc({
	id: "703440c04edbe7d7589447d4a582fd36961c873d4804e9030b35779a0f9f5345",
	name: "adminGetProduct",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminGetProduct.__executeServer(opts));
var adminGetProduct = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).inputValidator((raw) => objectType({
	id: stringType().uuid(),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(adminGetProduct_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	return productsRepo.getById(context.supabase, data.id, tenantId);
});
var adminListCategories_createServerFn_handler = createServerRpc({
	id: "5de4dc944a006c369d93b04878277c48bf137e5f414c453c8f056278d7013242",
	name: "adminListCategories",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminListCategories.__executeServer(opts));
var adminListCategories = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).inputValidator((raw) => tenantScope.parse(raw ?? {})).handler(adminListCategories_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	return categoriesRepo.list(context.supabase, {
		tenantId,
		includeInactive: true
	});
});
var adminCreateProduct_createServerFn_handler = createServerRpc({
	id: "06a52bbd6702707c101d6ef1f8e83375a7ace29e2800f956398e5898c2648413",
	name: "adminCreateProduct",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminCreateProduct.__executeServer(opts));
var adminCreateProduct = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => productInputSchema.extend({ tenantId: stringType().uuid().optional() }).parse(raw)).handler(adminCreateProduct_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const { tenantId: overrideTenant, ...input } = data;
	const tenantId = await resolveAdminTenant(context, overrideTenant);
	return productsRepo.create(context.supabase, tenantId, input);
});
var adminUpdateProduct_createServerFn_handler = createServerRpc({
	id: "2a10bca94ea6435dd4fa7ff3043b753b63f742aff6221e705ddaace3932ae9e3",
	name: "adminUpdateProduct",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminUpdateProduct.__executeServer(opts));
var adminUpdateProduct = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => productUpdateSchema.extend({ tenantId: stringType().uuid().optional() }).parse(raw)).handler(adminUpdateProduct_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const { id, tenantId: overrideTenant, ...patch } = data;
	const tenantId = await resolveAdminTenant(context, overrideTenant);
	return productsRepo.update(context.supabase, tenantId, id, patch);
});
var adminDeleteProduct_createServerFn_handler = createServerRpc({
	id: "95f0a74b6f757d825d5bfafce0299ffef93ec04843fd056267f8c8fe1789b49f",
	name: "adminDeleteProduct",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminDeleteProduct.__executeServer(opts));
var adminDeleteProduct = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => objectType({
	id: stringType().uuid(),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(adminDeleteProduct_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	await productsRepo.remove(context.supabase, tenantId, data.id);
	return { ok: true };
});
var adminCreateCategory_createServerFn_handler = createServerRpc({
	id: "dc6192b8126e456f8eb9c3d3d26176b1f8af356ca9c04a0c09567dec2ea6fbc8",
	name: "adminCreateCategory",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminCreateCategory.__executeServer(opts));
var adminCreateCategory = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => categoryInputSchema.extend({ tenantId: stringType().uuid().optional() }).parse(raw)).handler(adminCreateCategory_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const { tenantId: overrideTenant, ...input } = data;
	const tenantId = await resolveAdminTenant(context, overrideTenant);
	return categoriesRepo.create(context.supabase, tenantId, input);
});
var adminUpdateCategory_createServerFn_handler = createServerRpc({
	id: "f59a61bdaf33b7d255d039f5e47ada0b91cdee58fb730fcc01bfc35635fb31da",
	name: "adminUpdateCategory",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminUpdateCategory.__executeServer(opts));
var adminUpdateCategory = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => categoryUpdateSchema.extend({ tenantId: stringType().uuid().optional() }).parse(raw)).handler(adminUpdateCategory_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const { id, tenantId: overrideTenant, ...patch } = data;
	const tenantId = await resolveAdminTenant(context, overrideTenant);
	return categoriesRepo.update(context.supabase, tenantId, id, patch);
});
var adminDeleteCategory_createServerFn_handler = createServerRpc({
	id: "65b6d27341b73be55679374075255c26fc9db0341f0b600ed23cfc8df65c8d4a",
	name: "adminDeleteCategory",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminDeleteCategory.__executeServer(opts));
var adminDeleteCategory = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => objectType({
	id: stringType().uuid(),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(adminDeleteCategory_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	await categoriesRepo.remove(context.supabase, tenantId, data.id);
	return { ok: true };
});
var adminRecordInventory_createServerFn_handler = createServerRpc({
	id: "07642af69f1ad271fbf43583a8e31b47d2b3c129a00b6efbfa32423e84cfead7",
	name: "adminRecordInventory",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminRecordInventory.__executeServer(opts));
var adminRecordInventory = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((raw) => inventoryMovementSchema.extend({ tenantId: stringType().uuid().optional() }).parse(raw)).handler(adminRecordInventory_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const { tenantId: overrideTenant, ...input } = data;
	const tenantId = await resolveAdminTenant(context, overrideTenant);
	return inventoryRepo.record(context.supabase, tenantId, {
		...input,
		created_by: context.userId
	});
});
var adminListInventory_createServerFn_handler = createServerRpc({
	id: "88d95eb4d60915dd78133e41ecca3c24aaa71adb8cbe2df4d1c57d60fe95f471",
	name: "adminListInventory",
	filename: "src/lib/catalog.functions.ts"
}, (opts) => adminListInventory.__executeServer(opts));
var adminListInventory = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).inputValidator((raw) => objectType({
	productId: stringType().uuid(),
	tenantId: stringType().uuid().optional()
}).parse(raw)).handler(adminListInventory_createServerFn_handler, async ({ data, context }) => {
	await assertAdmin(context);
	const tenantId = await resolveAdminTenant(context, data.tenantId);
	return inventoryRepo.listByProduct(context.supabase, tenantId, data.productId);
});
//#endregion
export { adminCreateCategory_createServerFn_handler, adminCreateProduct_createServerFn_handler, adminDeleteCategory_createServerFn_handler, adminDeleteProduct_createServerFn_handler, adminGetProduct_createServerFn_handler, adminListCategories_createServerFn_handler, adminListInventory_createServerFn_handler, adminListProducts_createServerFn_handler, adminRecordInventory_createServerFn_handler, adminUpdateCategory_createServerFn_handler, adminUpdateProduct_createServerFn_handler, getCategoryBySlug_createServerFn_handler, getProductBySlug_createServerFn_handler, getProductsByIds_createServerFn_handler, listCategories_createServerFn_handler, listProducts_createServerFn_handler };
