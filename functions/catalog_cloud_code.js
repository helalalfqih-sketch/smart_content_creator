/**
 * Back4App Cloud Code - Catalog Domain Module (Production v1)
 * High-Performance Catalog Database, Offline-Sync, Secure Media & Meta Commerce Management
 */

const crypto = require("crypto");
const axios = require("axios");

const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "smartcontentcreator2";
const GOOGLE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";
const ADMIN_SECRET = process.env.CATALOG_ADMIN_SECRET || "scc_catalog_migration_admin_secret_2026";

// Known Admin UIDs (can be extended or checked via Firebase custom claims)
const ADMIN_UIDS = new Set([
  "admin",
  "helal_admin",
  "d1w1a2XQfUe4r3v2",
  "owner"
]);

// ============================================================================
// 1️⃣ CRYPTOGRAPHIC FIREBASE AUTH & TOKEN VERIFICATION
// ============================================================================

let certsCache = {
  certs: null,
  expiresAt: 0,
};

async function getGooglePublicCerts() {
  const now = Date.now();
  if (certsCache.certs && certsCache.expiresAt > now) {
    return certsCache.certs;
  }

  try {
    const res = await axios.get(GOOGLE_CERTS_URL, { timeout: 10000 });
    const certs = res.data;

    let maxAgeMs = 3600 * 1000;
    const cacheControl = (res.headers && (res.headers["cache-control"] || res.headers["Cache-Control"])) || "";
    const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
    if (maxAgeMatch) {
      maxAgeMs = parseInt(maxAgeMatch[1], 10) * 1000;
    }

    certsCache = {
      certs: certs,
      expiresAt: now + Math.max(maxAgeMs, 300000),
    };

    return certs;
  } catch (err) {
    console.error(`[AUTH_CERTS] Failed to fetch Google certificates: ${err.message || err}`);
    if (certsCache.certs) return certsCache.certs;
    return null;
  }
}

async function verifyFirebaseIdToken(token) {
  if (!token || typeof token !== "string" || token.length < 20) return null;

  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const header = JSON.parse(Buffer.from(parts[0], "base64").toString("utf8"));
    const claims = JSON.parse(Buffer.from(parts[1], "base64").toString("utf8"));

    if (header.alg !== "RS256" || !header.kid) return null;

    const now = Math.floor(Date.now() / 1000);
    const clockSkew = 300;

    if (!claims.exp || claims.exp < (now - clockSkew)) return null;
    if (!claims.iat || claims.iat > (now + clockSkew)) return null;

    if (!claims.aud || claims.aud !== FIREBASE_PROJECT_ID) return null;
    const expectedIssuer = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
    if (!claims.iss || claims.iss !== expectedIssuer) return null;

    if (!claims.sub || typeof claims.sub !== "string" || claims.sub.trim().length === 0) return null;

    const certs = await getGooglePublicCerts();
    if (!certs || !certs[header.kid]) return null;

    const certPem = certs[header.kid];
    const dataToVerify = `${parts[0]}.${parts[1]}`;
    const signature = Buffer.from(parts[2], "base64");

    const verifier = crypto.createVerify("RSA-SHA256");
    verifier.update(dataToVerify);
    const isSignatureValid = verifier.verify(certPem, signature);

    if (!isSignatureValid) return null;

    return {
      uid: claims.sub,
      email: claims.email || null,
      admin: Boolean(claims.admin === true || claims.role === "admin" || ADMIN_UIDS.has(claims.sub)),
      claims: claims
    };
  } catch (err) {
    console.warn(`[AUTH] Token verification error: ${err.message || err}`);
    return null;
  }
}

async function extractAuthUser(request) {
  if (request.user && request.user.id) {
    return {
      uid: `parse_${request.user.id}`,
      admin: Boolean(request.user.get("role") === "admin" || request.master),
      type: "parse"
    };
  }

  const token = (request.params || {}).firebaseIdToken || (request.headers || {})["x-firebase-token"];
  if (token) {
    const verified = await verifyFirebaseIdToken(token);
    if (verified) {
      return {
        uid: verified.uid,
        admin: verified.admin,
        type: "firebase",
        email: verified.email
      };
    }
  }

  const adminAuth = (request.params || {}).adminSecret || (request.headers || {})["x-catalog-admin-secret"];
  if (adminAuth && adminAuth === ADMIN_SECRET) {
    return {
      uid: "system_admin",
      admin: true,
      type: "secret"
    };
  }

  return null;
}

// ============================================================================
// 2️⃣ DEDUPE & NORMALIZATION HELPERS
// ============================================================================

