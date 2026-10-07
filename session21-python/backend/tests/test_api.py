def test_health(client):
    assert client.get("/health").json() == {"status": "UP"}


def test_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "TaskBoard API"


def test_ready(client):
    assert client.get("/ready").json() == {"status": "READY"}


def test_create_task_validation(client):
    response = client.post("/api/tasks", json={"title": "Deploy application", "priority": "HIGH", "assignee": "Student"})
    assert response.status_code == 201
    assert response.json()["title"] == "Deploy application"


def test_create_task_rejects_empty_title(client):
    response = client.post("/api/tasks", json={"title": ""})
    assert response.status_code == 422


def test_list_and_get_task(client):
    created = client.post("/api/tasks", json={"title": "Write Helm chart"}).json()
    ids = [task["id"] for task in client.get("/api/tasks").json()]
    assert created["id"] in ids
    assert client.get(f"/api/tasks/{created['id']}").json()["title"] == "Write Helm chart"
    assert client.get("/api/tasks/99999").status_code == 404


def test_update_task_and_stats(client):
    created = client.post("/api/tasks", json={"title": "Configure HPA"}).json()
    response = client.put(f"/api/tasks/{created['id']}", json={"status": "DONE"})
    assert response.status_code == 200
    assert response.json()["status"] == "DONE"
    stats = client.get("/api/tasks/stats").json()
    assert stats["done"] >= 1
    assert stats["total"] == stats["todo"] + stats["inProgress"] + stats["done"]


def test_delete_task(client):
    created = client.post("/api/tasks", json={"title": "Temporary task"}).json()
    assert client.delete(f"/api/tasks/{created['id']}").status_code == 204
    assert client.get(f"/api/tasks/{created['id']}").status_code == 404


def test_metrics_endpoint(client):
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text
