import { Dt as numberType, Et as enumType, Ot as objectType, Tt as booleanType, kt as stringType, wt as arrayType } from "../_libs/@ai-sdk/gateway+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/catalog-oIutAB_A.js
var productInputSchema = objectType({
	slug: stringType().min(1).regex(/^[a-z0-9-]+$/i),
	name: stringType().min(1),
	description: stringType().default(""),
	price: numberType().min(0),
	old_price: numberType().min(0).nullable().optional(),
	currency: stringType().default("YER"),
	category_id: stringType().uuid().nullable().optional(),
	brand: stringType().nullable().optional(),
	images: arrayType(stringType().url()).default([]),
	model_url: stringType().url().nullable().optional(),
	stock: numberType().int().min(0).default(0),
	tags: arrayType(stringType()).default([]),
	badge: stringType().nullable().optional(),
	is_published: booleanType().default(true)
});
var productUpdateSchema = productInputSchema.partial().extend({ id: stringType().uuid() });
var categoryInputSchema = objectType({
	slug: stringType().min(1).regex(/^[a-z0-9-]+$/i),
	name: stringType().min(1),
	description: stringType().nullable().optional(),
	image_url: stringType().url().nullable().optional(),
	icon: stringType().nullable().optional(),
	color: stringType().nullable().optional(),
	parent_id: stringType().uuid().nullable().optional(),
	sort: numberType().int().default(0),
	is_active: booleanType().default(true)
});
var categoryUpdateSchema = categoryInputSchema.partial().extend({ id: stringType().uuid() });
var inventoryMovementSchema = objectType({
	product_id: stringType().uuid(),
	delta: numberType().int(),
	reason: enumType([
		"restock",
		"sale",
		"adjustment",
		"return",
		"damage"
	]),
	reference: stringType().nullable().optional(),
	note: stringType().nullable().optional()
});
//#endregion
export { productUpdateSchema as a, productInputSchema as i, categoryUpdateSchema as n, inventoryMovementSchema as r, categoryInputSchema as t };
