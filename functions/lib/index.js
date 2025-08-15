"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.echoChat = void 0;
const https_1 = require("firebase-functions/v2/https");
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-admin/firestore");
(0, app_1.initializeApp)();
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
exports.echoChat = (0, https_1.onRequest)({ region: "us-central1" }, async (req, res) => {
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
        // 2) reply (echo)
        const reply = `Yes, copy message [${text}]`;
        // 3) assistant message
        const replyDoc = await messagesCol.add({
            role: "assistant",
            text: reply,
            ts: firestore_1.FieldValue.serverTimestamp(),
            replyTo: userDoc.id,
            source: "echoChat-fn",
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