"""Offline contract tests for the three real API adapters.
No API keys, Internet calls, or vendor billing are used.
"""
import app as nova
from fastapi.testclient import TestClient

client = TestClient(nova.app)


def test_openai_adapter_sends_messages_and_returns_text(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "fake-secret")
    sent = []

    async def fake_post(url, headers, data):
        sent.append((url, headers, data))
        return {"choices": [{"message": {"content": "OpenAI mock reply"}}]}

    monkeypatch.setattr(nova, "_post", fake_post)
    response = client.post("/v1/chat", json={
        "provider": "openai",
        "messages": [{"role": "user", "content": "안녕"}],
        "system": "Short answers only"
    })
    assert response.status_code == 200
    assert response.json()["text"] == "OpenAI mock reply"
    assert response.json()["demo"] is False
    assert sent[0][0].endswith("/v1/chat/completions")
    assert sent[0][2]["messages"][0]["role"] == "system"
    assert sent[0][2]["messages"][-1]["content"] == "안녕"
    assert "fake-secret" not in response.text


def test_claude_adapter_roles_and_reply(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "fake-secret")
    sent = []

    async def fake_post(url, headers, data):
        sent.append((url, headers, data))
        return {"content": [{"type": "text", "text": "Claude mock reply"}]}

    monkeypatch.setattr(nova, "_post", fake_post)
    response = client.post("/v1/chat", json={
        "provider": "anthropic",
        "messages": [{"role": "user", "content": "첫 질문"},
                     {"role": "assistant", "content": "답변"},
                     {"role": "user", "content": "추가 질문"}],
        "system": "Test"
    })
    assert response.status_code == 200
    assert response.json()["text"] == "Claude mock reply"
    assert sent[0][2]["system"] == "Test"
    assert len(sent[0][2]["messages"]) == 3
    assert sent[0][0].endswith("/v1/messages")


def test_gemini_adapter_translates_message_roles(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "fake-secret")
    sent = []

    async def fake_post(url, headers, data):
        sent.append((url, headers, data))
        return {"candidates": [{"content": {"parts": [{"text": "Gemini mock reply"}]}}]}

    monkeypatch.setattr(nova, "_post", fake_post)
    response = client.post("/v1/chat", json={
        "provider": "gemini",
        "messages": [{"role": "user", "content": "Q"},
                     {"role": "assistant", "content": "A"},
                     {"role": "user", "content": "Q2"}]
    })
    assert response.status_code == 200
    assert response.json()["text"] == "Gemini mock reply"
    assert sent[0][2]["contents"][1]["role"] == "model"
    assert "generateContent" in sent[0][0]


def test_no_key_no_request(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    assert client.post("/v1/chat", json={"provider": "openai", "messages": [{"role": "user", "content": "hello"}]}).status_code == 503


def test_reject_broken_images(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "fake-secret")
    response = client.post("/v1/chat", json={"provider": "openai", "messages": [{"role": "user", "content": "look"}], "image_base64": "YQ=="})
    assert response.status_code == 422


def test_reject_empty_upstream_text(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "fake-secret")

    async def fake_post(url, headers, data):
        return {"choices": [{"message": {"content": ""}}]}

    monkeypatch.setattr(nova, "_post", fake_post)
    response = client.post("/v1/chat", json={"provider": "openai", "messages": [{"role": "user", "content": "test"}]})
    assert response.status_code == 502
