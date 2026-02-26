-- Triggers para auditoría y reglas de negocio en Pagila

-- 1) Tabla de auditoría
CREATE TABLE IF NOT EXISTS audit_log (
    audit_id   BIGSERIAL PRIMARY KEY,
    event_ts   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    table_name TEXT        NOT NULL,
    op         TEXT        NOT NULL,
    pk         TEXT        NOT NULL,
    old_row    JSONB,
    new_row    JSONB
);


-- 2) Función genérica de auditoría
CREATE OR REPLACE FUNCTION audit_row_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_pk text;
BEGIN
    -- Se asume que las tablas tienen una única PK sencilla llamada *_id.
    IF TG_OP = 'INSERT' THEN
        v_pk := to_jsonb(NEW)->> (TG_ARGV[0]);
        INSERT INTO audit_log(table_name, op, pk, old_row, new_row)
        VALUES (TG_TABLE_NAME, TG_OP, v_pk, NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        v_pk := to_jsonb(NEW)->> (TG_ARGV[0]);
        INSERT INTO audit_log(table_name, op, pk, old_row, new_row)
        VALUES (TG_TABLE_NAME, TG_OP, v_pk, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        v_pk := to_jsonb(OLD)->> (TG_ARGV[0]);
        INSERT INTO audit_log(table_name, op, pk, old_row, new_row)
        VALUES (TG_TABLE_NAME, TG_OP, v_pk, to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


-- Triggers de auditoría para rental y payment
DROP TRIGGER IF EXISTS tr_audit_rental ON rental;
CREATE TRIGGER tr_audit_rental
AFTER INSERT OR UPDATE OR DELETE ON rental
FOR EACH ROW
EXECUTE FUNCTION audit_row_change('rental_id');

DROP TRIGGER IF EXISTS tr_audit_payment ON payment;
CREATE TRIGGER tr_audit_payment
AFTER INSERT OR UPDATE OR DELETE ON payment
FOR EACH ROW
EXECUTE FUNCTION audit_row_change('payment_id');


-- 3) Regla de negocio: prohibir pagos con amount <= 0

CREATE OR REPLACE FUNCTION ensure_positive_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'El monto del pago debe ser mayor que cero.'
            USING ERRCODE = '23514'; -- check_violation
    END IF;
    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS tr_payment_positive_amount ON payment;
CREATE TRIGGER tr_payment_positive_amount
BEFORE INSERT OR UPDATE ON payment
FOR EACH ROW
EXECUTE FUNCTION ensure_positive_payment();

