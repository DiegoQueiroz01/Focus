import hashlib

from email_validator import EmailNotValidError, validate_email
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from app.api.deps import CurrentUser, DbSession
from app.core.config import get_settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse, UserRead

router = APIRouter(tags=["auth"])


def _token_for(user: User) -> TokenResponse:
    token, expires_in = create_access_token(str(user.id))
    return TokenResponse(access_token=token, expires_in=expires_in)


def _normalize_email(raw: str) -> str:
    try:
        result = validate_email(
            raw.strip(), check_deliverability=get_settings().email_check_deliverability
        )
    except EmailNotValidError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Informe um e-mail válido e existente.",
        ) from error
    return result.normalized.lower()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: DbSession) -> TokenResponse:
    email = _normalize_email(payload.email)
    if db.scalar(select(User.id).where(User.email == email)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Já existe uma conta com este e-mail.",
        )

    user = User(name=payload.name, email=email, password_hash=hash_password(payload.password))
    db.add(user)
    db.commit()
    return _token_for(user)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: DbSession) -> TokenResponse:
    identifier = payload.email.strip()
    if "@" in identifier:
        query = select(User).where(User.email == identifier.lower())
    else:
        # Contas antigas, criadas pelo CLI antes do cadastro por e-mail.
        query = select(User).where(func.lower(User.username) == identifier.lower())
    user = db.scalar(query)

    password_ok = verify_password(payload.password, user.password_hash if user else None)
    if user is None or not password_ok or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha inválidos",
        )
    return _token_for(user)


def avatar_url_for(user: User) -> str | None:
    if user.avatar_url:
        return user.avatar_url
    if user.email and get_settings().gravatar_enabled:
        digest = hashlib.sha256(user.email.strip().lower().encode()).hexdigest()
        # d=404: sem foto cadastrada, o Gravatar responde 404 e o app mostra as iniciais.
        return f"https://gravatar.com/avatar/{digest}?s=256&d=404"
    return None


@router.get("/me", response_model=UserRead)
def me(user: CurrentUser) -> UserRead:
    return UserRead(id=user.id, name=user.name, email=user.email, avatar_url=avatar_url_for(user))
