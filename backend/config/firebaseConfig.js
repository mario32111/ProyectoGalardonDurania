var admin = require("firebase-admin");
var serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT) : require("../firebase-service-account.json");

try {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log("🔥 Firebase initialized successfully");
} catch (error) {
    if (!admin.apps.length) {
        console.error("❌ Error initializing Firebase:", error);
    } else {
        console.log("🔥 Firebase already initialized");
    }
}

const db = admin.firestore();

module.exports = { admin, db };