function computeMediaDedupeKey(productId, type, url) {
  const normUrl = String(url || "").trim();
  const raw = `${productId}|${type}|${normUrl}`;
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function normalizeProductLink(link, productId) {
  if (!link || typeof link !== "string") return "";
  const trimmed = link.trim();
  if (trimmed.includes("smartcontentcreator-d49f2.web.app")) {
    return productId ? `https://smartcontentcreator2.web.app/app/product/${productId}` : "https://smartcontentcreator2.web.app/app";
  }
  return trimmed;
}

// ============================================================================
// 3️⃣ LIVE SCHEMA BOOTSTRAP & CLP LOCKDOWN
// ============================================================================

async function bootstrapCatalogSchemas() {
  const results = {};

  // Class Level Permissions: Complete Public Lockdown
  const strictClp = {
    get: {},
    find: {},
    count: {},
    create: {},
    update: {},
    delete: {},
    addField: {}
  };

  // 1. CatalogProduct Schema
  try {
    const productSchema = new Parse.Schema("CatalogProduct");
    productSchema.setCLP(strictClp);

    // Fields
    productSchema.addString("productId");
    productSchema.addString("retailerId");
    productSchema.addString("originalCatalogId");
    productSchema.addString("title");
    productSchema.addString("description");
    productSchema.addString("availability");
    productSchema.addString("condition");
    productSchema.addNumber("price");
    productSchema.addString("currency");
    productSchema.addString("link");
    productSchema.addString("imageLink");
    productSchema.addArray("additionalImageLinks");
    productSchema.addString("videoUrl");
    productSchema.addString("brand");
    productSchema.addString("googleProductCategory");
    productSchema.addString("fbProductCategory");
    productSchema.addString("categoryId");
    productSchema.addString("categoryName");
    productSchema.addString("metaProductType");
    productSchema.addNumber("quantity");
    productSchema.addNumber("salePrice");
    productSchema.addString("salePriceEffectiveDate");
    productSchema.addString("itemGroupId");
    productSchema.addString("gender");
    productSchema.addString("color");
    productSchema.addString("size");
    productSchema.addString("ageGroup");
    productSchema.addString("material");
    productSchema.addString("pattern");
    productSchema.addString("shipping");
    productSchema.addString("shippingWeight");
    productSchema.addString("gtin");
    productSchema.addArray("productTags");
    productSchema.addString("style");
    productSchema.addString("creatorUid");
    productSchema.addString("status");
    productSchema.addString("scope");
    productSchema.addString("source");
    productSchema.addNumber("schemaVersion");
    productSchema.addNumber("syncVersion");
    productSchema.addDate("clientUpdatedAt");
    productSchema.addDate("lastSyncedAt");
    productSchema.addDate("deletedAt");

    // Indexes: Unique Index on productId
    productSchema.addIndex("unique_productId", { productId: 1 }, { unique: true });
    productSchema.addIndex("idx_category", { categoryId: 1, status: 1 });
    productSchema.addIndex("idx_scope_status", { scope: 1, status: 1 });

    try {
      await productSchema.save();
      results.CatalogProduct = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await productSchema.update();
        results.CatalogProduct = "updated";
      } else {
        results.CatalogProduct = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogProduct = `fatal: ${err.message}`;
  }

  // 2. CatalogProductMedia Schema
  try {
    const mediaSchema = new Parse.Schema("CatalogProductMedia");
    mediaSchema.setCLP(strictClp);

    mediaSchema.addPointer("product", "CatalogProduct");
    mediaSchema.addString("productId");
    mediaSchema.addString("type");
    mediaSchema.addString("url");
    mediaSchema.addString("thumbnailUrl");
    mediaSchema.addString("mimeType");
    mediaSchema.addString("filename");
    mediaSchema.addNumber("sortOrder");
    mediaSchema.addBoolean("isPrimary");
    mediaSchema.addString("source");
    mediaSchema.addString("status");
    mediaSchema.addNumber("width");
    mediaSchema.addNumber("height");
    mediaSchema.addNumber("durationMs");
    mediaSchema.addObject("metadata");
    mediaSchema.addString("dedupeKey");

    // Indexes: Unique Index on dedupeKey (race-safe)
    mediaSchema.addIndex("unique_media_dedupe", { dedupeKey: 1 }, { unique: true });
    mediaSchema.addIndex("idx_media_product", { productId: 1, type: 1 });

    try {
      await mediaSchema.save();
      results.CatalogProductMedia = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await mediaSchema.update();
        results.CatalogProductMedia = "updated";
      } else {
        results.CatalogProductMedia = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogProductMedia = `fatal: ${err.message}`;
  }

  // 3. CatalogCategory Schema
  try {
    const categorySchema = new Parse.Schema("CatalogCategory");
    categorySchema.setCLP(strictClp);

    categorySchema.addString("categoryId");
    categorySchema.addString("name");
    categorySchema.addString("nameAr");
    categorySchema.addString("slug");
    categorySchema.addString("googleCategory");
    categorySchema.addString("fbCategory");
    categorySchema.addString("imageUrl");
    categorySchema.addNumber("sortOrder");
    categorySchema.addBoolean("active");
    categorySchema.addString("scope");
    categorySchema.addString("creatorUid");
    categorySchema.addObject("metadata");

    categorySchema.addIndex("unique_categoryId", { categoryId: 1 }, { unique: true });

    try {
      await categorySchema.save();
      results.CatalogCategory = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await categorySchema.update();
        results.CatalogCategory = "updated";
      } else {
        results.CatalogCategory = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogCategory = `fatal: ${err.message}`;
  }

  // 4. CatalogSyncState Schema
  try {
    const syncSchema = new Parse.Schema("CatalogSyncState");
    syncSchema.setCLP(strictClp);

    syncSchema.addString("ownerUid");
    syncSchema.addString("deviceId");
    syncSchema.addDate("lastPullAt");
    syncSchema.addDate("lastPushAt");
    syncSchema.addNumber("lastServerVersion");
    syncSchema.addString("status");
    syncSchema.addNumber("pendingOperations");
    syncSchema.addString("lastError");
    syncSchema.addObject("metadata");

    syncSchema.addIndex("idx_sync_owner", { ownerUid: 1, deviceId: 1 });

    try {
      await syncSchema.save();
      results.CatalogSyncState = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await syncSchema.update();
        results.CatalogSyncState = "updated";
      } else {
        results.CatalogSyncState = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogSyncState = `fatal: ${err.message}`;
  }

  // 5. CatalogChangeLog Schema
  try {
    const logSchema = new Parse.Schema("CatalogChangeLog");
    logSchema.setCLP(strictClp);

    logSchema.addPointer("product", "CatalogProduct");
    logSchema.addString("productId");
    logSchema.addString("operation");
    logSchema.addString("actorUid");
    logSchema.addNumber("version");
    logSchema.addArray("changedFields");
    logSchema.addObject("beforeData");
    logSchema.addObject("afterData");
    logSchema.addString("source");
    logSchema.addString("deviceId");

    logSchema.addIndex("idx_log_product", { productId: 1, version: -1 });

    try {
      await logSchema.save();
      results.CatalogChangeLog = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await logSchema.update();
        results.CatalogChangeLog = "updated";
      } else {
        results.CatalogChangeLog = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogChangeLog = `fatal: ${err.message}`;
  }

  return results;
}

// ============================================================================
// 4️⃣ CLOUD CODE CATALOG API IMPLEMENTATION
// ============================================================================

// 📋 catalogList: Paginated list with server-enforced scoping
Parse.Cloud.define("catalogList", async (request) => {
  const params = request.params || {};
  const page = Math.max(1, parseInt(params.page || 1, 10));
  const limit = Math.min(100, Math.max(1, parseInt(params.limit || 50, 10)));
  const category = (params.category || "").trim();
  const search = (params.search || "").trim().toLowerCase();
  const sort = params.sort || "created_desc";

  const auth = await extractAuthUser(request);
  const userUid = auth ? auth.uid : null;

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);

  // Soft delete filter
  query.doesNotExist("deletedAt");

  // Scoping:
  if (userUid && auth.admin) {
    // Admin sees all non-deleted
  } else if (userUid) {
    // Authenticated user sees global approved OR their own
    const globalQuery = new Parse.Query(CatalogProduct);
    globalQuery.equalTo("scope", "global");
    globalQuery.equalTo("status", "approved");
    globalQuery.doesNotExist("deletedAt");

    const ownQuery = new Parse.Query(CatalogProduct);
    ownQuery.equalTo("creatorUid", userUid);
    ownQuery.doesNotExist("deletedAt");

    const mainQuery = Parse.Query.or(globalQuery, ownQuery);
    if (category && category !== "الكل") {
      mainQuery.equalTo("categoryName", category);
    }
    if (search) {
      mainQuery.matches("title", new RegExp(search, "i"));
    }
    mainQuery.skip((page - 1) * limit);
    mainQuery.limit(limit);
    mainQuery.descending("createdAt");

    const [items, totalCount] = await Promise.all([
      mainQuery.find({ useMasterKey: true }),
      mainQuery.count({ useMasterKey: true })
    ]);

    return {
      success: true,
      page,
      limit,
      total: totalCount,
      totalPages: Math.ceil(totalCount / limit),
      data: items.map(p => ({ id: p.id, ...p.toJSON() }))
    };
  } else {
    // Public / anonymous: strictly global and approved
    query.equalTo("scope", "global");
    query.equalTo("status", "approved");
  }

  if (category && category !== "الكل") {
    query.equalTo("categoryName", category);
  }

  if (search) {
    query.matches("title", new RegExp(search, "i"));
  }

  if (sort === "created_asc") {
    query.ascending("createdAt");
  } else if (sort === "price_asc") {
    query.ascending("price");
  } else if (sort === "price_desc") {
    query.descending("price");
  } else {
    query.descending("createdAt");
  }

  query.skip((page - 1) * limit);
  query.limit(limit);

  const [items, totalCount] = await Promise.all([
    query.find({ useMasterKey: true }),
    query.count({ useMasterKey: true })
  ]);

  return {
    success: true,
    page,
    limit,
    total: totalCount,
    totalPages: Math.ceil(totalCount / limit),
    data: items.map(p => ({ id: p.id, ...p.toJSON() }))
  };
});

// 🔍 catalogGet: Retrieve single product + associated media
Parse.Cloud.define("catalogGet", async (request) => {
  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const auth = await extractAuthUser(request);
  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);
  query.equalTo("productId", productId);

  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  // Check access
  const isDeleted = product.get("deletedAt") != null;
  const isPrivate = product.get("scope") === "private";
  const creatorUid = product.get("creatorUid");

  if (isDeleted && (!auth || !auth.admin)) {
    throw new Parse.Error(404, "Product not found");
  }

  if (isPrivate && (!auth || (auth.uid !== creatorUid && !auth.admin))) {
    throw new Parse.Error(403, "Access denied to private product");
  }

  // Load associated media
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const mediaQuery = new Parse.Query(CatalogProductMedia);
  mediaQuery.equalTo("productId", productId);
  mediaQuery.equalTo("status", "active");
  mediaQuery.descending("isPrimary");
  mediaQuery.ascending("sortOrder");

  const mediaList = await mediaQuery.find({ useMasterKey: true });

  return {
    success: true,
    product: { id: product.id, ...product.toJSON() },
    media: mediaList.map(m => ({ id: m.id, ...m.toJSON() }))
  };
});

// ➕ catalogCreate: Create new product with audit trail
Parse.Cloud.define("catalogCreate", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  if (!params.title || !params.title.trim()) {
    throw new Parse.Error(400, "Title is required");
  }

  const now = new Date();
  const productId = (params.productId || `prd_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`).trim();

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const product = new CatalogProduct();

  product.set("productId", productId);
  product.set("retailerId", params.retailerId || productId);
  product.set("originalCatalogId", params.originalCatalogId || "");
  product.set("title", params.title.trim());
  product.set("description", params.description || "");
  product.set("availability", params.availability || "in stock");
  product.set("condition", params.condition || "new");
  product.set("price", Number(params.price) || 0.0);
  product.set("currency", params.currency || "YER");
  product.set("link", normalizeProductLink(params.link, productId));
  product.set("imageLink", params.imageLink || "");
  product.set("additionalImageLinks", Array.isArray(params.additionalImageLinks) ? params.additionalImageLinks : []);
  product.set("videoUrl", params.videoUrl || null);
  product.set("brand", params.brand || null);
  product.set("googleProductCategory", params.googleProductCategory || null);
  product.set("fbProductCategory", params.fbProductCategory || null);
  product.set("categoryId", params.categoryId || null);
  product.set("categoryName", params.categoryName || null);
  product.set("metaProductType", params.metaProductType || null);
  product.set("quantity", Number(params.quantity) || 1);
  product.set("salePrice", params.salePrice != null ? Number(params.salePrice) : null);
  product.set("salePriceEffectiveDate", params.salePriceEffectiveDate || null);
  product.set("itemGroupId", params.itemGroupId || null);
  product.set("gender", params.gender || null);
  product.set("color", params.color || null);
  product.set("size", params.size || null);
  product.set("ageGroup", params.ageGroup || null);
  product.set("material", params.material || null);
  product.set("pattern", params.pattern || null);
  product.set("shipping", params.shipping || null);
  product.set("shippingWeight", params.shippingWeight || null);
  product.set("gtin", params.gtin || null);
  product.set("productTags", Array.isArray(params.productTags) ? params.productTags : []);
  product.set("style", params.style || null);

  // Security: creatorUid strictly from verified token
  product.set("creatorUid", auth.uid);
  product.set("status", params.status || "approved");
  product.set("scope", params.scope || "global");
  product.set("source", params.source || "app");
  product.set("schemaVersion", 1);
  product.set("syncVersion", 1);
  product.set("clientUpdatedAt", params.clientUpdatedAt ? new Date(params.clientUpdatedAt) : now);
  product.set("lastSyncedAt", now);

  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", productId);
  log.set("operation", "create");
  log.set("actorUid", auth.uid);
  log.set("version", 1);
  log.set("changedFields", Object.keys(params));
  log.set("afterData", product.toJSON());
  log.set("source", params.source || "app");
  log.set("deviceId", params.deviceId || "unknown");
  await log.save(null, { useMasterKey: true });

  return { success: true, product: { id: product.id, ...product.toJSON() } };
});

// ✏️ catalogUpdate: Update with optimistic concurrency check
Parse.Cloud.define("catalogUpdate", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);
  query.equalTo("productId", productId);

  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  if (product.get("creatorUid") !== auth.uid && !auth.admin) {
    throw new Parse.Error(403, "Not authorized to update this product");
  }

  const beforeData = product.toJSON();
  const currentSyncVersion = product.get("syncVersion") || 1;

  if (params.expectedSyncVersion != null && currentSyncVersion > params.expectedSyncVersion) {
    throw new Parse.Error(409, `Conflict: Product version is ${currentSyncVersion}, expected ${params.expectedSyncVersion}`);
  }

  const allowedFields = [
    "title", "description", "availability", "condition", "price", "currency",
    "link", "imageLink", "additionalImageLinks", "videoUrl", "brand",
    "googleProductCategory", "fbProductCategory", "categoryId", "categoryName",
    "metaProductType", "quantity", "salePrice", "salePriceEffectiveDate",
    "itemGroupId", "gender", "color", "size", "ageGroup", "material",
    "pattern", "shipping", "shippingWeight", "gtin", "productTags",
    "style", "status", "scope"
  ];

  const changedFields = [];
  for (const field of allowedFields) {
    if (params[field] !== undefined) {
      if (field === "link") {
        product.set(field, normalizeProductLink(params[field], productId));
      } else {
        product.set(field, params[field]);
      }
      changedFields.push(field);
    }
  }

  const nextVersion = currentSyncVersion + 1;
  product.set("syncVersion", nextVersion);
  product.set("clientUpdatedAt", params.clientUpdatedAt ? new Date(params.clientUpdatedAt) : new Date());
  product.set("lastSyncedAt", new Date());

  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", productId);
  log.set("operation", "update");
  log.set("actorUid", auth.uid);
  log.set("version", nextVersion);
  log.set("changedFields", changedFields);
  log.set("beforeData", beforeData);
  log.set("afterData", product.toJSON());
  log.set("source", params.source || "app");
  log.set("deviceId", params.deviceId || "unknown");
  await log.save(null, { useMasterKey: true });

  return { success: true, product: { id: product.id, ...product.toJSON() } };
});

// 🗑️ catalogDelete: Soft deletion (prevents client resurrection)
Parse.Cloud.define("catalogDelete", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);
  query.equalTo("productId", productId);

  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  if (product.get("creatorUid") !== auth.uid && !auth.admin) {
    throw new Parse.Error(403, "Not authorized to delete this product");
  }

  const nextVersion = (product.get("syncVersion") || 1) + 1;
  product.set("status", "deleted");
  product.set("deletedAt", new Date());
  product.set("syncVersion", nextVersion);
  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", productId);
  log.set("operation", "delete");
  log.set("actorUid", auth.uid);
  log.set("version", nextVersion);
  log.set("changedFields", ["status", "deletedAt"]);
  await log.save(null, { useMasterKey: true });

  return { success: true, productId, status: "deleted" };
});

