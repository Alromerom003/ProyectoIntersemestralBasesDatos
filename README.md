# DVD Rental API (Pagila) – Concurrencia, Aislamiento y Deadlocks

API REST académica en FastAPI + PostgreSQL (Pagila / DVD Rental) enfocada en:

- **Transacciones explícitas** y **niveles de aislamiento**.
- **Control de concurrencia** contra doble renta activa.
- **Manejo de deadlocks y serialization failures** con reintentos.
- **Triggers de auditoría y reglas de negocio**.
- **Pruebas de carga con pgbench**.

> Lenguaje: Python 3.11+, PostgreSQL 14+ (o similar).

---

## ¿Cómo funciona la aplicación?

La app simula un **sistema de alquiler de DVDs**. Tiene tres operaciones principales:

1. **Crear renta** (`POST /rentals`): Un cliente alquila una copia de película (inventory_id). La base de datos impide que la misma copia se rente dos veces al mismo tiempo (control de concurrencia).
2. **Registrar devolución** (`POST /returns/{rental_id}`): Se marca la renta como devuelta. Es idempotente: llamar dos veces no causa problemas.
3. **Registrar pago** (`POST /payments`): Se guarda un pago, opcionalmente asociado a una renta.

**Flujo típico:** Cliente renta → luego devuelve → y paga. La API usa transacciones con distintos niveles de aislamiento (SERIALIZABLE para rentas, READ COMMITTED para devoluciones y pagos) y reintenta ante deadlocks o errores de serialización.

---

## Guía paso a paso para el profesor

Siga estos pasos en orden para probar la aplicación.

### Paso 1: Prerrequisitos

- **Python 3.11+** y **PostgreSQL** instalados.
- En Windows: PostgreSQL en el PATH, o use `C:\Program Files\PostgreSQL\18\bin\` (ajuste la versión si es distinta).

### Paso 2: Crear la base de datos Pagila

**Opción A – Script automático (Windows PowerShell):**

```powershell
.\setup-pagila.ps1
```

Le pedirá la contraseña de PostgreSQL. Asegúrese de tener la base `pagila` creada y cargada.

**Opción B – Manual:**

```bash
# Crear BD
createdb -U postgres pagila

# Descargar datos (en PowerShell use Invoke-WebRequest -OutFile)
# Linux/Mac: wget ...
# Windows: Invoke-WebRequest -Uri "URL" -OutFile "archivo.sql" -UseBasicParsing

# Cargar schema y datos
psql -U postgres -d pagila -f pagila-schema.sql
psql -U postgres -d pagila -f pagila-data.sql

# Aplicar índices y triggers del proyecto
psql -U postgres -d pagila -f sql/indexes.sql
psql -U postgres -d pagila -f sql/triggers.sql
```

### Paso 3: Configurar .env

En la raíz del proyecto, edite el archivo `.env` y ponga la contraseña real de PostgreSQL:

```
DATABASE_URL=postgresql+psycopg://postgres:SU_CONTRASEÑA_AQUÍ@localhost:5432/pagila
```

### Paso 4: Entorno virtual e instalación

```bash
python -m venv .venv

# Windows:
.\.venv\Scripts\activate

# Linux/Mac:
source .venv/bin/activate

pip install -r requirements.txt
```

### Paso 5: Ejecutar la API

```bash
uvicorn app.main:app --reload
```

Debería ver: `Uvicorn running on http://127.0.0.1:8000`

### Paso 6: Probar en el navegador

1. Abra: **http://127.0.0.1:8000/docs**
2. **Crear renta:** expanda `POST /rentals` → Try it out → body:
   ```json
   { "customer_id": 1, "inventory_id": 1, "staff_id": 1 }
   ```
   → Execute. Debe responder **201 Created** con un `rental_id`.
3. **Intentar renta duplicada:** repita el mismo body. Debe responder **409 Conflict** (concurrencia funcionando).
4. **Devolver:** expanda `POST /returns/{rental_id}` → ponga el `rental_id` obtenido → Execute. Debe responder **200 OK**.
5. **Crear pago:** expanda `POST /payments` → Try it out → body:
   ```json
   { "customer_id": 1, "staff_id": 1, "amount": 5.99 }
   ```
   → Execute. Debe responder **201 Created**.

Si todos los pasos responden correctamente, la aplicación está funcionando.

**Si `POST /payments` devuelve 500** con el error «no se encontró una partición de payment»: la tabla `payment` está particionada por fecha y faltan particiones para años recientes. Ejecuta:
```powershell
psql -U postgres -d pagila -f sql/partitions.sql
```

