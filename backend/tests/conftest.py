import os

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-with-at-least-32-characters")
# Os testes não dependem de DNS; a validação de formato continua ativa.
os.environ.setdefault("EMAIL_CHECK_DELIVERABILITY", "false")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.security import hash_password
from app.db.session import get_db
from app.main import app
from app.models import Base, User

PASSWORD = "senha-forte-123"


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    engine.dispose()


@pytest.fixture
def client(session_factory):
    def override_get_db():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def make_user(session_factory):
    def _make(email: str, password: str = PASSWORD, *, username: str | None = None) -> User:
        with session_factory() as db:
            user = User(
                name=email.split("@")[0].title(),
                email=email,
                username=username,
                password_hash=hash_password(password),
            )
            db.add(user)
            db.commit()
            return user

    return _make


@pytest.fixture
def auth_headers(client, make_user):
    def _headers(email: str = "diego@example.com") -> dict[str, str]:
        make_user(email)
        response = client.post("/login", json={"email": email, "password": PASSWORD})
        return {"Authorization": f"Bearer {response.json()['access_token']}"}

    return _headers