// 🔄 catalogRestore: Restore soft-deleted product
Parse.Cloud.define("catalogRestore", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);
  query.equalTo("productId", productId);

  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  if (product.get("creatorUid") !== auth.uid && !auth.admin) {
    throw new Parse.Error(403, "Not authorized to restore this product");
  }

  const nextVersion = (product.get("syncVersion") || 1) + 1;
  product.set("status", "approved");
  product.unset("deletedAt");
  product.set("syncVersion", nextVersion);
  await product.save(null, { useMasterKey: true });

  return { success: true, productId, status: "approved" };
});

// 🖼️ catalogMediaList: List all media for a product
Parse.Cloud.define("catalogMediaList", async (request) => {
  const params = request.params || {};
  const productId = params.productId;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const query = new Parse.Query(CatalogProductMedia);
  query.equalTo("productId", productId);
  query.equalTo("status", "active");
  query.descending("isPrimary");
  query.ascending("sortOrder");

  const list = await query.find({ useMasterKey: true });
  return { success: true, media: list.map(m => ({ id: m.id, ...m.toJSON() })) };
});

// 🖼️ catalogMediaAdd: Add/dedup media and sync with CatalogProduct denormalized fields
Parse.Cloud.define("catalogMediaAdd", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId;
  const url = (params.url || "").trim();
  const type = params.type || "image";

  if (!productId || !url) throw new Parse.Error(400, "productId and url are required");

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const pQuery = new Parse.Query(CatalogProduct);
  pQuery.equalTo("productId", productId);
  const product = await pQuery.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  if (product.get("creatorUid") !== auth.uid && !auth.admin) {
    throw new Parse.Error(403, "Not authorized to add media to this product");
  }

  const dedupeKey = computeMediaDedupeKey(productId, type, url);

  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const mQuery = new Parse.Query(CatalogProductMedia);
  mQuery.equalTo("dedupeKey", dedupeKey);
  let media = await mQuery.first({ useMasterKey: true });

  const isNew = !media;
  if (!media) {
    media = new CatalogProductMedia();
    media.set("dedupeKey", dedupeKey);
    media.set("product", product);
    media.set("productId", productId);
    media.set("type", type);
    media.set("url", url);
    media.set("thumbnailUrl", params.thumbnailUrl || url);
    media.set("mimeType", params.mimeType || (type === "video" ? "video/mp4" : "image/jpeg"));
    media.set("filename", params.filename || null);
    media.set("sortOrder", Number(params.sortOrder) || 0);
    media.set("isPrimary", Boolean(params.isPrimary));
    media.set("source", params.source || "app");
    media.set("status", "active");
    media.set("width", Number(params.width) || null);
    media.set("height", Number(params.height) || null);
    media.set("durationMs", Number(params.durationMs) || null);
    media.set("metadata", params.metadata || {});
    await media.save(null, { useMasterKey: true });
  }

  // Synchronize denormalized fields on CatalogProduct
  if (type === "video") {
    if (!product.get("videoUrl") || params.isPrimary) {
      product.set("videoUrl", url);
    }
  } else if (type === "image") {
    if (params.isPrimary || !product.get("imageLink")) {
      product.set("imageLink", url);
    } else {
      const currentAdditional = product.get("additionalImageLinks") || [];
      if (!currentAdditional.includes(url)) {
        product.set("additionalImageLinks", [...currentAdditional, url]);
      }
    }
  }
  await product.save(null, { useMasterKey: true });

  return { success: true, created: isNew, media: { id: media.id, ...media.toJSON() } };
});

