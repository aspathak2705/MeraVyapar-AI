def test_health_check_endpoint(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["data"]["service"] == "meravyapar-api"
    assert "X-Request-ID" in response.headers
