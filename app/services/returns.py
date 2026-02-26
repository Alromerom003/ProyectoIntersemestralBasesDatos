from datetime import datetime

from sqlalchemy import text
from sqlalchemy.engine import Connection

from app.errors import api_error
from app.schemas import ReturnResponse


def return_rental_read_committed(conn: Connection, rental_id: int) -> ReturnResponse:
    """
    Marca una renta como devuelta de forma idempotente.
    Usa READ COMMITTED y COALESCE para actualizar sólo si estaba NULL.
    """
    row = conn.execute(
        text(
            """
            SELECT rental_id, return_date
            FROM rental
            WHERE rental_id = :rental_id
            FOR UPDATE
            """
        ),
        {"rental_id": rental_id},
    ).first()

    if not row:
        raise api_error(
            404,
            "RENTAL_NOT_FOUND",
            f"Renta con id {rental_id} no existe.",
        )

    was_null = row.return_date is None

    updated = conn.execute(
        text(
            """
            UPDATE rental
            SET return_date = COALESCE(return_date, NOW())
            WHERE rental_id = :rental_id
            RETURNING rental_id, return_date
            """
        ),
        {"rental_id": rental_id},
    ).one()

    return ReturnResponse(
        rental_id=updated.rental_id,
        return_date=updated.return_date,
        already_returned=not was_null,
    )