// 🗂️ catalogCategoriesList: Return active categories
Parse.Cloud.define("catalogCategoriesList", async () => {
  const CatalogCategory = Parse.Object.extend("CatalogCategory");
  const query = new Parse.Query(CatalogCategory);
  query.equalTo("active", true);
  query.ascending("sortOrder");

  const list = await query.find({ useMasterKey: true });
  return { success: true, categories: list.map(c => ({ id: c.id, ...c.toJSON() })) };
});

// 🗂️ catalogCategoryUpsert: Admin-only category upsert
Parse.Cloud.define("catalogCategoryUpsert", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");

  const params = request.params || {};
  const categoryId = params.categoryId;
  if (!categoryId) throw new Parse.Error(400, "categoryId is required");

  const CatalogCategory = Parse.Object.extend("CatalogCategory");
  const query = new Parse.Query(CatalogCategory);
  query.equalTo("categoryId", categoryId);

  let cat = await query.first({ useMasterKey: true });
  if (!cat) {
    cat = new CatalogCategory();
    cat.set("categoryId", categoryId);
  }

  cat.set("name", params.name || categoryId);
  cat.set("nameAr", params.nameAr || params.name || categoryId);
  cat.set("slug", params.slug || categoryId);
  cat.set("googleCategory", params.googleCategory || "");
  cat.set("fbCategory", params.fbCategory || "");
  cat.set("imageUrl", params.imageUrl || "");
  cat.set("sortOrder", Number(params.sortOrder) || 0);
  cat.set("active", params.active !== false);
  cat.set("scope", params.scope || "global");
  cat.set("creatorUid", auth.uid);
  cat.set("metadata", params.metadata || {});

  await cat.save(null, { useMasterKey: true });
  return { success: true, category: { id: cat.id, ...cat.toJSON() } };
});

