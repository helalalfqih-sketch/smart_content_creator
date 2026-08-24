# خطة المعالجة المقترحة

لا تنفيذ ضمن التدقيق.

1. إغلاق Firestore role escalation/read-all وStorage wildcard، تدوير الأسرار، حماية endpoints، وإزالة debug App Check من release.
2. نقل OAuth exchanges للخادم، state/PKCE، CSPRNG/rate limits/transactions، وتنقيح logs.
3. معاملات/idempotency للكتالوج والوسائط، outbox/backoff، parameterized SQL، foreign keys، وإصلاح sizeBytes.
4. CI gates: analyze + hermetic tests + secret/rules tests قبل release؛ فصل live tests.
5. iOS permissions/deep links، signing fail-closed، تعطيل cleartext، R8/shrink، identifiers.
6. lazy/cache-first pagination، memoized filters، comparator ثابت، ونتائج bulk per-item.
7. dispose للWorkers/subscriptions/controllers.
8. تفكيك mega screens/controllers بعد characterization tests.
9. إزالة artifacts/deps/mocks فقط بعد إثبات الاستخدام.
10. runtime verification على emulators/staging دون production writes.

أعلى مخاطر الإصلاح: rules/secrets/App Check/pagination لأنها قد تقطع عملاء حاليين؛ يلزم rollout وrollback.