---

## 1) Prerrequisitos (detalle)

- Python 3.11+ instalado.
- PostgreSQL instalado y accesible por línea de comandos (`createdb`, `psql`, `pgbench`).
- Acceso a Internet para descargar `pagila.sql`.

Clonar o descargar este repositorio en una carpeta local.

---

## 2) Crear y cargar la base de datos Pagila

```bash
createdb pagila

# Descargar el script oficial de Pagila (DVD Rental)
wget https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-schema.sql -O pagila-schema.sql
wget https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-data.sql -O pagila-data.sql

psql -d pagila -f pagila-schema.sql
psql -d pagila -f pagila-data.sql
```

> Si ya tienes `pagila.sql` combinado, simplemente ejecuta:
> `psql -d pagila -f pagila.sql`

---

## 3) Configurar entorno y `DATABASE_URL`

Crear y activar un entorno virtual (opcional pero recomendado):

```bash
python -m venv .venv
source .venv/bin/activate  # En Windows: .venv\Scripts\activate
```

Instalar dependencias:

```bash
pip install -r requirements.txt
```

Configurar la variable de entorno `DATABASE_URL` (ajusta usuario/clave/host/puerto según tu instalación):

```bash
export DATABASE_URL="postgresql+psycopg://postgres:postgres@localhost:5432/pagila"
# En Windows PowerShell (reemplaza TU_PASSWORD por tu contraseña de postgres):
# $env:DATABASE_URL = "postgresql+psycopg://postgres:TU_PASSWORD@localhost:5432/pagila"
```

---

## 4) Aplicar SQL (índices y triggers)

Desde la raíz del proyecto:

```bash
psql -d pagila -f sql/indexes.sql
psql -d pagila -f sql/triggers.sql
```

Esto crea:

- **Índice único parcial** `ux_rental_active_inventory` sobre `rental(inventory_id)` con `WHERE return_date IS NULL`.
- Índices de apoyo para consultas sobre `rental` y `payment`.
- Tabla `audit_log` y triggers de auditoría en `rental` y `payment`.
- Trigger `ensure_positive_payment` que impide pagos con `amount <= 0`.

---

## 5) Ejecutar la API

Desde la raíz del proyecto:

```bash
uvicorn app.main:app --reload
```

La documentación interactiva estará disponible en:

- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/redoc`

---

## 6) Endpoints y ejemplos de prueba (curl)

### 6.1) POST `/rentals`

**Objetivo:** crear una renta nueva.  
**Aislamiento:** `SERIALIZABLE` con reintentos (`40P01`, `40001`).  
**Invariante de concurrencia:** a lo sumo **una renta activa** (`return_date IS NULL`) por `inventory_id`.

Ejemplo:

```bash
curl -X POST http://127.0.0.1:8000/rentals \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1,
    "inventory_id": 1,
    "staff_id": 1
  }'
```

Respuesta exitosa:

```json
{
  "rental_id": 16050,
  "customer_id": 1,
  "inventory_id": 1,
  "staff_id": 1,
  "rental_date": "2024-02-24T18:31:45.123456+00:00"
}
```

**Caso 409 (inventory ya rentado activamente):**

Lanza dos peticiones en paralelo (por ejemplo, desde dos terminales) con el mismo `inventory_id`.  
Una se concretará; la otra recibirá:

```json
{
  "detail": "Ya existe una renta activa para este inventory_id (return_date IS NULL).",
  "code": "RENTAL_ALREADY_ACTIVE"
}
```

### 6.2) POST `/returns/{rental_id}`

**Objetivo:** marcar una renta como devuelta.  
**Aislamiento:** `READ COMMITTED`.  
**Idempotencia:** llamar dos veces no rompe consistencia; el campo `already_returned` indica si ya estaba devuelta.

Ejemplo (primera llamada):

```bash
curl -X POST http://127.0.0.1:8000/returns/16050
```

Respuesta típica:

```json
{
  "rental_id": 16050,
  "return_date": "2024-02-24T18:40:10.000000+00:00",
  "already_returned": false
}
```

Segunda llamada (idempotente):

```bash
curl -X POST http://127.0.0.1:8000/returns/16050
```

Respuesta:

```json
{
  "rental_id": 16050,
  "return_date": "2024-02-24T18:40:10.000000+00:00",
  "already_returned": true
}
```

### 6.3) POST `/payments`

**Objetivo:** registrar un pago.  
**Aislamiento:** `READ COMMITTED`.  
**Validaciones:**

- `amount > 0` (validación de API + trigger `ensure_positive_payment`).
- `customer_id` y `staff_id` deben existir.
- Si se envía `rental_id`, debe existir y pertenecer al `customer_id` dado.
  - Si `rental_id` no existe → **404** `RENTAL_NOT_FOUND`.
  - Si existe pero pertenece a otro cliente → **400** `RENTAL_CUSTOMER_MISMATCH`.

Ejemplo sin `rental_id`:

```bash
curl -X POST http://127.0.0.1:8000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1,
    "staff_id": 1,
    "amount": 5.99
  }'
