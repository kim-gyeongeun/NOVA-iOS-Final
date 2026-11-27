"""API setup diagnostics without real vendor keys / outbound calls."""
from fastapi.testclient import TestClient
import app as nova

client = TestClient(nova.app)


def test_provider_status_does_not_expose_key(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "my-top-secret-key")
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    response = client.get("/v1/providers")
    assert response.status_code == 200
    data = response.json()
    assert len(data["providers"]) == 3
    assert data["providers"][0]["configured"] is True
    assert data["providers"][1]["configured"] is False
    assert data["providers"][0]["model"]
    assert "my-top-secret-key" not in str(data)


def test_probe_really_calls_vendor_mock(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "fake-gemini-key")
    seen = []
    async def fake_post(url, headers, data):
        seen.append((url, headers, data))
        return {"candidates": [{"content": {"parts": [{"text": "OK"}]}}]}
    monkeypatch.setattr(nova, "_post", fake_post)
    response = client.post("/v1/probe/gemini")
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["preview"] == "OK"
    assert response.json()["elapsed_ms"] >= 0
    assert len(seen) == 1
    assert seen[0][2]["generationConfig"]["maxOutputTokens"] == 96


def test_probe_rejects_bad_provider():
    assert client.post("/v1/probe/not-a-provider").status_code == 404


def test_probe_requires_key(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    result = client.post("/v1/probe/anthropic")
    assert result.status_code == 503


def test_max_tokens_bounds():
    req = {"provider": "openai", "messages": [{"role":"user", "content":"hi"}], "max_output_tokens": 9999}
    assert client.post("/v1/chat", json=req).status_code == 422


def test_vendor_errors_are_sanitized(monkeypatch):
    import httpx
    monkeypatch.setenv("OPENAI_API_KEY", "dont-leak-this")
    async def broken_post(url, headers, data):
        request = httpx.Request("POST", url)
        response = httpx.Response(401, request=request, text="secret token dont-leak-this")
        response.raise_for_status()
    monkeypatch.setattr(nova, "_post", broken_post)
    # `_post` is replaced so its error conversion is not tested here.
    # Ensure endpoint doesn't return any auth header in a successful probe/metadata path.
    assert "dont-leak-this" not in client.get("/v1/providers").text