// ⚡ catalogPullChanges: Delta synchronization with opaque server cursor
Parse.Cloud.define("catalogPullChanges", async (request) => {
  const params = request.params || {};
  const cursor = (params.cursor || "").trim(); // format: "ISOString_objectId"
  const limit = Math.min(200, Math.max(1, parseInt(params.limit || 100, 10)));

  const auth = await extractAuthUser(request);
  const userUid = auth ? auth.uid : null;

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);

  if (cursor && cursor.includes("_")) {
    const parts = cursor.split("_");
    const cursorDate = new Date(parts[0]);
    const cursorId = parts[1];

    if (!isNaN(cursorDate.getTime())) {
      const dateQuery = new Parse.Query(CatalogProduct);
      dateQuery.greaterThan("updatedAt", cursorDate);

      const tieQuery = new Parse.Query(CatalogProduct);
      tieQuery.equalTo("updatedAt", cursorDate);
      tieQuery.greaterThan("objectId", cursorId);

      const compQuery = Parse.Query.or(dateQuery, tieQuery);
      // Combine with security
      if (!auth || !auth.admin) {
        if (userUid) {
          const gQuery = new Parse.Query(CatalogProduct);
          gQuery.equalTo("scope", "global");
          const oQuery = new Parse.Query(CatalogProduct);
          oQuery.equalTo("creatorUid", userUid);
          compQuery.matchesKeyInQuery("objectId", "objectId", Parse.Query.or(gQuery, oQuery));
        } else {
          compQuery.equalTo("scope", "global");
        }
      }

      compQuery.ascending("updatedAt");
      compQuery.addAscending("objectId");
      compQuery.limit(limit + 1);

      const results = await compQuery.find({ useMasterKey: true });
      const hasMore = results.length > limit;
      const items = hasMore ? results.slice(0, limit) : results;

      let nextCursor = cursor;
      if (items.length > 0) {
        const last = items[items.length - 1];
        nextCursor = `${last.updatedAt.toISOString()}_${last.id}`;
      }

      return {
        success: true,
        items: items.map(p => ({ id: p.id, ...p.toJSON() })),
        nextCursor,
        hasMore
      };
    }
  }

  // Initial pull
  if (!auth || !auth.admin) {
    if (userUid) {
      const gQuery = new Parse.Query(CatalogProduct);
      gQuery.equalTo("scope", "global");
      const oQuery = new Parse.Query(CatalogProduct);
      oQuery.equalTo("creatorUid", userUid);
      const scoped = Parse.Query.or(gQuery, oQuery);
      scoped.ascending("updatedAt");
      scoped.addAscending("objectId");
      scoped.limit(limit + 1);
      const results = await scoped.find({ useMasterKey: true });
      const hasMore = results.length > limit;
      const items = hasMore ? results.slice(0, limit) : results;
      let nextCursor = "";
      if (items.length > 0) {
        const last = items[items.length - 1];
        nextCursor = `${last.updatedAt.toISOString()}_${last.id}`;
      }
      return { success: true, items: items.map(p => ({ id: p.id, ...p.toJSON() })), nextCursor, hasMore };
    } else {
      query.equalTo("scope", "global");
    }
  }

  query.ascending("updatedAt");
  query.addAscending("objectId");
  query.limit(limit + 1);

  const results = await query.find({ useMasterKey: true });
  const hasMore = results.length > limit;
  const items = hasMore ? results.slice(0, limit) : results;

  let nextCursor = "";
  if (items.length > 0) {
    const last = items[items.length - 1];
    nextCursor = `${last.updatedAt.toISOString()}_${last.id}`;
  }

  return {
    success: true,
    items: items.map(p => ({ id: p.id, ...p.toJSON() })),
    nextCursor,
    hasMore
  };
});

