"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.echoChat = void 0;
const https_1 = require("firebase-functions/v2/https");
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-admin/firestore");
const aiplatform_1 = require("@google-cloud/aiplatform");
(0, app_1.initializeApp)();
// ---- CONFIG ----
const PROJECT_ID = process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    process.env.PROJECT_ID ||
    "project-d-start-of-everything";
// 2nd-gen Functions set GOOGLE_CLOUD_REGION. Fall back to your deploy region.
const LOCATION = process.env.GOOGLE_CLOUD_REGION ||
    process.env.FUNCTION_REGION ||
    "us-central1";
// MUST be the numeric endpoint id from Vertex AI → Endpoints page
const ENDPOINT_ID = process.env.VERTEX_ENDPOINT_ID || "";
// Validate early so errors are obvious in logs
if (!/^[a-z]+-[a-z]+[0-9]$/.test(LOCATION)) {
    console.error(`Bad region in LOCATION: "${LOCATION}"`);
}
if (!/^\d+$/.test(ENDPOINT_ID)) {
    console.error(`VERTEX_ENDPOINT_ID must be the numeric id, got "${ENDPOINT_ID}". ` +
        "Find it in Console → Vertex AI → Endpoints (ID column).");
}
const VERTEX_ENDPOINT = `projects/${PROJECT_ID}/locations/${LOCATION}/endpoints/${ENDPOINT_ID}`;
const predictionClient = new aiplatform_1.PredictionServiceClient({
    apiEndpoint: `${LOCATION}-aiplatform.googleapis.com`,
});
/**
 * Calls the Vertex AI endpoint to get a prediction for the given text.
 * @param {string} text The input text to send to the model.
 * @return {Promise<string>} A promise that resolves with the model's
 * prediction as a formatted string.
 */
async function callVertex(text) {
    var _a, _b, _c;
    try {
        const instance = { content: text }; // adjust to your model signature
        const [response] = await predictionClient.predict({
            endpoint: VERTEX_ENDPOINT,
            // cast to the expected proto shape without losing type-safety
            instances: [instance],
            parameters: {},
        });
        const preds = ((_a = response.predictions) !== null && _a !== void 0 ? _a : []);
        if (!preds.length)
            return "(no prediction)";
        const p = preds[0];
        if (Array.isArray(p.displayNames) &&
            (Array.isArray(p.confidences) || Array.isArray(p.scores))) {
            const scores = ((_b = p.confidences) !== null && _b !== void 0 ? _b : p.scores);
            const pairs = p.displayNames.map((name, i) => { var _a; return [name, (_a = scores === null || scores === void 0 ? void 0 : scores[i]) !== null && _a !== void 0 ? _a : null]; });
            const [topName, topScore] = (_c = pairs.sort((a, b) => { var _a, _b; return ((_a = b[1]) !== null && _a !== void 0 ? _a : 0) - ((_b = a[1]) !== null && _b !== void 0 ? _b : 0); })[0]) !== null && _c !== void 0 ? _c : ["(unknown)", null];
            return topScore != null ?
                `${topName} (${(topScore * 100).toFixed(1)}%)` : topName;
        }
        return JSON.stringify(p);
    }
    catch (err) {
        if (err instanceof Error) {
            console.error("Vertex predict() failed", {
                message: err.message,
                stack: err.stack,
                endpoint: VERTEX_ENDPOINT,
            });
            throw err;
        }
        console.error("Vertex predict() failed (non-Error)", { err });
        throw new Error("Vertex predict() failed");
    }
}
/**
 * POST /echoChat
 * Body: { text: string }
 * Auth: Firebase ID token in:
 *   Authorization: Bearer <token>
 *
 * Writes:
 *  /users/{uid}/messages/{autoId}
 *    role=user, text, ts, source="client"
 *  /users/{uid}/messages/{autoId}
 *    role=assistant, text=echo, ts,
 *    replyTo=<userDocId>, source="echoChat-fn"
 *
 * Returns:
 *  { reply, userMessageId, replyMessageId }
 */
exports.echoChat = (0, https_1.onRequest)({ region: "us-central1", memory: "512MiB" }, async (req, res) => {
    var _a, _b;
    try {
        if (req.method !== "POST") {
            res.status(405).json({ error: "Use POST" });
            return;
        }
        const header = req.headers.authorization || "";
        const match = header.match(/^Bearer (.+)$/i);
        if (!match) {
            res
                .status(401)
                .json({ error: "Missing Authorization: Bearer <token>" });
            return;
        }
        const idToken = match[1];
        const decoded = await (0, auth_1.getAuth)().verifyIdToken(idToken);
        const uid = decoded.uid;
        const raw = ((_b = (_a = req.body) === null || _a === void 0 ? void 0 : _a.text) !== null && _b !== void 0 ? _b : "");
        const text = typeof raw === "string" ? raw.trim() : "";
        if (!text) {
            res.status(400).json({ error: "text required" });
            return;
        }
        const db = (0, firestore_1.getFirestore)();
        const messagesCol = db
            .collection("users")
            .doc(uid)
            .collection("messages");
        // 1) user message
        const userDoc = await messagesCol.add({
            role: "user",
            text,
            ts: firestore_1.FieldValue.serverTimestamp(),
            source: "client",
        });
        // 2) reply (Vertex AI)
        const reply = await callVertex(text);
        // 3) assistant message
        const replyDoc = await messagesCol.add({
            role: "assistant",
            text: reply,
            ts: firestore_1.FieldValue.serverTimestamp(),
            replyTo: userDoc.id,
            source: "vertex-ai",
            meta: {
                projectId: PROJECT_ID,
                location: LOCATION,
                endpointId: ENDPOINT_ID,
            },
        });
        // 4) response to client
        res.status(200).json({
            reply,
            userMessageId: userDoc.id,
            replyMessageId: replyDoc.id,
        });
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : "Internal error";
        console.error(e);
        res.status(500).json({ error: msg });
    }
});
//# sourceMappingURL=index.js.map