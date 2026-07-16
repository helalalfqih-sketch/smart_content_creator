//#region node_modules/.nitro/vite/services/ssr/assets/store-data-zIacan09.js
var STORE_CONTACT = "771370740";
var CURRENCY = "ر.ي";
var categories = [
	{
		id: "cars",
		name: "قطع سيارات",
		icon: "Car",
		color: "from-blue-500 to-blue-700"
	},
	{
		id: "fashion",
		name: "أزياء",
		icon: "Shirt",
		color: "from-pink-500 to-rose-600"
	},
	{
		id: "home",
		name: "أدوات منزلية",
		icon: "Home",
		color: "from-amber-500 to-orange-600"
	},
	{
		id: "electronics",
		name: "إلكترونيات",
		icon: "Smartphone",
		color: "from-indigo-500 to-purple-600"
	},
	{
		id: "beauty",
		name: "العناية والجمال",
		icon: "Sparkles",
		color: "from-fuchsia-500 to-pink-600"
	},
	{
		id: "kids",
		name: "أطفال",
		icon: "Baby",
		color: "from-cyan-500 to-teal-600"
	},
	{
		id: "grocery",
		name: "بقالة",
		icon: "ShoppingBasket",
		color: "from-emerald-500 to-green-600"
	},
	{
		id: "tools",
		name: "عدد وأدوات",
		icon: "Wrench",
		color: "from-slate-500 to-slate-700"
	}
];
var img = (seed) => `https://images.unsplash.com/${seed}?auto=format&fit=crop&w=800&q=70`;
var products = [
	{
		id: "p1",
		slug: "wireless-earbuds-pro",
		name: "سماعات لاسلكية Pro",
		description: "سماعات بلوتوث بجودة صوت عالية، عزل ضوضاء، بطارية تدوم 24 ساعة.",
		price: 12500,
		oldPrice: 16e3,
		stock: 34,
		image: img("photo-1590658268037-6bf12165a8df"),
		rating: 4.7,
		reviews: 128,
		categoryId: "electronics",
		badge: "الأكثر مبيعاً"
	},
	{
		id: "p2",
		slug: "smart-watch-x",
		name: "ساعة ذكية X-Series",
		description: "ساعة ذكية بشاشة AMOLED، تتبع اللياقة، مقاومة للماء.",
		price: 18900,
		oldPrice: 24e3,
		stock: 12,
		image: img("photo-1523275335684-37898b6baf30"),
		rating: 4.6,
		reviews: 96,
		categoryId: "electronics",
		badge: "خصم 21%"
	},
	{
		id: "p3",
		slug: "car-vacuum",
		name: "مكنسة سيارة محمولة",
		description: "شفط قوي 120 واط، خفيفة، سهلة الاستخدام لتنظيف السيارة.",
		price: 6800,
		stock: 45,
		image: img("photo-1607853202273-797f1c22a38e"),
		rating: 4.4,
		reviews: 54,
		categoryId: "cars"
	},
	{
		id: "p4",
		slug: "kitchen-blender",
		name: "خلاط كهربائي احترافي",
		description: "خلاط 1000 واط بشفرات فولاذية، مناسب للعصير والطحن.",
		price: 9500,
		oldPrice: 11500,
		stock: 20,
		image: img("photo-1570222094114-d054a817e56b"),
		rating: 4.5,
		reviews: 71,
		categoryId: "home",
		badge: "عرض اليوم"
	},
	{
		id: "p5",
		slug: "mens-jacket",
		name: "جاكيت رجالي شتوي",
		description: "جاكيت أنيق مقاوم للبرد، متوفر بمقاسات متعددة.",
		price: 14200,
		stock: 18,
		image: img("photo-1551028719-00167b16eac5"),
		rating: 4.3,
		reviews: 32,
		categoryId: "fashion"
	},
	{
		id: "p6",
		slug: "kids-toy-car",
		name: "سيارة أطفال بريموت",
		description: "سيارة قابلة للشحن مع جهاز تحكم عن بعد وأضواء.",
		price: 8700,
		stock: 27,
		image: img("photo-1558877385-8c1c72237c2c"),
		rating: 4.8,
		reviews: 44,
		categoryId: "kids",
		badge: "جديد"
	},
	{
		id: "p7",
		slug: "beauty-serum",
		name: "سيروم مرطب للبشرة",
		description: "سيروم فيتامين C لتفتيح البشرة وترطيبها.",
		price: 4500,
		oldPrice: 6e3,
		stock: 60,
		image: img("photo-1556228578-8c89e6adf883"),
		rating: 4.6,
		reviews: 89,
		categoryId: "beauty",
		badge: "خصم"
	},
	{
		id: "p8",
		slug: "power-drill",
		name: "مثقاب كهربائي 18V",
		description: "مثقاب قوي مع بطارية قابلة للشحن ومجموعة رؤوس.",
		price: 22e3,
		stock: 9,
		image: img("photo-1504148455328-c376907d081c"),
		rating: 4.7,
		reviews: 38,
		categoryId: "tools"
	}
];
var formatPrice = (n) => new Intl.NumberFormat("ar-EG", { maximumFractionDigits: 0 }).format(n) + " ر.ي";
//#endregion
export { products as a, formatPrice as i, STORE_CONTACT as n, categories as r, CURRENCY as t };
