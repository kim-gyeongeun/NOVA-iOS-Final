"""NOVA local bridge: server-side secrets; no keys are embedded in the iOS app.

Run on your trusted computer/network only. Not hardened for public deployment.
"""
from __future__ import annotations

import base64
import binascii
import os
import time
from typing import Literal

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator

load_dotenv()
app = FastAPI(title="NOVA AI Bridge", version="1.0")
PROVIDERS = {"openai": "OPENAI_API_KEY", "anthropic": "ANTHROPIC_API_KEY", "gemini": "GEMINI_API_KEY"}
MODELS = {
    "openai": ("OPENAI_MODEL", "gpt-4.1-mini"),
    "anthropic": ("ANTHROPIC_MODEL", "claude-haiku-4-5"),
    "gemini": ("GEMINI_MODEL", "gemini-3.5-flash-lite"),
}


class Turn(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=35000)


class ChatRequest(BaseModel):
    provider: Literal["openai", "anthropic", "gemini"]
    messages: list[Turn] = Field(min_length=1, max_length=14)
    system: str | None = Field(default=None, max_length=6000)
    image_base64: str | None = None
    max_output_tokens: int = Field(default=1800, ge=64, le=2400)

    @field_validator("image_base64")
    @classmethod
    def check_image(cls, value: str | None) -> str | None:
        if value is None:
            return value
        if len(value) > 6_800_000:
            raise ValueError("이미지 크기는 약 5MB 이하만 지원합니다.")
        try:
            image = base64.b64decode(value, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise ValueError("올바른 Base64 이미지가 아닙니다.") from exc
        if len(image) > 5_000_000:
            raise ValueError("이미지 크기는 5MB 이하여야 합니다.")
        if not image.startswith(b"\xff\xd8\xff"):
            raise ValueError("현재 JPEG 이미지 입력만 지원합니다.")
        return value

    @model_validator(mode="after")
    def final_message_from_user(self):
        if self.messages[-1].role != "user":
            raise ValueError("마지막 메시지는 사용자 메시지여야 합니다.")
        return self


@app.get("/health")
async def health():
    return {"name": "NOVA Bridge", "providers": {provider: bool(os.getenv(env)) for provider, env in PROVIDERS.items()}}


@app.get("/v1/providers")
async def provider_status():
    """Public (LAN-only) metadata. Never returns API keys or secret prefixes."""
    return {"providers": [
        {"id": name, "configured": bool(os.getenv(key)), "model": os.getenv(*MODELS[name])}
        for name, key in PROVIDERS.items()
    ]}


@app.post("/v1/probe/{provider}")
async def probe(provider: str):
    """Really contacts an upstream model; there may be a small API charge."""
    if provider not in PROVIDERS:
        raise HTTPException(404, "알 수 없는 AI 제공자입니다.")
    start = time.perf_counter()
    result = await chat(ChatRequest(provider=provider, messages=[Turn(role="user", content="Reply with the single word OK.")], max_output_tokens=96))
    return {"provider": result["provider"], "model": result["model"],
            "elapsed_ms": int((time.perf_counter() - start) * 1000),
            "success": bool(result["text"].strip()), "preview": result["text"][:120]}


async def _post(url: str, headers: dict, data: dict) -> dict:
    async with httpx.AsyncClient(timeout=httpx.Timeout(85.0)) as client:
        try:
            response = await client.post(url, headers=headers, json=data)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as exc:
            status = exc.response.status_code
            # Never reflect upstream response text or request bodies: may contain private data.
            hint = {
                400: "모델 이름 또는 요청 형식을 확인하세요.",
                401: "API 키가 올바른지 확인하세요.",
                402: "결제 설정이나 잔액을 확인하세요.",
                403: "API 권한과 모델 접근 권한을 확인하세요.",
                404: "모델 ID가 정확한지 확인하세요.",
                429: "호출 한도 또는 잔액을 확인하세요. 잠시 뒤 재시도하세요.",
            }.get(status, "제공자 서비스 상태와 모델 설정을 확인하세요.")
            raise HTTPException(status_code=502, detail=f"AI 제공자 오류 ({status}): {hint}") from exc
        except httpx.RequestError as exc:
            raise HTTPException(status_code=504, detail="AI 제공자와의 통신 시간이 초과되었거나 연결에 실패했습니다.") from exc


def build_openai(req: ChatRequest) -> dict:
    messages: list[dict] = []
    if req.system:
        messages.append({"role": "system", "content": req.system})
    for i, turn in enumerate(req.messages):
        content: str | list = turn.content
        if req.image_base64 and i == len(req.messages) - 1:
            content = [
                {"type": "text", "text": turn.content},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{req.image_base64}"}},
            ]
        messages.append({"role": turn.role, "content": content})
    return {"model": os.getenv(*MODELS["openai"]), "messages": messages, "max_completion_tokens": req.max_output_tokens}


def build_anthropic(req: ChatRequest) -> dict:
    messages: list[dict] = []
    for i, turn in enumerate(req.messages):
        content: str | list = turn.content
        if req.image_base64 and i == len(req.messages) - 1:
            content = [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": req.image_base64}},
                {"type": "text", "text": turn.content},
            ]
        messages.append({"role": turn.role, "content": content})
    payload = {"model": os.getenv(*MODELS["anthropic"]), "max_tokens": req.max_output_tokens, "messages": messages}
    if req.system:
        payload["system"] = req.system
    return payload


def build_gemini(req: ChatRequest) -> dict:
    contents = []
    for i, turn in enumerate(req.messages):
        parts = [{"text": turn.content}]
        if req.image_base64 and i == len(req.messages) - 1:
            parts.insert(0, {"inline_data": {"mime_type": "image/jpeg", "data": req.image_base64}})
        contents.append({"role": "model" if turn.role == "assistant" else "user", "parts": parts})
    payload: dict = {"contents": contents, "generationConfig": {"maxOutputTokens": req.max_output_tokens}}
    if req.system:
        payload["systemInstruction"] = {"parts": [{"text": req.system}]}
    return payload


@app.post("/v1/chat")
async def chat(req: ChatRequest):
    key = os.getenv(PROVIDERS[req.provider])
    if not key:
        raise HTTPException(status_code=503, detail=f"{req.provider} API 키가 설정되지 않았습니다. Backend/.env를 확인하세요.")
    model = os.getenv(*MODELS[req.provider])
    if req.provider == "openai":
        data = await _post("https://api.openai.com/v1/chat/completions", {"Authorization": f"Bearer {key}"}, build_openai(req))
        try:
            text = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise HTTPException(502, "OpenAI 응답에서 텍스트를 찾지 못했습니다.") from exc
    elif req.provider == "anthropic":
        data = await _post("https://api.anthropic.com/v1/messages", {"x-api-key": key, "anthropic-version": "2023-06-01"}, build_anthropic(req))
        try:
            text = "\n".join(block["text"] for block in data["content"] if block["type"] == "text")
        except (KeyError, TypeError) as exc:
            raise HTTPException(502, "Anthropic 응답에서 텍스트를 찾지 못했습니다.") from exc
    else:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        data = await _post(url, {"x-goog-api-key": key}, build_gemini(req))
        try:
            text = "\n".join(p["text"] for p in data["candidates"][0]["content"]["parts"] if "text" in p)
        except (KeyError, IndexError, TypeError) as exc:
            raise HTTPException(502, "Gemini 응답에서 텍스트를 찾지 못했습니다.") from exc
    if not text:
        raise HTTPException(502, "모델이 빈 답변을 반환했습니다.")
    return {"provider": req.provider, "model": model, "text": text, "demo": False}
