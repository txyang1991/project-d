# main.py
import os
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
import firebase_admin
from firebase_admin import auth as fb_auth, firestore
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from aws_sagemaker_client import generate_text

app = FastAPI()

# Initialize Firebase Admin (uses Cloud Run service account by default)
if not firebase_admin._apps:
    firebase_admin.initialize_app()

db = firestore.client()

class ChatIn(BaseModel):
    text: str

@app.post("/echoChat")
def echo_chat(request: Request, body: ChatIn):
    # 1) Read Firebase ID token
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization: Bearer <token>")
    id_token = auth_header.split(" ", 1)[1].strip()

    # 2) Verify token
    try:
        decoded = fb_auth.verify_id_token(id_token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Firebase ID token")

    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Token missing uid")

    # 3) Validate input
    text = (body.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="text required")

    # 4) Firestore writes (same shape as before)
    messages = db.collection("users").document(uid).collection("messages")

    _, user_ref = messages.add({
        "role": "user",
        "text": text,
        "ts": SERVER_TIMESTAMP,
        "source": "client",
    })

    # Call AWS SageMaker endpoint. Adjust parameters as you like.
    try:
        reply = generate_text(
            text,
            parameters={
                "max_new_tokens": 128,
                "temperature": 0.2,
                "do_sample": False
            },
        )
    except Exception as e:
        # Surface a clean 502 to the client; still log the error for debugging.
        # (In production you may prefer structured logging.)
        raise HTTPException(status_code=502, detail=f"AWS inference error: {e}")


    _, reply_ref = messages.add({
        "role": "assistant",
        "text": reply,
        "ts": SERVER_TIMESTAMP,
        "replyTo": user_ref.id,
        "source": "cloud-run-python",
    })

    return {
        "reply": reply,
        "userMessageId": user_ref.id,
        "replyMessageId": reply_ref.id,
    }
 