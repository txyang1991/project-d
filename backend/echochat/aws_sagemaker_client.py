# aws_sagemaker_client.py
"""
Thin wrapper around AWS SageMaker Runtime InvokeEndpoint for use from GCP Cloud Run.

Reads configuration from environment variables:
  - AWS_REGION (or AWS_DEFAULT_REGION)       e.g. "us-west-1"
  - AWS_SAGEMAKER_ENDPOINT_NAME              e.g. "flan-t5-sft-1756315716"
  - AWS_ACCESS_KEY_ID                        (do NOT hardcode; use secrets)
  - AWS_SECRET_ACCESS_KEY                    (do NOT hardcode; use secrets)
  - AWS_SESSION_TOKEN                        (optional; for temporary creds)

Usage:
    from aws_sagemaker_client import generate_text
    text = generate_text("Paraphrase: Hello there, how are you?")
"""

import json
import os
from typing import Any, Dict, Optional, Union

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError


_JSON = Union[Dict[str, Any], Any]


def _make_client():
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
    if not region:
        raise RuntimeError("Missing AWS_REGION (or AWS_DEFAULT_REGION) env var.")
    # boto3 will automatically pick up env credentials (and also supports
    # secrets mounted as env vars in Cloud Run).
    return boto3.client(
        "sagemaker-runtime",
        region_name=region,
        config=Config(retries={"max_attempts": 3, "mode": "standard"}),
    )


def _extract_text(obj: _JSON) -> str:
    """
    Try to pull the generated text out of common SageMaker/HF response shapes.
    Falls back to a compact JSON string if structure is unknown.
    """
    if isinstance(obj, str):
        return obj

    if isinstance(obj, dict):
        for key in ("generated_text", "text", "output_text", "answer"):
            val = obj.get(key)
            if isinstance(val, str):
                return val
            if isinstance(val, list) and val and isinstance(val[0], str):
                return val[0]

        # Some HF containers return {"outputs": "..."} or {"outputs": ["..."]}
        val = obj.get("outputs")
        if isinstance(val, str):
            return val
        if isinstance(val, list) and val and isinstance(val[0], str):
            return val[0]

    if isinstance(obj, list) and obj:
        # Common HF response: [{"generated_text": "..."}]
        return _extract_text(obj[0])

    # Unknown shape — return a compact preview
    try:
        return json.dumps(obj, ensure_ascii=False)[:1000]
    except Exception:
        return str(obj)[:1000]


def generate_text(
    prompt: str,
    *,
    parameters: Optional[Dict[str, Any]] = None,
    endpoint_name: Optional[str] = None,
) -> str:
    """
    Invoke a SageMaker endpoint with a simple text prompt.

    :param prompt: Your input prompt (e.g., "Paraphrase: ...")
    :param parameters: Optional inference params (e.g., {"max_new_tokens": 128})
    :param endpoint_name: Optional override for endpoint name.
    :return: Extracted text from the model response.
    :raises RuntimeError: on network/auth/service errors with a concise message.
    """
    ep = endpoint_name or os.getenv("AWS_SAGEMAKER_ENDPOINT_NAME")
    if not ep:
        raise RuntimeError("Missing AWS_SAGEMAKER_ENDPOINT_NAME env var.")

    payload: Dict[str, Any] = {"inputs": prompt}
    if parameters:
        payload["parameters"] = parameters

    body = json.dumps(payload).encode("utf-8")

    client = _make_client()

    try:
        resp = client.invoke_endpoint(
            EndpointName=ep,
            ContentType="application/json",
            Accept="application/json",
            Body=body,
        )
        raw = resp["Body"].read()
        # Body is bytes -> parse JSON; some containers return JSON lines; handle both.
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            # Try to split JSON lines (DJL Serving sometimes streams JSONL)
            lines = [l for l in raw.decode("utf-8", "ignore").splitlines() if l.strip()]
            if len(lines) == 1:
                parsed = json.loads(lines[0])
            else:
                # best effort: parse first JSON-looking line
                for l in lines:
                    try:
                        parsed = json.loads(l)
                        break
                    except Exception:
                        continue
                else:
                    parsed = {"outputs": raw.decode("utf-8", "ignore")}
        return _extract_text(parsed)

    except (ClientError, BotoCoreError) as e:
        # Present a short, actionable message to the caller
        msg = getattr(e, "response", {}).get("Error", {}).get("Message") or str(e)
        raise RuntimeError(f"SageMaker invoke failed: {msg}") from e