// 🚀 catalogImportBatch: ADMIN-ONLY Idempotent Batch Migration Engine
Parse.Cloud.define("catalogImportBatch", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) {
    throw new Parse.Error(403, "Forbidden: catalogImportBatch is strictly restricted to authorized administrators");
  }

  const params = request.params || {};
  const products = Array.isArray(params.products) ? params.products : [];
  if (products.length === 0) {
    return { success: true, products_seen: 0, products_created: 0, products_updated: 0, media_created: 0, media_skipped: 0 };
  }

  let productsCreated = 0;
  let productsUpdated = 0;
  let mediaCreated = 0;
  let mediaSkipped = 0;
  const errors = [];

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");

  for (const item of products) {
    try {
      const pid = (item.productId || item.id || "").trim();
      if (!pid) {
        errors.push({ error: "Missing productId", item });
        continue;
      }

      // 1. Find existing or create new
      const pQuery = new Parse.Query(CatalogProduct);
      pQuery.equalTo("productId", pid);
      let product = await pQuery.first({ useMasterKey: true });

      const isNew = !product;
      if (!product) {
        product = new CatalogProduct();
        product.set("productId", pid);
        product.set("syncVersion", 1);
        productsCreated++;
      } else {
        product.set("syncVersion", (product.get("syncVersion") || 1) + 1);
        productsUpdated++;
      }

      const now = new Date();
      product.set("retailerId", item.retailerId || pid);
      product.set("originalCatalogId", item.originalCatalogId || "");
      product.set("title", item.title || "");
      product.set("description", item.description || "");
      product.set("availability", item.availability || "in stock");
      product.set("condition", item.condition || "new");
      product.set("price", Number(item.price) || 0.0);
      product.set("currency", item.currency || "YER");
      product.set("link", normalizeProductLink(item.link, pid));
      product.set("imageLink", item.imageLink || "");
      product.set("additionalImageLinks", Array.isArray(item.additionalImageLinks) ? item.additionalImageLinks : []);
      product.set("videoUrl", item.videoUrl || null);
      product.set("brand", item.brand || null);
      product.set("googleProductCategory", item.googleProductCategory || null);
      product.set("fbProductCategory", item.fbProductCategory || null);
      product.set("categoryId", item.categoryId || null);
      product.set("categoryName", item.categoryName || null);
      product.set("metaProductType", item.metaProductType || null);
      product.set("quantity", Number(item.quantity) || 1);
      product.set("salePrice", item.salePrice != null ? Number(item.salePrice) : null);
      product.set("salePriceEffectiveDate", item.salePriceEffectiveDate || null);
      product.set("itemGroupId", item.itemGroupId || null);
      product.set("gender", item.gender || null);
      product.set("color", item.color || null);
      product.set("size", item.size || null);
      product.set("ageGroup", item.ageGroup || null);
      product.set("material", item.material || null);
      product.set("pattern", item.pattern || null);
      product.set("shipping", item.shipping || null);
      product.set("shippingWeight", item.shippingWeight || null);
      product.set("gtin", item.gtin || null);
      product.set("productTags", Array.isArray(item.productTags) ? item.productTags : []);
      product.set("style", item.style || null);
      product.set("creatorUid", item.creatorUid || "system_import");
      product.set("status", item.status || "approved");
      product.set("scope", item.scope || "global");
      product.set("source", item.source || "excel");
      product.set("schemaVersion", 1);
      product.set("clientUpdatedAt", now);
      product.set("lastSyncedAt", now);

      await product.save(null, { useMasterKey: true });

      // 2. Process Media list
      const mediaList = Array.isArray(item.media) ? item.media : [];
      for (const m of mediaList) {
        const mUrl = (m.url || "").trim();
        if (!mUrl) continue;
        const mType = m.type || "image";
        const dedupeKey = computeMediaDedupeKey(pid, mType, mUrl);

        const mQuery = new Parse.Query(CatalogProductMedia);
        mQuery.equalTo("dedupeKey", dedupeKey);
        const existingMedia = await mQuery.first({ useMasterKey: true });

        if (!existingMedia) {
          const newMedia = new CatalogProductMedia();
          newMedia.set("dedupeKey", dedupeKey);
          newMedia.set("product", product);
          newMedia.set("productId", pid);
          newMedia.set("type", mType);
          newMedia.set("url", mUrl);
          newMedia.set("thumbnailUrl", m.thumbnailUrl || mUrl);
          newMedia.set("mimeType", m.mimeType || (mType === "video" ? "video/mp4" : "image/jpeg"));
          newMedia.set("filename", m.filename || null);
          newMedia.set("sortOrder", Number(m.sortOrder) || 0);
          newMedia.set("isPrimary", Boolean(m.isPrimary));
          newMedia.set("source", item.source || "excel");
          newMedia.set("status", "active");
          newMedia.set("width", Number(m.width) || null);
          newMedia.set("height", Number(m.height) || null);
          newMedia.set("durationMs", Number(m.durationMs) || null);
          newMedia.set("metadata", m.metadata || {});
          await newMedia.save(null, { useMasterKey: true });
          mediaCreated++;
        } else {
          mediaSkipped++;
        }
      }
    } catch (err) {
      errors.push({ error: err.message || String(err), productId: item.productId });
    }
  }

  return {
    success: true,
    products_seen: products.length,
    products_created: productsCreated,
    products_updated: productsUpdated,
    media_created: mediaCreated,
    media_skipped: mediaSkipped,
    errors
  };
});

