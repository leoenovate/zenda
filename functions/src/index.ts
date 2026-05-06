import * as admin from "firebase-admin";

admin.initializeApp();

// Authentication is handled directly in Firestore by the Flutter app.
// No Cloud Functions are needed to manage identities or role claims.
export {};
