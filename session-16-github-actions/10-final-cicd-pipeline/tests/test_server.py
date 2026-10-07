import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.server import handle


def test_health():
    status, body = handle("/health")
    assert status == 200
    assert body["status"] == "ok"


def test_calculate_add():
    status, body = handle("/calculate?op=add&a=10&b=5")
    assert status == 200
    assert body["result"] == 15


def test_calculate_divide_by_zero():
    status, body = handle("/calculate?op=divide&a=10&b=0")
    assert status == 400
    assert "Cannot divide by zero" in body["error"]


def test_unknown_route():
    status, _ = handle("/missing")
    assert status == 404
