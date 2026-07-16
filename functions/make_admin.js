const admin = require("firebase-admin");

admin.initializeApp();
const auth = admin.auth();
const db = admin.firestore();

async function createAdmin() {
  const email = "helalalfqih@gmail.com";
  const password = "6508.6508";

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log("User already exists:", userRecord.uid);
    // Optionally update password if needed, but not strictly necessary if they already know it
    await auth.updateUser(userRecord.uid, { password: password });
    console.log("Password updated.");
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email: email,
        password: password,
      });
      console.log("Created new user:", userRecord.uid);
    } else {
      throw e;
    }
  }

  await db.collection("users").doc(userRecord.uid).set({
    email: email,
    role: "admin",
    firestore_role: "admin",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log("Successfully made user admin in Firestore.");
}

createAdmin().catch(console.error);
