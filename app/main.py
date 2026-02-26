from fastapi import FastAPI, Depends
from sqlalchemy.engine import Connection

from app.db import get_connection, run_serializable_transaction, run_read_committed_transaction
from app.errors import add_exception_handlers
from app.schemas import (
    RentalCreate,
    RentalResponse,
    ReturnResponse,
    PaymentCreate,
    PaymentResponse,
)
from app.services.rentals import create_rental_serializable
from app.services.returns import return_rental_read_committed
from app.services.payments import create_payment_read_committed


app = FastAPI(
    title="DVD Rental API - Concurrencia Pagila",
    version="1.0.0",
)

add_exception_handlers(app)


def get_db_connection() -> Connection:
    with get_connection() as conn:
        yield conn


@app.post("/rentals", response_model=RentalResponse, status_code=201)
def create_rental_endpoint(
    payload: RentalCreate,
    conn: Connection = Depends(get_db_connection),
) -> RentalResponse:
    """
    Crea una renta.

    - Transacción explícita.
    - Aislamiento: SERIALIZABLE.
    - Reintentos ante 40001 (serialization_failure) y 40P01 (deadlock_detected).
    - Se apoya en un índice único parcial para garantizar que no haya dos
      rentas activas (return_date IS NULL) para el mismo inventory_id,
      incluso bajo alta concurrencia.
    """

    def tx_fn(c: Connection) -> RentalResponse:
        return create_rental_serializable(c, payload)

    return run_serializable_transaction(conn, tx_fn)


@app.post("/returns/{rental_id}", response_model=ReturnResponse)
def return_rental_endpoint(
    rental_id: int,
    conn: Connection = Depends(get_db_connection),
) -> ReturnResponse:
    """
    Marca una renta como devuelta.

    - Transacción explícita.
    - Aislamiento: READ COMMITTED.
    - Idempotente: llamar dos veces sobre la misma renta no produce efectos
      adicionales; simplemente marca `already_returned = true` si ya estaba devuelta.
    """

    def tx_fn(c: Connection) -> ReturnResponse:
        return return_rental_read_committed(c, rental_id)

    return run_read_committed_transaction(conn, tx_fn)


@app.post("/payments", response_model=PaymentResponse, status_code=201)
def create_payment_endpoint(
    payload: PaymentCreate,
    conn: Connection = Depends(get_db_connection),
) -> PaymentResponse:
    """
    Crea un pago.

    - Transacción explícita.
    - Aislamiento: READ COMMITTED.
    - Valida amount > 0 (además del trigger de BD) y que, si se pasa rental_id,
      exista y pertenezca al mismo customer_id.
    """

    def tx_fn(c: Connection) -> PaymentResponse:
        return create_payment_read_committed(c, payload)

    return run_read_committed_transaction(conn, tx_fn)

