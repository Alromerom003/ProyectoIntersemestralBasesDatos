from sqlalchemy import text
from sqlalchemy.engine import Connection

from app.errors import api_error
from app.schemas import PaymentCreate, PaymentResponse


def create_payment_read_committed(conn: Connection, data: PaymentCreate) -> PaymentResponse:
    """
    Crea un pago validando:
    - existencia de customer y staff,
    - opcionalmente existencia de rental y pertenencia al mismo customer,
    - amount > 0 (validación adicional a la de trigger).
    """

    # Validación defensiva adicional (antes de llegar al trigger).
    if data.amount <= 0:
        raise api_error(
            400,
            "INVALID_AMOUNT",
            "El monto del pago debe ser mayor que cero.",
        )

    # Validar existencia de customer y staff.
    for table, field_name, field_value in [
        ("customer", "customer_id", data.customer_id),
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

    rental_id = data.rental_id

    if rental_id is not None:
        rental_row = conn.execute(
            text(
                """
                SELECT rental_id, customer_id
                FROM rental
                WHERE rental_id = :rental_id
                """
            ),
            {"rental_id": rental_id},
        ).first()

        if not rental_row:
            raise api_error(
                404,
                "RENTAL_NOT_FOUND",
                f"Renta con id {rental_id} no existe.",
            )

        if rental_row.customer_id != data.customer_id:
            raise api_error(
                400,
                "RENTAL_CUSTOMER_MISMATCH",
                "El rental_id indicado no pertenece al customer_id proporcionado.",
            )

    row = conn.execute(
        text(
            """
            INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
            VALUES (:customer_id, :staff_id, :rental_id, :amount, NOW())
            RETURNING payment_id, customer_id, staff_id, rental_id, amount, payment_date
            """
        ),
        {
            "customer_id": data.customer_id,
            "staff_id": data.staff_id,
            "rental_id": rental_id,
            "amount": data.amount,
        },
    ).one()

    return PaymentResponse(
        payment_id=row.payment_id,
        customer_id=row.customer_id,
        staff_id=row.staff_id,
        rental_id=row.rental_id,
        amount=row.amount,
        payment_date=row.payment_date,
    )