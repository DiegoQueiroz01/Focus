"""Comandos administrativos.

Uso (dentro do container):
    python -m app.cli create-user <username>
"""

import argparse
import getpass
import sys

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import User


def create_user(username: str, password: str) -> None:
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.username == username)):
            sys.exit(f"Usuário '{username}' já existe.")
        db.add(User(username=username, password_hash=hash_password(password)))
        db.commit()
    print(f"Usuário '{username}' criado.")


def main() -> None:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create-user")
    create.add_argument("username")
    create.add_argument(
        "--password-stdin", action="store_true", help="lê a senha do stdin em vez de pedir"
    )
    args = parser.parse_args()

    if args.command == "create-user":
        if args.password_stdin:
            password = sys.stdin.readline().rstrip("\n")
        else:
            password = getpass.getpass("Senha: ")
            if password != getpass.getpass("Confirme a senha: "):
                sys.exit("As senhas não conferem.")
        if len(password) < 8:
            sys.exit("A senha deve ter pelo menos 8 caracteres.")
        create_user(args.username, password)


if __name__ == "__main__":
    main()
