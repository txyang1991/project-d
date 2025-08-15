import {onRequest} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

initializeApp();

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
export const echoChat = onRequest({region: "us-central1"}, async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).json({error: "Use POST"});
      return;
    }

    const header = req.headers.authorization || "";
    const match = header.match(/^Bearer (.+)$/i);
    if (!match) {
      res
        .status(401)
        .json({error: "Missing Authorization: Bearer <token>"});
      return;
    }

    const idToken = match[1];
    const decoded = await getAuth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const raw = (req.body?.text ?? "") as string;
    const text = typeof raw === "string" ? raw.trim() : "";
    if (!text) {
      res.status(400).json({error: "text required"});
      return;
    }

    const db = getFirestore();
    const messagesCol = db
      .collection("users")
      .doc(uid)
      .collection("messages");

    // 1) user message
    const userDoc = await messagesCol.add({
      role: "user",
      text,
      ts: FieldValue.serverTimestamp(),
      source: "client",
    });

    // 2) reply (echo)
    const reply = `Yes, copy message [${text}]`;

    // 3) assistant message
    const replyDoc = await messagesCol.add({
      role: "assistant",
      text: reply,
      ts: FieldValue.serverTimestamp(),
      replyTo: userDoc.id,
      source: "echoChat-fn",
    });

    // 4) response to client
    res.status(200).json({
      reply,
      userMessageId: userDoc.id,
      replyMessageId: replyDoc.id,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Internal error";
    console.error(e);
    res.status(500).json({error: msg});
  }
});