```

Ejemplo con `rental_id` asociado al mismo cliente:

```bash
curl -X POST http://127.0.0.1:8000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1,
    "staff_id": 1,
    "amount": 3.50,
    "rental_id": 16050
  }'
```

Respuesta exitosa:

```json
{
  "payment_id": 20001,
  "customer_id": 1,
  "staff_id": 1,
  "rental_id": 16050,
  "amount": 3.5,
  "payment_date": "2024-02-24T18:50:00.000000+00:00"
}
```

### 6.4) Formato de errores

Todos los errores siguen el formato:

```json
{ "detail": "...", "code": "..." }
```

Ejemplos:

- 404: `{"detail": "Renta con id 99999 no existe.", "code": "RENTAL_NOT_FOUND"}`
- 400: `{"detail": "El rental_id indicado no pertenece al customer_id proporcionado.", "code": "RENTAL_CUSTOMER_MISMATCH"}`
- 409: `{"detail": "Ya existe una renta activa para este inventory_id (return_date IS NULL).", "code": "RENTAL_ALREADY_ACTIVE"}`
- 422 (validación): `{"detail": "Error de validación en la petición.", "code": "VALIDATION_ERROR", "errors": [...] }`

---

## 7) Ejecutar pgbench con los scripts de concurrencia

### 7.1) scriptA_hot_inventory.sql

Este script simula la lógica de `/rentals` intentando insertar rentas activas para el mismo `inventory_id`.

Editar en `scripts/pgbench/scriptA_hot_inventory.sql` el valor de `\set inventory_id` a un `inventory_id` real de la base.

Ejecutar:

```bash
pgbench -d pagila -c 20 -j 4 -T 30 \
  -f scripts/pgbench/scriptA_hot_inventory.sql
```

Esperado:

- Varias transacciones exitosas si hay inventario disponible (según return_date).
- Errores `unique_violation` en la salida de pgbench cuando el índice parcial detecta más de una renta activa posible.

Al final, validar con la consulta **Q7** (ver sección 8) que no haya inconsistencias.

### 7.2) scriptB_deadlock.sql (provocar deadlock)

Este script actualiza dos `customer_id` en orden `aid` luego `bid`.  
Ejecutar pgbench en **dos terminales** con el mismo script y suficientes clientes/hilos para favorecer interleaving:

```bash
pgbench -d pagila -c 10 -j 4 -T 30 \
  -f scripts/pgbench/scriptB_deadlock.sql
```

En los logs de PostgreSQL deberías ver entradas tipo:

```text
ERROR:  deadlock detected
DETAIL: Process ... waits for ShareLock on transaction ...
SQL state: 40P01
```

Esto demuestra un deadlock real bajo carga concurrente.

### 7.3) scriptB_deadlock_fixed.sql (deadlock evitado)

La versión corregida ordena siempre los `customer_id` con `LEAST`/`GREATEST` y toma locks en ese orden.  
Ejecutar:

```bash
pgbench -d pagila -c 10 -j 4 -T 30 \
  -f scripts/pgbench/scriptB_deadlock_fixed.sql
```

Comparar los logs de PostgreSQL:

- **Antes:** se observan `deadlock detected (40P01)`.
- **Después:** el patrón de deadlock desaparece porque ya no existe ciclo de espera circular; todas las transacciones bloquean filas en el mismo orden lógico.

---

## 8) Validar consistencia de rentas activas

Usando la consulta **Q7** de `sql/queries.sql`:

```sql
SELECT
    inventory_id,
    COUNT(*) AS active_rentals,
    ARRAY_AGG(rental_id ORDER BY rental_id) AS rental_ids
