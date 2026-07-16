import { i as formatPrice, n as STORE_CONTACT, t as CURRENCY } from "./store-data-zIacan09.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/whatsapp-6pYW6j0-.js
function buildOrderMessage(items, total, customer) {
	const lines = [];
	lines.push("🧾 *طلب جديد من اندكس ستور*");
	lines.push("");
	items.forEach((it, idx) => {
		lines.push(`${idx + 1}. ${it.name}`);
		lines.push(`   الكمية: ${it.qty} × ${it.price.toLocaleString("ar-EG")} ${CURRENCY}`);
		lines.push(`   الإجمالي: ${(it.qty * it.price).toLocaleString("ar-EG")} ${CURRENCY}`);
		lines.push("");
	});
	lines.push(`💰 *الإجمالي الكلي:* ${total.toLocaleString("ar-EG")} ${CURRENCY}`);
	lines.push("");
	if (customer?.name) lines.push(`👤 الاسم: ${customer.name}`);
	if (customer?.phone) lines.push(`📞 الهاتف: ${customer.phone}`);
	if (customer?.address) lines.push(`📍 العنوان: ${customer.address}`);
	if (customer?.notes) lines.push(`📝 ملاحظات: ${customer.notes}`);
	lines.push("");
	lines.push("💳 طريقة الدفع: الدفع عند الاستلام");
	return lines.join("\n");
}
function whatsappLink(message, phone = STORE_CONTACT) {
	return `https://wa.me/${phone.startsWith("+") ? phone.slice(1) : `967${phone}`}?text=${encodeURIComponent(message)}`;
}
/** Quick single-product order link matching the exact brand template. */
function quickOrderLink(product, phone = STORE_CONTACT) {
	const normalized = phone.startsWith("+") ? phone.slice(1) : `967${phone}`;
	const text = `مرحباً، أريد طلب ${product.name} بسعر ${formatPrice(product.price)}`;
	return `https://wa.me/${normalized}?text=${encodeURIComponent(text)}`;
}
//#endregion
export { quickOrderLink as n, whatsappLink as r, buildOrderMessage as t };
