import os
import time
from contextlib import contextmanager
from typing import Callable, Generator, TypeVar, Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import DBAPIError

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://postgres:postgres@localhost:5432/pagila",
)
# Si el usuario configuró psycopg2, usar psycopg (psycopg3) en su lugar
if "+psycopg2" in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("+psycopg2", "+psycopg")

engine = create_engine(
    DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
    isolation_level="READ COMMITTED",
    future=True,
)

T = TypeVar("T")


@contextmanager
def get_connection() -> Generator[Connection, None, None]:
    conn = engine.connect()
    try:
        yield conn
    finally:
        conn.close()


def _run_transaction_with_isolation(
    conn: Connection,
    fn: Callable[[Connection], T],
    isolation_level_sql: str | None = None,
) -> T:
    trans = conn.begin()
    try:
        if isolation_level_sql:
            conn.execute(text(isolation_level_sql))
        result = fn(conn)
        trans.commit()
        return result
    except Exception:
        trans.rollback()
        raise


CONCURRENCY_SQLSTATES = {"40P01", "40001"}


def retry_transaction(
    conn: Connection,
    fn: Callable[[Connection], T],
    isolation_level_sql: str | None = None,
    max_retries: int = 5,
    base_backoff: float = 0.05,
) -> T:
    """
    Ejecuta una transacción con reintentos ante deadlocks y serialization failures.
    Backoff exponencial: 0.05, 0.1, 0.2, 0.4, 0.8 ...
    """
    attempt = 0
    while True:
        try:
            return _run_transaction_with_isolation(conn, fn, isolation_level_sql)
        except DBAPIError as exc:
            orig = getattr(exc, "orig", None)
            sqlstate = getattr(orig, "pgcode", None) or getattr(orig, "sqlstate", None)
            if sqlstate not in CONCURRENCY_SQLSTATES or attempt >= max_retries:
                raise
            sleep_seconds = base_backoff * (2**attempt)
            time.sleep(sleep_seconds)
            attempt += 1


def run_serializable_transaction(
    conn: Connection,
    fn: Callable[[Connection], T],
) -> T:
    """
    Ejecuta una transacción SERIALIZABLE con reintentos.
    """
    return retry_transaction(
        conn,
        fn,
        isolation_level_sql="SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE",
    )


def run_read_committed_transaction(
    conn: Connection,
    fn: Callable[[Connection], T],
) -> T:
    """
    Ejecuta una transacción READ COMMITTED (explícita).
    """
    return retry_transaction(
        conn,
        fn,
        isolation_level_sql="SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED",
        # Normalmente no esperamos conflictos de serialización aquí, pero reutilizamos la misma
        # función de reintentos por simplicidad y para cubrir casos de deadlock.
    )

