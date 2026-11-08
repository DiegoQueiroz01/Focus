from datetime import date, datetime, timedelta, timezone


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(value: datetime) -> datetime:
    """SQLite devolve datas sem fuso; o Postgres devolve com. Normaliza para UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def local_date(value: datetime, offset: timedelta) -> date:
    return (as_utc(value) + offset).date()