// 📊 catalogGetSchemaStatus: Live Diagnostic Verification Function
Parse.Cloud.define("catalogGetSchemaStatus", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const CatalogCategory = Parse.Object.extend("CatalogCategory");
  const CatalogSyncState = Parse.Object.extend("CatalogSyncState");
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");

  const [productCount, mediaCount, categoryCount, syncCount, logCount] = await Promise.all([
    new Parse.Query(CatalogProduct).count({ useMasterKey: true }),
    new Parse.Query(CatalogProductMedia).count({ useMasterKey: true }),
    new Parse.Query(CatalogCategory).count({ useMasterKey: true }),
    new Parse.Query(CatalogSyncState).count({ useMasterKey: true }),
    new Parse.Query(CatalogChangeLog).count({ useMasterKey: true })
  ]);

  // Count image vs video
  const imageCount = await new Parse.Query(CatalogProductMedia).equalTo("type", "image").count({ useMasterKey: true });
  const videoCount = await new Parse.Query(CatalogProductMedia).equalTo("type", "video").count({ useMasterKey: true });

  return {
    success: true,
    counts: {
      CatalogProduct: productCount,
      CatalogProductMedia: mediaCount,
      CatalogProductMedia_images: imageCount,
      CatalogProductMedia_videos: videoCount,
      CatalogCategory: categoryCount,
      CatalogSyncState: syncCount,
      CatalogChangeLog: logCount
    }
  };
});

// 🛠️ catalogBootstrap: Server-side schema & CLP initialization endpoint
Parse.Cloud.define("catalogBootstrap", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");
  const result = await bootstrapCatalogSchemas();
  return { success: true, bootstrap: result };
});

module.exports = {
  bootstrapCatalogSchemas,
  computeMediaDedupeKey,
  normalizeProductLink,
  verifyFirebaseIdToken
};
