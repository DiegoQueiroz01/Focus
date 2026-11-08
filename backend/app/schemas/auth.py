from pydantic import BaseModel, ConfigDict, Field, field_validator


def _password_fits_bcrypt(value: str) -> str:
    # O bcrypt só considera os primeiros 72 bytes da senha.
    if len(value.encode()) > 72:
        raise ValueError("A senha deve ter no máximo 72 bytes")
    return value


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=72)

    @field_validator("name")
    @classmethod
    def _strip_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if len(value) < 2:
            raise ValueError("Informe seu nome")
        return value

    _check_password = field_validator("password")(_password_fits_bcrypt)


class LoginRequest(BaseModel):
    # Aceita o e-mail ou, para contas antigas, o username.
    email: str = Field(min_length=1, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str | None
    # Foto de perfil, se existir. O app mostra as iniciais quando a URL não carrega.
    avatar_url: str | None = None
