"""Comandos administrativos.

Uso (dentro do container):
    python -m app.cli create-user <email> --name "Seu Nome"

O caminho normal é o cadastro pelo app (POST /register); este comando serve
para criar contas manualmente.
"""

import argparse
import getpass
import sys

from email_validator import EmailNotValidError, validate_email
from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import User


def create_user(email: str, name: str, password: str) -> None:
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.email == email)):
            sys.exit(f"Já existe uma conta com o e-mail '{email}'.")
        db.add(User(email=email, name=name, password_hash=hash_password(password)))
        db.commit()
    print(f"Usuário '{email}' criado.")


def main() -> None:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create-user")
    create.add_argument("email")
    create.add_argument("--name", required=True)
    create.add_argument(
        "--password-stdin", action="store_true", help="lê a senha do stdin em vez de pedir"
    )
    args = parser.parse_args()

    if args.command == "create-user":
        try:
            email = validate_email(args.email, check_deliverability=False).normalized.lower()
        except EmailNotValidError as error:
            sys.exit(f"E-mail inválido: {error}")

        if args.password_stdin:
            password = sys.stdin.readline().rstrip("\n")
        else:
            password = getpass.getpass("Senha: ")
            if password != getpass.getpass("Confirme a senha: "):
                sys.exit("As senhas não conferem.")
        if len(password) < 8:
            sys.exit("A senha deve ter pelo menos 8 caracteres.")
        create_user(email, args.name.strip(), password)


if __name__ == "__main__":
    main()
