# Guía paso a paso: Uso de la app y prueba completa

Esta guía explica de forma clara cómo configurar, ejecutar y probar por completo la **DVD Rental API (Pagila)**.

---

## Índice

1. [Prerrequisitos](#1-prerrequisitos)
2. [Configurar la base de datos](#2-configurar-la-base-de-datos)
3. [Configurar el proyecto](#3-configurar-el-proyecto)
4. [Ejecutar la API](#4-ejecutar-la-api)
5. [Prueba completa en Swagger UI](#5-prueba-completa-en-swagger-ui)
6. [Prueba completa con curl (opcional)](#6-prueba-completa-con-curl-opcional)
7. [Validación de consistencia (opcional)](#7-validación-de-consistencia-opcional)

---

## 1. Prerrequisitos

Antes de empezar, asegúrate de tener:

| Requisito | Descripción |
|-----------|-------------|
| **Python 3.11+** | [python.org](https://www.python.org/downloads/) |
| **PostgreSQL** | Versión 14 o superior. Debe estar instalado y accesible. |
| **Conexión a Internet** | Para descargar los scripts de Pagila la primera vez. |

---

## 2. Configurar la base de datos

### Opción A: Script automático (recomendado en Windows)

1. Abre **PowerShell** en la carpeta del proyecto.
2. Si PostgreSQL te pide contraseña, puedes definirla antes:
   ```powershell
   $env:PGPASSWORD = "tu_contraseña_postgres"
   ```
3. Ejecuta:
   ```powershell
   .\setup-pagila.ps1
   ```

El script hará automáticamente:
- Crear la base de datos `pagila` (si no existe)
- Descargar `pagila-schema.sql` y `pagila-data.sql`
- Cargar el esquema y los datos
- Aplicar índices, triggers y particiones del proyecto

### Opción B: Manual (Linux/Mac o si prefieres hacerlo a mano)

```bash
# Crear la base de datos
createdb -U postgres pagila

# Descargar Pagila (si no lo tienes)
wget https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-schema.sql -O pagila-schema.sql
wget https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-data.sql -O pagila-data.sql

# Cargar schema y datos
psql -U postgres -d pagila -f pagila-schema.sql
psql -U postgres -d pagila -f pagila-data.sql

# Aplicar scripts del proyecto
psql -U postgres -d pagila -f sql/indexes.sql
psql -U postgres -d pagila -f sql/triggers.sql
psql -U postgres -d pagila -f sql/partitions.sql
```

---

## 3. Configurar el proyecto

### 3.1. Archivo `.env`

En la raíz del proyecto, edita el archivo `.env` y configura la URL de la base de datos:

```
DATABASE_URL=postgresql+psycopg://postgres:TU_CONTRASEÑA@localhost:5432/pagila
```

Reemplaza `TU_CONTRASEÑA` por la contraseña real del usuario `postgres` en PostgreSQL.

### 3.2. Entorno virtual e instalación

En la raíz del proyecto:

```powershell
# Crear el entorno virtual
python -m venv .venv

# Activar (Windows PowerShell)
.\.venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt
```

En Linux/Mac:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## 4. Ejecutar la API

Con el entorno virtual activado:

```bash
uvicorn app.main:app --reload
```

Deberías ver algo como:

```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete.
```

La API está lista. Abre tu navegador en:
- **Swagger UI (documentación interactiva):** http://127.0.0.1:8000/docs
- **ReDoc:** http://127.0.0.1:8000/redoc

---

## 5. Prueba completa en Swagger UI

Sigue estos pasos en orden para realizar una prueba completa de toda la funcionalidad.

### Paso 5.1. Abrir Swagger

1. Ve a **http://127.0.0.1:8000/docs**
2. Verás los tres endpoints principales: `POST /rentals`, `POST /returns/{rental_id}`, `POST /payments`

---

### Paso 5.2. Crear una renta (flujo normal)

1. **Expande** `POST /rentals` y haz clic en **"Try it out"**.
2. En el cuerpo de la petición, usa por ejemplo:
   ```json
   {
     "customer_id": 1,
     "inventory_id": 1,
     "staff_id": 1
   }
   ```
3. Haz clic en **"Execute"**.
4. **Resultado esperado:** Código de estado **201 Created** con una respuesta similar a:
   ```json
   {
     "rental_id": 16050,
     "customer_id": 1,
     "inventory_id": 1,
     "staff_id": 1,
     "rental_date": "2024-02-24T18:31:45.123456+00:00"
   }
   ```
5. **Anota el `rental_id`** que devuelve la respuesta (lo usarás en los siguientes pasos).

---

### Paso 5.3. Comprobar concurrencia (renta duplicada = 409)

1. **Sin devolver** la renta anterior, ejecuta de nuevo `POST /rentals` con el **mismo body**:
   ```json
   {
     "customer_id": 1,
     "inventory_id": 1,
     "staff_id": 1
   }
   ```
2. **Resultado esperado:** Código **409 Conflict** con un mensaje indicando que ya existe una renta activa para ese `inventory_id`.
3. Esto demuestra que el sistema **evita la doble renta** de la misma copia.

---

### Paso 5.4. Registrar la devolución

1. Expande `POST /returns/{rental_id}` y haz clic en **"Try it out"**.
2. En el campo `rental_id`, introduce el `rental_id` que obtuviste en el paso 5.2.
3. Haz clic en **"Execute"**.
4. **Resultado esperado:** Código **200 OK** con algo como:
   ```json
   {
     "rental_id": 16050,
     "return_date": "2024-02-24T18:40:10.000000+00:00",
     "already_returned": false
   }
   ```

---

### Paso 5.5. Comprobar idempotencia de la devolución

1. Ejecuta de nuevo `POST /returns/{rental_id}` con el **mismo** `rental_id`.
2. **Resultado esperado:** Código **200 OK** con `"already_returned": true`.
3. Esto demuestra que la devolución es **idempotente**: llamar dos veces no produce efectos negativos.

---

### Paso 5.6. Crear un pago (sin asociar a renta)

1. Expande `POST /payments` y haz clic en **"Try it out"**.
2. Usa por ejemplo:
   ```json
   {
     "customer_id": 1,
     "staff_id": 1,
     "amount": 5.99
   }
   ```
3. Haz clic en **"Execute"**.
4. **Resultado esperado:** Código **201 Created** con la respuesta del pago creado.

---

### Paso 5.7. Crear un pago asociado a una renta

1. De nuevo en `POST /payments`, usa el mismo cuerpo pero añadiendo el `rental_id`:
   ```json
   {
     "customer_id": 1,
     "staff_id": 1,
     "amount": 3.50,
     "rental_id": 16050
   }
   ```
   (Usa el `rental_id` real que obtuviste en el paso 5.2.)
2. Haz clic en **"Execute"**.
3. **Resultado esperado:** Código **201 Created** con el pago asociado a esa renta.

---

### Paso 5.8. Casos de error (opcional)

| Acción | Resultado esperado |
|--------|--------------------|
| `POST /returns/99999` (renta inexistente) | **404** – Renta no encontrada |
| `POST /payments` con `amount: 0` o negativo | **422** – Error de validación |
| `POST /payments` con `rental_id` de otro cliente | **400** – RENTAL_CUSTOMER_MISMATCH |

---

## Resumen de la prueba completa en Swagger

| # | Endpoint | Body / Parámetro | Código esperado |
|---|----------|------------------|-----------------|
| 1 | POST /rentals | customer_id:1, inventory_id:1, staff_id:1 | 201 Created |
| 2 | POST /rentals | (mismo body) | 409 Conflict |
| 3 | POST /returns/{rental_id} | rental_id del paso 1 | 200 OK |
| 4 | POST /returns/{rental_id} | (mismo rental_id) | 200 OK, already_returned: true |
| 5 | POST /payments | customer_id:1, staff_id:1, amount:5.99 | 201 Created |
| 6 | POST /payments | + rental_id | 201 Created |

Si todos los pasos responden correctamente, la aplicación está funcionando como se espera.

---

## 6. Prueba completa con curl (opcional)

Si prefieres usar la línea de comandos, aquí tienes el flujo equivalente:

```bash
# 1. Crear renta
curl -X POST http://127.0.0.1:8000/rentals \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "inventory_id": 1, "staff_id": 1}'

# Anota el rental_id de la respuesta (ej: 16050)

# 2. Intentar renta duplicada (debe dar 409)
curl -X POST http://127.0.0.1:8000/rentals \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "inventory_id": 1, "staff_id": 1}'

# 3. Devolver (usa el rental_id real)
curl -X POST http://127.0.0.1:8000/returns/16050

# 4. Crear pago
curl -X POST http://127.0.0.1:8000/payments \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "staff_id": 1, "amount": 5.99}'

# 5. Crear pago con rental_id
curl -X POST http://127.0.0.1:8000/payments \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "staff_id": 1, "amount": 3.50, "rental_id": 16050}'
```

En Windows PowerShell, usa comillas simples y escapes distintos; o ejecuta cada comando adaptando las comillas según tu shell.

---

## 7. Validación de consistencia (opcional)

Para comprobar que no hay rentas activas duplicadas en la base de datos (validación interna):

```bash
psql -U postgres -d pagila -c "
SELECT inventory_id, COUNT(*) AS active_rentals
FROM rental
WHERE return_date IS NULL
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY active_rentals DESC;
"
```

**Resultado esperado:** 0 filas. Si devuelve filas, habría inconsistencia (el sistema debería evitarlo gracias al índice único parcial).

---

## Solución de problemas

| Problema | Posible solución |
|----------|------------------|
| Error de conexión a PostgreSQL | Verifica que PostgreSQL esté en ejecución y que `DATABASE_URL` en `.env` sea correcta. |
| 404 en `/docs` | Asegúrate de que la API esté corriendo con `uvicorn app.main:app --reload`. |
| 409 en la primera renta | Es posible que haya una renta activa previa. Prueba con otro `inventory_id` (por ejemplo, 2, 3…). |
| Error al cargar Pagila | Comprueba que `psql` y `createdb` estén en el PATH o que `setup-pagila.ps1` apunte al directorio correcto de PostgreSQL. |

---

## Enlaces rápidos

- **Swagger UI:** http://127.0.0.1:8000/docs  
- **ReDoc:** http://127.0.0.1:8000/redoc  
- **Raíz de la API:** http://127.0.0.1:8000/
