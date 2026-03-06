-- ======================================
-- Esquema de auditoría y performance
-- ======================================

-- 1. Tabla de Auditoría
CREATE TABLE IF NOT EXISTS public.audit_log (
    id SERIAL PRIMARY KEY,
    tabla_afectada TEXT,
    operacion TEXT,
    valor_anterior JSONB,
    valor_nuevo JSONB,
    usuario_db TEXT DEFAULT CURRENT_USER,
    fecha_registro TIMESTAMP DEFAULT NOW()
);

-- 2. Función para disparar el registro
CREATE OR REPLACE FUNCTION public.fn_registrar_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log(tabla_afectada, operacion, valor_anterior, valor_nuevo)
        VALUES (TG_RELNAME, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log(tabla_afectada, operacion, valor_nuevo)
        VALUES (TG_RELNAME, TG_OP, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log(tabla_afectada, operacion, valor_anterior)
        VALUES (TG_RELNAME, TG_OP, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 3. Triggers de aplicación
-- Registro de INSERT/UPDATE/DELETE sobre rental y payment
CREATE TRIGGER trg_audit_rental 
AFTER INSERT OR UPDATE OR DELETE ON rental 
FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

CREATE TRIGGER trg_audit_payment 
AFTER INSERT OR UPDATE OR DELETE ON payment 
FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

-- ==============================
-- Índices de optimización 
-- ==============================

CREATE UNIQUE INDEX IF NOT EXISTS ux_rental_active_inventory
    ON rental (inventory_id) WHERE return_date IS NULL;

-- Búsqueda eficiente por cliente
CREATE INDEX IF NOT EXISTS idx_rental_customer_lookup
    ON rental (customer_id);

-- Índice compuesto para el endpoint de pagos
CREATE INDEX IF NOT EXISTS idx_payment_customer_date_composite
    ON payment (customer_id, payment_date);

-- Impide el registro de pagos con montos menores o iguales a cero.

CREATE OR REPLACE FUNCTION check_payment_amount()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'ERROR_REGLA_NEGOCIO: El monto del pago (%) debe ser mayor a cero.', NEW.amount;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_payment_amount
BEFORE INSERT OR UPDATE ON payment
FOR EACH ROW EXECUTE FUNCTION check_payment_amount();