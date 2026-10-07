import os

# Tests never touch PostgreSQL: point SQLAlchemy at a throwaway SQLite file
# before the application (and its engine) is imported.
os.environ["DATABASE_URL"] = "sqlite:///./test.db"

import pytest
from fastapi.testclient import TestClient

from app.db import Base, engine
from app.main import app


@pytest.fixture(scope="session")
def client():
    Base.metadata.drop_all(bind=engine)
    # "with" runs the FastAPI startup event, which creates the tables.
    with TestClient(app) as test_client:
        yield test_client
    Base.metadata.drop_all(bind=engine)
