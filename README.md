Documentación Técnica: API de Gestión de Alquiler de DVDs (Pagila)

Estudiantes: 
- Mariajosé Rito Michelena
- Sebastián Fernández Oro Ricaud
- Diego Valdovinos Rodríguez
- Alberto Romero

Materia: Bases de Datos Avanzadas

Fecha: 06 de marzo de 2026

1. Introducción
El presente proyecto intersemestral consiste en el desarrollo y despliegue de una API REST construida con el framework FastAPI, utilizando PostgreSQL como motor de base de datos relacional. La implementación se basa en el esquema Pagila y tiene como objetivo principal demostrar el manejo avanzado de transacciones, niveles de aislamiento y control de concurrencia en un entorno de alta demanda.

2. Arquitectura y Tecnologías
Para garantizar la escalabilidad y el mantenimiento del sistema, se seleccionaron las siguientes tecnologías:

- Backend: Python 3.11+ con FastAPI.

- ORM / Acceso a Datos: SQLAlchemy 2.0 y Psycopg3 para una gestión eficiente de conexiones.

- Base de Datos: PostgreSQL 18, aprovechando sus capacidades nativas para el manejo de bloqueos y triggers.

- Entorno: Gestión de variables de entorno mediante .env para asegurar la portabilidad y seguridad de las credenciales.

3. Implementación de Concurrencia y Aislamiento
El núcleo del proyecto se centra en la integridad de los datos durante procesos concurrentes. Se aplicaron las siguientes estrategias:

Control de "Doble Renta": Se implementó un Índice Único Parcial (ux_rental_active_inventory) en la tabla rental. Este índice garantiza que un mismo inventory_id no pueda tener dos registros con return_date IS NULL simultáneamente.

Niveles de Aislamiento: * El endpoint de creación de rentas opera bajo el nivel SERIALIZABLE, el más estricto en SQL, para prevenir anomalías de lectura y escritura.

Las devoluciones y pagos utilizan READ COMMITTED, optimizando el rendimiento en operaciones que no comprometen la integridad global del inventario.

Manejo de Deadlocks: Se desarrolló un sistema de reintentos con backoff exponencial que captura errores de serialización (40001) y bloqueos mutuos (40P01), asegurando que la transacción se complete tras breves intervalos de espera.

4. Lógica de Negocio y Triggers
Se integraron reglas de negocio directamente en el motor de base de datos para añadir una capa extra de validación:

Auditoría: Uso de triggers para registrar cualquier cambio en las tablas críticas en un audit_log.

Validación de Pagos: Restricción a nivel de base de datos para impedir registros de pagos con montos menores o iguales a cero mediante un trigger de validación.

5. Guía de Instalación y 

5.1 Configuración de Base de Datos
Crear la base de datos: createdb -U postgres pagila

  Ejecutar los scripts en el siguiente orden jerárquico:

  - pagila-schema.sql (Estructura base)

  - pagila-data.sql (Carga de registros)

  - sql/indexes.sql (Optimización y restricciones de unicidad)

  - sql/triggers.sql (Lógica de auditoría y negocio)

5.2 Entorno de Ejecución
Bash
# Instalación de dependencias y activación de entorno
- python -m venv .venv
- .\.venv\Scripts\activate
- pip install -r requirements.txt
  
5.3 Ejecución del Servidor
Para iniciar la API en modo de desarrollo:

- uvicorn app.main:app --reload

6. Pruebas de Carga y Validación
Se incluyeron scripts de pgbench para estresar el sistema. Estas pruebas confirman que, bajo una carga de 20 clientes concurrentes, el sistema gestiona correctamente las excepciones de base de datos sin comprometer la consistencia del inventario de DVDs.

La documentación interactiva y los esquemas de validación de datos (Pydantic) están disponibles en el endpoint:

http://127.0.0.1:8000/docs
