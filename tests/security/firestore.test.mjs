import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, deleteField, doc, getDoc, getDocs, increment, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;
const profile = () => ({
  email: 'alice@example.test', name: 'Alice', role: 'user', isPremium: false,
  visualAnalysisCount: 0, credits: 50, is_trial_active: true,
  is_ai_blocked: false, ai_backend: 'firebase_ai', newUserNotification: true,
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(), last_credit_reset: serverTimestamp(),
});
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-scc-security',
    firestore: { host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    await setDoc(doc(store, 'users/alice'), profile());
    await setDoc(doc(store, 'users/bob'), { ...profile(), email: 'bob@example.test' });
    await setDoc(doc(store, 'users/admin'), { ...profile(), role: 'admin' });
    await setDoc(doc(store, 'users/bob/chats/private'), { text: 'private' });
  });
});
after(async () => { await env?.cleanup(); });

test('anonymous clients cannot read private profiles', async () => {
  await assertFails(getDoc(doc(db(), 'users/alice')));
});
test('an owner can read and edit profile fields', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(updateDoc(ref, { name: 'Updated', bio: 'Creator', creator_stats: { posts: 1 } }));
});
test('other users cannot read or list private profiles', async () => {
  await assertFails(getDoc(doc(db('alice'), 'users/bob')));
  await assertFails(getDocs(collection(db('alice'), 'users')));
});
test('admin can list and manage accounts', async () => {
  await assertSucceeds(getDocs(collection(db('admin'), 'users')));
  await assertSucceeds(updateDoc(doc(db('admin'), 'users/bob'), { role: 'admin', credits: 200 }));
});
test('new account can be created with the application defaults', async () => {
  await assertSucceeds(setDoc(doc(db('new-user'), 'users/new-user'), profile()));
});
test('new account cannot grant itself administrator privileges or paid benefits', async () => {
  for (const change of [{ role: 'admin' }, { isPremium: true }, { credits: 5000 }, { subscription: { status: 'active' } }, { permissions: { admin: true } }]) {
    await assertFails(setDoc(doc(db('new-user'), 'users/new-user'), { ...profile(), ...change }));
  }
});
test('owner cannot promote themselves, remove role, or replace a profile with admin data', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertFails(updateDoc(ref, { role: 'admin' }));
  await assertFails(updateDoc(ref, { role: deleteField() }));
  await assertFails(setDoc(ref, { ...profile(), role: 'admin' }));
});
test('owner cannot mint credits, buy premium, or override AI access policy', async () => {
  for (const change of [{ credits: 999 }, { isPremium: true }, { ai_backend: 'manus' }, { is_ai_blocked: true }, { subscription: { status: 'active' } }, { permissions: { admin: true } }, { unknownPrivilege: true }]) {
    await assertFails(updateDoc(doc(db('alice'), 'users/alice'), change));
  }
});
test('owner cannot delete and recreate their account to refill credits', async () => {
  await assertFails(deleteDoc(doc(db('alice'), 'users/alice')));
});
test('analysis counter can advance by one but cannot reset or decrement', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertSucceeds(updateDoc(ref, { visualAnalysisCount: increment(1) }));
  await assertFails(updateDoc(ref, { visualAnalysisCount: 0 }));
  await assertFails(updateDoc(ref, { visualAnalysisCount: -1 }));
  await assertFails(updateDoc(ref, { visualAnalysisCount: deleteField() }));
  await assertFails(updateDoc(ref, { visualAnalysisCount: 2.5 }));
});
test('owner can still sync private provider settings and social profile data', async () => {
  await assertSucceeds(updateDoc(doc(db('alice'), 'users/alice'), {
    tiktok_connected: true, tiktok_profile: { display_name: 'Alice' },
    user_api_keys: { testProvider: 'dummy-test-value' },
    instagram_connected: false, brand_identity: { name: 'Studio' },
  }));
  await assertFails(getDoc(doc(db('bob'), 'users/alice')));
});
test('private chat subcollections remain isolated while owner access works', async () => {
  await assertFails(getDoc(doc(db('alice'), 'users/bob/chats/private')));
  await assertFails(setDoc(doc(db('alice'), 'users/bob/chats/injected'), { text: 'bad' }));
  await assertSucceeds(setDoc(doc(db('alice'), 'users/alice/chats/own'), { text: 'hello' }));
});
