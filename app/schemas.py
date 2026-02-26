from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, ConfigDict


class RentalCreate(BaseModel):
    customer_id: int = Field(gt=0)
    inventory_id: int = Field(gt=0)
    staff_id: int = Field(gt=0)


class RentalResponse(BaseModel):
    rental_id: int
    customer_id: int
    inventory_id: int
    staff_id: int
    rental_date: datetime

    model_config = ConfigDict(from_attributes=True)


class ReturnResponse(BaseModel):
    rental_id: int
    return_date: datetime
    already_returned: bool


class PaymentCreate(BaseModel):
    customer_id: int = Field(gt=0)
    staff_id: int = Field(gt=0)
    amount: float = Field(gt=0, description="Monto del pago, debe ser > 0.")
    rental_id: Optional[int] = Field(default=None, gt=0)


class PaymentResponse(BaseModel):
    payment_id: int
    customer_id: int
    staff_id: int
    rental_id: Optional[int]
    amount: float
    payment_date: datetime

    model_config = ConfigDict(from_attributes=True)

