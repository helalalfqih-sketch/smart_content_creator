import { r as HTTPResponse } from "../_libs/h3+rou3+srvx.mjs";
//#region #nitro/virtual/renderer-template
var rendererTemplate = () => new HTTPResponse("<!DOCTYPE html>\r\n<html lang=\"ar\" dir=\"rtl\">\r\n\r\n<head>\r\n  <meta charset=\"UTF-8\">\r\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\r\n  <meta name=\"tiktok-developers-site-verification\" content=\"8EIh0gTFBJvtQX1l3pDMLW2v9QZ4cEfJ\" />\r\n  <meta content=\"IE=Edge\" http-equiv=\"X-UA-Compatible\">\r\n  <meta name=\"description\" content=\"Smart Content Creator - صانع المحتوى الذكي\">\r\n  <!-- 🔑 Google Sign-In Web Client ID -->\r\n  <meta name=\"google-signin-client_id\" content=\"947880578188-hnd32gc8c9f3n6u22nl95bsumjq1em7e.apps.googleusercontent.com\">\r\n\r\n  <!-- Favicon -->\r\n  <link rel=\"icon\" type=\"image/png\" href=\"/favicon.png\" />\r\n  <link rel=\"manifest\" href=\"/manifest.json\">\r\n\r\n  <title>Smart Content Creator - صانع المحتوى الذكي</title>\r\n\r\n  <style>\r\n    html, body, #root {\r\n      margin: 0;\r\n      padding: 0;\r\n      min-height: 100vh;\r\n      background-color: #F8F9FF;\r\n      font-family: 'Tajawal', 'IBMPlexSansArabic', sans-serif;\r\n    }\r\n  </style>\r\n</head>\r\n\r\n<body>\r\n  <div id=\"root\"></div>\r\n</body>\r\n\r\n</html>", { headers: { "content-type": "text/html; charset=utf-8" } });
//#endregion
//#region node_modules/nitro/dist/runtime/internal/routes/renderer-template.mjs
function renderIndexHTML(event) {
	return rendererTemplate(event.req);
}
//#endregion
export { renderIndexHTML as default };