FROM rental
WHERE return_date IS NULL
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY active_rentals DESC, inventory_id;
```

Ejecuta en psql:

```bash
psql -d pagila
-- dentro de psql:
\i sql/queries.sql   -- (opcional, sólo para tener las consultas documentadas)
-- luego pega Q7 directamente
```

**Esperado:** después de aplicar `indexes.sql` y hacer pruebas con `/rentals` y `scriptA_hot_inventory.sql`, **Q7 debe devolver 0 filas**, es decir:

- Para cada `inventory_id`, `COUNT(*) <= 1` donde `return_date IS NULL`.

Esto muestra que el **índice único parcial** + **transacción SERIALIZABLE con reintentos** implementan una estrategia robusta contra la doble renta activa bajo concurrencia.

---

## 9) Estrategia de concurrencia, aislamiento y reintentos

- **Base de datos:** PostgreSQL (Pagila).
- **Driver + ORM:** `psycopg` (psycopg3) vía `SQLAlchemy 2.0 Core`.
- **Transacciones explícitas:** se usan helpers en `app/db.py`:

  - `run_serializable_transaction(conn, fn)` → `SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE`.
  - `run_read_committed_transaction(conn, fn)` → `SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED`.

- **Reintentos con backoff exponencial** (`retry_transaction` en `app/db.py`):

  - Captura `DBAPIError` y mira `orig.pgcode` o `orig.sqlstate`.
  - Si `SQLSTATE` ∈ `{40P01, 40001}`, hace reintentos con backoff: 0.05, 0.1, 0.2, 0.4, 0.8 segundos.
  - Si se agotan los reintentos o el error no es de concurrencia, se propaga la excepción.

- **Niveles de aislamiento por endpoint:**

  - `POST /rentals` → **SERIALIZABLE** (máximo aislamiento, adecuado para asegurar la invariante de unicidad de renta activa).
  - `POST /returns/{rental_id}` → **READ COMMITTED** (suficiente y más barato para una operación idempotente y local a una fila).
  - `POST /payments` → **READ COMMITTED** (operación OLTP típica sin riesgo de anomalías graves para esta lógica).

- **Guardrail fuerte en BD contra doble renta activa:**

  ```sql
  CREATE UNIQUE INDEX IF NOT EXISTS ux_rental_active_inventory
      ON rental (inventory_id)
      WHERE return_date IS NULL;
  ```

  - Aunque varias transacciones SERIALIZABLE intenten crear una renta activa para el mismo `inventory_id`, sólo una insertará la fila; las demás recibirán `unique_violation (23505)` y la API devolverá **409**.
  - Esto garantiza la consistencia incluso en casos donde la lógica de aplicación pudiera ser defectuosa o no considerar todos los caminos.

---

## 10) Cómo se ajusta a la rúbrica (A–E)

- **A – Transacciones y aislamiento:**
  - Endpoints con transacciones explícitas.
  - Uso de **SERIALIZABLE** para `/rentals` y **READ COMMITTED** para `/returns` y `/payments`.
  - `retry_transaction` con reintentos para `40P01` (deadlock) y `40001` (serialization failure).

- **B – Concurrencia y double-rent:**
  - Índice único parcial `ux_rental_active_inventory` impide más de una renta activa por `inventory_id`.
  - `/rentals` está diseñado para trabajar bajo carga concurrente; el caso límite se prueba con `scriptA_hot_inventory.sql` y validación Q7.

- **C – SQL avanzado y triggers:**
  - `sql/queries.sql` contiene 7 consultas con **CTEs**, **window functions**, agregaciones y HAVING.
  - `sql/triggers.sql` implementa:
    - Tabla `audit_log` + trigger genérico `audit_row_change` para `rental` y `payment`.
    - Trigger de negocio `ensure_positive_payment` para impedir `amount <= 0`.

- **D – Pruebas de carga y deadlocks:**
  - `scripts/pgbench/scriptA_hot_inventory.sql` reproduce el patrón de `/rentals` con hot `inventory_id`.
  - `scripts/pgbench/scriptB_deadlock.sql` y `scriptB_deadlock_fixed.sql` muestran el **antes/después** de un deadlock real y su solución al ordenar los locks.

- **E – Calidad de API y documentación:**
  - API REST clara en FastAPI con Pydantic (tipado para requests y responses).
  - Manejo consistente de errores JSON: `{"detail": "...", "code": "..."}`.
  - README detallado en español con pasos de instalación, ejecución, pruebas con `curl`, uso de pgbench y explicación de la estrategia de concurrencia.

