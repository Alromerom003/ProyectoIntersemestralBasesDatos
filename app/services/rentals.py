from datetime import datetime

from sqlalchemy import text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import IntegrityError

from app.errors import api_error
from app.schemas import RentalCreate, RentalResponse


def create_rental_serializable(conn: Connection, data: RentalCreate) -> RentalResponse:
    """
    Crea una renta usando una transacción SERIALIZABLE con reintentos.
    """

    # Validación defensiva básica
    if data.customer_id <= 0 or data.inventory_id <= 0 or data.staff_id <= 0:
        raise api_error(
            400,
            "INVALID_INPUT",
            "Los identificadores deben ser mayores que cero.",
        )

    for table, field_name, field_value in [
        ("customer", "customer_id", data.customer_id),
        ("inventory", "inventory_id", data.inventory_id),
        ("staff", "staff_id", data.staff_id),
    ]:
        exists = conn.execute(
            text(f"SELECT 1 FROM {table} WHERE {field_name} = :id"),
            {"id": field_value},
        ).first()

        if not exists:
            raise api_error(
                404,
                f"{table.upper()}_NOT_FOUND",
                f"{table.capitalize()} con id {field_value} no existe.",
            )

    try:
        row = conn.execute(
            text(
                """
                INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
                VALUES (NOW(), :inventory_id, :customer_id, NULL, :staff_id)
                RETURNING rental_id, rental_date, inventory_id, customer_id, staff_id
                """
            ),
            {
                "inventory_id": data.inventory_id,
                "customer_id": data.customer_id,
                "staff_id": data.staff_id,
            },
        ).one()

    except IntegrityError as exc:
        orig = getattr(exc, "orig", None)
        sqlstate = getattr(orig, "pgcode", None) or getattr(orig, "sqlstate", None)

        if sqlstate == "23505":
            raise api_error(
                409,
                "RENTAL_ALREADY_ACTIVE",
                "Ya existe una renta activa para este inventory_id.",
            )
        raise

    return RentalResponse(
        rental_id=row.rental_id,
        rental_date=row.rental_date,
        inventory_id=row.inventory_id,
        customer_id=row.customer_id,
        staff_id=row.staff_id,
    )