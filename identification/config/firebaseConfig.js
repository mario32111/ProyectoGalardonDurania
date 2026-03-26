var admin = require("firebase-admin");
var path = require("path");
// Reuse the service account from the backend folder
var serviceAccountPath = path.join(__dirname, "../../backend/firebase-service-account.json");
var serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT) : require(serviceAccountPath);

try {
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        console.log("🔥 Firebase initialized successfully in Identification module");
    } else {
        console.log("🔥 Firebase already initialized in Identification module");
    }
} catch (error) {
    console.error("❌ Error initializing Firebase in Identification module:", error);
}

const db = admin.firestore();

module.exports = { admin, db };
