import base64
import os

import pytest
from fastapi.testclient import TestClient

import app as nova

client = TestClient(nova.app)


def sample(provider="openai", image=None):
    return {"provider": provider, "messages": [{"role": "user", "content": "안녕하세요"}], "system": "친절하게", "image_base64": image}


def test_health_keys_not_leaked():
    response = client.get("/health")
    assert response.status_code == 200
    assert sorted(response.json()["providers"]) == ["anthropic", "gemini", "openai"]
    assert "secret" not in str(response.json())


def test_requires_api_key(monkeypatch):
    for name in nova.PROVIDERS.values():
        monkeypatch.delenv(name, raising=False)
    response = client.post("/v1/chat", json=sample())
    assert response.status_code == 503


def test_bad_image_rejected():
    assert client.post("/v1/chat", json=sample(image="this-is-not-base64")).status_code == 422
    assert client.post("/v1/chat", json=sample(image=base64.b64encode(b"hello").decode())).status_code == 422


def test_last_turn_must_be_user():
    body = sample()
    body["messages"] = [{"role": "assistant", "content": "hi"}]
    assert client.post("/v1/chat", json=body).status_code == 422


def test_vendor_payload_shapes():
    body = nova.ChatRequest.model_validate(sample())
    assert nova.build_openai(body)["messages"][-1]["role"] == "user"
    assert nova.build_anthropic(body)["max_tokens"] == 1800
    assert nova.build_gemini(body)["contents"][-1]["role"] == "user"


def test_vendor_images():
    image = base64.b64encode(b"\xff\xd8\xff" + b"demo-image").decode()
    body = nova.ChatRequest.model_validate(sample(image=image))
    assert "image_url" in str(nova.build_openai(body))
    assert "base64" in str(nova.build_anthropic(body))
    assert "inline_data" in str(nova.build_gemini(body))


@pytest.mark.parametrize("provider,text", [("openai", "OpenAI text"), ("anthropic", "Claude text"), ("gemini", "Gemini text")])
def test_actual_vendor_bridge_using_mock(monkeypatch, provider, text):
    monkeypatch.setenv(nova.PROVIDERS[provider], "test-fake-key")
    async def mocked_post(url, headers, data):
        assert headers
        if provider == "openai": return {"choices": [{"message": {"content": text}}]}
        if provider == "anthropic": return {"content": [{"type": "text", "text": text}]}
        return {"candidates": [{"content": {"parts": [{"text": text}]}}]}
    monkeypatch.setattr(nova, "_post", mocked_post)
    result = client.post("/v1/chat", json=sample(provider=provider))
    assert result.status_code == 200
    assert result.json()["text"] == text
    assert result.json()["demo"] is False
