# Proyecto BI — Inscripciones Arte y Cultura

## Documento de estructura, organización y mantenimiento

| Campo | Valor |
|---|---|
| Versión | 1.8 |
| Fecha | 2026-11-09 |
| Autor | Nicolás |
| Estado | Modelo estrella depurado: 529 hechos y 5 dimensiones (`Dim_Oferta` 22, `Dim_Programa` 24, `Dim_Ubicacion` 47, `Dim_Persona` 399, `Dim_Calendario` 365). Cruces con catálogos por llave normalizada (0 estudiantes sin facultad y 0 inscripciones sin departamento). 8 medidas de indicadores y 13 de tiempo. Staging 01–08 no cargado y datos personales ocultos. Pendiente: dashboard. |
| Nombre provisional del proyecto | `Proyecto` |

---

## 1. Propósito del documento

Este documento explica cómo está organizado el proyecto de inteligencia de negocio de **Inscripciones Arte y Cultura**, por qué se tomó cada decisión y cómo agregar datos nuevos sin romper el modelo.

Está pensado para que cualquier persona —incluido el autor en el futuro— pueda:

- Entender qué hay en cada carpeta y para qué sirve.
- Saber qué archivos lee Power BI y cuáles no.
- Agregar un año, semestre, disciplina o proceso nuevo.
- Mantener la fuente ordenada y trazable.
- Evitar duplicados, errores de nombres y pérdida de información.

La idea central es separar tres mundos:

1. **Datos**: lo que llega, lo que se usa y lo que se conserva.
2. **Configuración**: el mapeo y los catálogos que Power Query necesita.
3. **Documentación**: las reglas, decisiones y explicaciones para humanos.

---

## 2. Resumen del proyecto

La fuente son las inscripciones a los grupos de Arte y Cultura de la universidad. Los datos están organizados por:

- **Periodo**: 2025-01 y 2025-02.
- **Disciplina**: Danza Folclórica, Danza Urbana / Baile Deportivo, Música, Salsa y Bachata, Teatro.
- **Población**: estudiantes y no estudiantes.
- **Proceso**: formación, planta, semillero, representativo, extensión.
- **Grupo**: Quynza, Armonía Amazónica, Ensamble de Guitarras, Waira, etc.

Los datos son de prueba, pero se organizan como si fueran reales para demostrar un proceso completo de BI: conexión, limpieza, modelado, medidas y dashboard.

### Situación actual de la fuente

| Concepto | Valor |
|---|---:|
| Archivos en `01-Crudos` | 14 |
| Archivos canónicos | 14 |
| Copias / casos especiales | 0 (la copia de Danza Urbana S2 se movió a histórico) |
| Periodos | 2 |
| Disciplinas | 5 |
| Poblaciones | 2 |
| Hojas de datos visibles | 24 |
| Hojas ocultas de catálogo | 2 (`Obj 2,4`) |
| Filas en el mapeo | 26 (24 visibles + 2 ocultas) |

---

## 3. Principios de organización

### 3.1. El original no se toca

Los archivos que llegaron se guardan en `00-Original`. No se editan, no se renombran y no se conectan a Power BI. Son la evidencia de lo que entregó la fuente.

### 3.2. Un archivo por periodo + disciplina + población

Un archivo no se crea por grupo ni por proceso. Se crea por:

```text
AAAA-SS_disciplina_publico.xlsx
```

Ejemplo:

```text
2025-01_danza-folclorica_estudiantes.xlsx
2025-01_danza-folclorica_no-estudiantes.xlsx
```

Los grupos y procesos viven **dentro** del archivo, como hojas.

### 3.3. Una hoja por proceso

Dentro de cada archivo, las hojas representan el proceso:

```text
formacion
planta
semillero
representativo
extension
quynza
```

Esto permite que Power Query sepa qué proceso tiene cada fila sin depender de nombres de archivos.

### 3.4. El mapeo es el contrato

`mapeo_fuentes.xlsx` es la tabla que conecta el mundo físico (archivos y hojas) con el mundo lógico (periodo, disciplina, grupo, proceso, público y layout). Sin mapeo, Power Query tendría que adivinar o habría que hacer una consulta por cada archivo.

### 3.5. Los catálogos normalizan, no inventan datos

Los catálogos no agregan personas: agregan significado. Sirven para unificar variantes como:

- `ASMET SALUD`, `ASMETSALUD`, `ASMED SALUD` → `Asmet Salud`.
- `FLORENCIA`, `FLORENCIA CAQUETA`, `FLORENCIA, CAQUETA` → `Florencia`.
- `GRADUDOS` y `EGRESADOS` → `Egresado/Graduado`.
- `LIC.ARTISTICA`, `LICENCIATURA EN ARTISTICA` → `Lic. Educación Artística y Cultural`.

### 3.6. Power BI no lee todo

Power BI lee únicamente:

```text
01-Datos/01-Crudos
01-Datos/02-Externos/mapeo_fuentes.xlsx
01-Datos/02-Externos/catalogos.xlsx
```

No lee `00-Original`, `03-Historico` ni `03-Documentacion`.

### 3.7. Todo cambio se documenta

Cada archivo nuevo, renombrado, movido o corregido se registra en la bitácora de cambios. Cada decisión de limpieza se registra en `02_reglas_y_decisiones.md`.

---

## 4. Estructura final del proyecto

```text
Proyecto/
│
├── 01-Datos/
│   │
│   ├── 00-Original/
│   │   └── 2025/
│   │       ├── 2025-01/
│   │       └── 2025-02/
│   │
│   ├── 01-Crudos/
│   │   └── 2025/
│   │       ├── 2025-01/
│   │       └── 2025-02/
│   │
│   ├── 02-Externos/
│   │   ├── mapeo_fuentes.xlsx
│   │   └── catalogos.xlsx
│   │
│   └── 03-Historico/
│       └── 2025/
│           ├── 2025-01/
│           │   └── teatro-duplicado.xlsx
│           └── 2025-02/
│               └── danza-urbana-copia-salsa.xlsx
│
├── 02-PowerBI/
│   ├── proyecto.pbix
│   ├── proyecto_backup_AAAAMMDD_HHMM.pbix   (copias de seguridad)
│   ├── 01_02_Filtro_Excel.pq
│   ├── 08_Fact_Limpia.pq
│   ├── Cat_Periodos.pq
│   ├── Dim_Calendario.pq
│   ├── Dim_Oferta.pq
│   ├── Dim_Persona.pq
│   └── Medidas_Tiempo.dax
│       (pendiente: tema del dashboard)
│
├── 03-Documentacion/
│   ├── 01_diccionario_datos.xlsx
│   ├── 02_reglas_y_decisiones.md
│   ├── 03_modelo_estrella.md
│   ├── 04_manual_actualizacion.md
│   ├── instrucciones/
│   └── 00-Formatos/
│       └── Formato Libro.docx
│
└── README.md
```

No existen `04-Entregables` ni `05-Respaldos`. Si se necesita entregar un informe o una presentación, se guarda dentro de `03-Documentacion` o fuera del proyecto. Los respaldos del modelo son copias `proyecto_backup_AAAAMMDD_HHMM.pbix` en `02-PowerBI`, hechas antes de cada cambio. Los respaldos de catálogos van a `01-Datos/03-Historico`.

---

## 5. Descripción de cada carpeta

### 5.1. `01-Datos/00-Original`

**Qué es:** los archivos tal como llegaron, sin modificar.

**Para qué sirve:**

- Tener evidencia de la fuente original.
- Comparar si un dato cambió.
- Recuperar información si una limpieza sale mal.
- Responder preguntas del tipo “¿de dónde salió esto?”.

**Qué va aquí:**

- Los 18 archivos originales de 2025.
- El ZIP de entrega, si se conserva.

**Qué no va aquí:**

- Archivos ya limpios.
- Archivos renombrados.
- El `.pbix`.

**Regla:** solo lectura. Power Query no se conecta a esta carpeta.

---

### 5.2. `01-Datos/01-Crudos`

**Qué es:** la fuente de trabajo que lee Power Query.

**Para qué sirve:**

- Alimentar el modelo de Power BI.
- Tener los archivos renombrados y organizados por periodo, disciplina y población.
- Separar estudiantes de no estudiantes.

**Qué va aquí:**

- Archivos `AAAA-SS_disciplina_publico.xlsx`.
- Hojas por proceso.
- Hojas ocultas de catálogo, si se conservan, pero excluidas del modelo.

**Qué no va aquí:**

- Duplicados exactos.
- Versiones viejas.
- Archivos originales.
- El `.pbix`.
- Documentación.

**Regla:** todo archivo que esté aquí se carga o se mapea. Si no debe cargarse, se mueve a `03-Historico` o se marca `incluir = No` en el mapeo.

#### Inventario 2025

| Periodo | Archivo | Población | Hojas | Filas crudas |
|---|---|---|---|---:|
| 2025-01 | `2025-01_danza-folclorica_estudiantes.xlsx` | Estudiantes | `formacion`, `quynza` | 71 |
| 2025-01 | `2025-01_danza-folclorica_no-estudiantes.xlsx` | No estudiantes | `extension` | 2 |
| 2025-01 | `2025-01_danza-urbana_estudiantes.xlsx` | Estudiantes | `formacion`, `planta` | 54 |
| 2025-01 | `2025-01_musica_estudiantes.xlsx` | Estudiantes | `formacion`, `representativo` | 94 |
| 2025-01 | `2025-01_musica_no-estudiantes.xlsx` | No estudiantes | `formacion`, `representativo` | 24 |
| 2025-01 | `2025-01_salsa-bachata_estudiantes.xlsx` | Estudiantes | `planta`, `semillero` | 51 |
| 2025-01 | `2025-01_teatro_estudiantes.xlsx` | Estudiantes | `planta`, `formacion` | 16 |
| 2025-02 | `2025-02_danza-folclorica_estudiantes.xlsx` | Estudiantes | `formacion`, `quynza`, `[oculta] Obj 2,4` | 56 |
| 2025-02 | `2025-02_danza-folclorica_no-estudiantes.xlsx` | No estudiantes | `extension`, `[oculta] Obj 2,4` | 2 |
| 2025-02 | `2025-02_musica_estudiantes.xlsx` | Estudiantes | `formacion`, `representativo` | 68 |
| 2025-02 | `2025-02_musica_no-estudiantes.xlsx` | No estudiantes | `formacion`, `representativo` | 24 |
| 2025-02 | `2025-02_salsa-bachata_estudiantes.xlsx` | Estudiantes | `planta`, `semillero` | 58 |
| 2025-02 | `2025-02_teatro_estudiantes.xlsx` | Estudiantes | `formacion` | 16 |
| 2025-02 | `2025-02_teatro_no-estudiantes.xlsx` | No estudiantes | `formacion` | 4 |

**Nota:** las filas son crudas; incluyen duplicados, bloque sintético y posibles errores. La deduplicación se hace en Power Query.

#### Layouts de los archivos

| Layout | Columnas | Nombre en | Encabezado | Población |
|---|---:|---|---:|---|
| `04-06` | 24 (A–X) | Columna C | Fila 4 | Estudiantes |
| `04-05` | 16 (A–P) | Columna E | Fila 3 | No estudiantes |
| `04-06-EXT` | 16 (A–P) | Columna E | Fila 3 | Hoja `extension` dentro de un archivo 04-06 |

La hoja `extension` dentro de un archivo de estudiantes usa el layout `04-05`. Es la única excepción real.

---

### 5.3. `01-Datos/02-Externos`

**Qué es:** la carpeta de configuración y referencia que Power Query necesita.

**Para qué sirve:**

- Decirle a Power Query qué es cada archivo y cada hoja.
- Normalizar valores que vienen escritos de muchas formas.
- Mantener listas estables para filtros, orden y colores.

**Qué va aquí:**

- `mapeo_fuentes.xlsx`.
- `catalogos.xlsx` con hojas de periodos, grupos, programas, dependencias, municipios, EPS, beneficios y comunidades.

**Qué no va aquí:**

- Datos de personas.
- El `.pbix`.
- Documentación narrativa.

#### `mapeo_fuentes.xlsx`

Es la tabla central del proyecto. Debe tener una fila por archivo y hoja.

| Columna | Ejemplo | Uso |
|---|---|---|
| `archivo` | `2025-01_danza-folclorica_estudiantes.xlsx` | Une con `Folder.Files` |
| `hoja` | `formacion` | Une con `Excel.Workbook` |
| `periodo` | `2025-01` | Dimensión periodo |
| `disciplina` | `Danza Folclórica` | Dimensión grupo |
| `publico` | `Estudiantes` | Dimensión comunidad |
| `proceso` | `Formación` | Dimensión grupo |
| `grupo` | `Formación en Danza Folclórica` | Dimensión grupo |
| `layout` | `04-06` | Parser de columnas |
| `incluir` | `Sí` / `No` | Filtro |
| `notas` | `copia de Salsa` | Documentación |

Ejemplo:

| archivo | hoja | periodo | disciplina | publico | proceso | grupo | layout | incluir | notas |
|---|---|---|---|---|---|---|---|---|---|
| `2025-01_danza-folclorica_estudiantes.xlsx` | `formacion` | 2025-01 | Danza Folclórica | Estudiantes | Formación | Formación en Danza Folclórica | 04-06 | Sí | |
| `2025-01_danza-folclorica_estudiantes.xlsx` | `quynza` | 2025-01 | Danza Folclórica | Estudiantes | Representativo | Quynza | 04-06 | Sí | |
| `2025-01_danza-folclorica_no-estudiantes.xlsx` | `extension` | 2025-01 | Danza Folclórica | No estudiantes | Extensión | Quynza | 04-05 | Sí | Corregir comunidad/división |
| `2025-02_danza-folclorica_estudiantes.xlsx` | `Obj 2,4` | 2025-02 | — | — | — | — | — | No | Catálogo, no roster |

**Regla:** si un archivo o hoja no está en el mapeo, no se carga. Una consulta de control debe listar los archivos sin mapeo.

#### `catalogos.xlsx`

Un solo archivo con varias hojas:

| Hoja | Contenido |
|---|---|
| `periodos` | 2025-01, 2025-02, 2026-01… |
| `grupos` | disciplina, grupo, proceso, público, orden |
| `programas` | programa, facultad, nivel |
| `dependencias` | facultad, vicerrectoría, oficina o programa de no estudiantes |
| `municipios` | municipio, departamento |
| `eps` | EPS normalizada |
| `beneficios` | Gratuidad, Renta Joven, Subsidio, etc. |
| `comunidades` | Estudiante, Docente, Egresado/Graduado, etc. |

Los catálogos se editan a mano. Si aparece un valor nuevo, se agrega una fila. Una consulta de control debe avisar si hay valores sin catálogo.

---

### 5.4. `01-Datos/03-Historico`

**Qué es:** la carpeta de duplicados y versiones anteriores.

**Para qué sirve:**

- Sacar de `01-Crudos` los archivos que no deben cargarse.
- Conservar evidencia de versiones anteriores.
- Evitar que Power Query lea dos veces el mismo roster.

**Qué va aquí:**

- El archivo duplicado de Teatro S1.
- Versiones `_v01`, `_v02` cuando se reemplacen.
- Archivos que se descartaron por duplicados.

**Qué no va aquí:**

- Archivos vigentes.
- El `.pbix`.

**Regla:** Power Query no lee esta carpeta.

---

### 5.5. `02-PowerBI`

**Qué es:** el archivo de Power BI y el código fuente reproducible de sus consultas y medidas.

**Para qué sirve:**

- Construir el modelo, las medidas y el dashboard.
- Guardar copias de seguridad del `.pbix`.
- Conservar el código M y DAX fuera del `.pbix`, para revisarlo y versionarlo.

**Qué va aquí:**

- `proyecto.pbix`.
- Copias `proyecto_backup_AAAAMMDD_HHMM.pbix`.
- Código M (`.pq`) y DAX (`.dax`).
- Pendiente: tema del dashboard (todavía no existe `tema.json`).

**Qué no va aquí:**

- Datos.
- Documentación.
- Archivos originales.

**Regla:** el `.pbix` no debe contener datos fuente duplicados; debe conectarse a `01-Crudos` y `02-Externos`.

---

### 5.6. `03-Documentacion`

**Qué es:** la memoria del proyecto para humanos.

**Para qué sirve:**

- Explicar qué se hizo y por qué.
- Facilitar la sustentación.
- Permitir que otra persona actualice el proyecto.
- Evitar depender de la memoria del autor.

**Qué va aquí:**

| Archivo | Contenido |
|---|---|
| `01_diccionario_datos.xlsx` | Campo, tipo, definición, fuente, regla de limpieza |
| `02_reglas_y_decisiones.md` | Reglas de limpieza, exclusiones, supuestos |
| `03_modelo_estrella.md` | Hechos, dimensiones, relaciones, medidas |
| `04_manual_actualizacion.md` | Paso a paso para agregar un año o semestre |
| `00-Formatos/Formato Libro.docx` | Formato de entrega del curso |

**Regla:** Power Query no lee esta carpeta, salvo que se decida poner el mapeo aquí. En la estructura final, el mapeo vive en `02-Externos` para evitar confusión.

---

### 5.7. `README.md`

**Qué es:** la puerta de entrada al proyecto.

**Para qué sirve:**

- Explicar en 5 minutos qué es el proyecto.
- Mostrar la estructura.
- Indicar dónde está cada cosa.
- Explicar cómo actualizar.

Debe incluir:

- Nombre del proyecto y autor.
- Objetivo.
- Estructura de carpetas.
- Convención de nombres.
- Qué lee Power BI.
- Cómo agregar datos nuevos.
- Dónde está la documentación.
- Estado del proyecto.

---

## 6. Convenciones de nombres

### 6.1. Carpetas

- Minúsculas, sin tildes, sin ñ, sin espacios.
- Prefijos numéricos para ordenar: `01-Datos`, `02-PowerBI`, `03-Documentacion`.
- Año: `2025`, `2026`.
- Semestre: `2025-01`, `2025-02` (con cero a la izquierda).

### 6.2. Archivos

```text
AAAA-SS_disciplina_publico.xlsx
```

| Campo | Valores |
|---|---|
| Año | `2025`, `2026` |
| Semestre | `01`, `02` |
| Disciplina | `danza-folclorica`, `danza-urbana`, `musica`, `salsa-bachata`, `teatro` |
| Público | `estudiantes`, `no-estudiantes` |
| Versión | `v01`, `v02` (opcional) |

Ejemplos:

```text
2025-01_danza-folclorica_estudiantes.xlsx
2025-01_danza-folclorica_no-estudiantes.xlsx
2025-02_musica_estudiantes.xlsx
2026-01_teatro_estudiantes.xlsx
```

**No usar:**

- `estudiantes2`, `final`, `final2`, `corregido`.
- Espacios, tildes, ñ.
- `04-05` o `04-06` en el nombre.
- Fechas ambiguas como `2025-1`.

### 6.3. Hojas

- `formacion`
- `planta`
- `semillero`
- `representativo`
- `extension`
- `quynza`

Minúsculas, sin tildes, sin espacios. Una hoja por proceso o grupo.

### 6.4. Columnas del modelo

- `snake_case`: `persona_key`, `periodo`, `disciplina`, `grupo`, `proceso`, `publico`, `programa`, `facultad`, `promedio_semestre`.
- Nombres “bonitos” solo en el reporte, no en el modelo.

---

## 7. Cómo se conecta Power BI

Power Query lee:

```text
01-Datos/01-Crudos
01-Datos/02-Externos/mapeo_fuentes.xlsx
01-Datos/02-Externos/catalogos.xlsx
```

Flujo recomendado:

```text
Folder.Files(01-Crudos)
    → Excel.Workbook
    → filtrar hojas visibles
    → unir con mapeo_fuentes
    → normalizar layout 04-06
    → normalizar layout 04-05
    → agregar columnas faltantes
    → Fact_Inscripciones
    → dimensiones
    → modelo estrella
```

### Reglas técnicas

- `Folder.Files` es recursivo: encuentra los archivos de `2025/2025-01`, `2026/2026-01`, etc.
- Filtrar `Extension = ".xlsx"` y `Name` que no empiece con `~$`.
- Excluir `03-Historico` por ruta.
- `Excel.Workbook([Content], null, true)` para listar hojas.
- Filtrar `Hidden = false` o excluir `Obj 2,4 Programas y Facultades`.
- No usar “Combinar archivos” a ciegas: hay dos layouts.
- Hacer `Staging_04_06` y `Staging_04_05` por separado.
- Agregar columnas nulas a 04-05 para los campos que no tiene.
- Unir en `Fact_Inscripciones`.
- Deduplicar por persona + periodo + disciplina + grupo + proceso.
- Usar `try ... otherwise null` para fechas y números.

---

## 8. Escalabilidad

### 8.1. Nuevo semestre

1. Crear `01-Datos/01-Crudos/2026/2026-01/`.
2. Agregar los archivos con la convención.
3. Agregar una fila por archivo/hoja al mapeo.
4. Agregar el periodo en la hoja `periodos` de `catalogos.xlsx`, con `periodo`, `anio`, `semestre`, `nombre`, `orden`, `fecha_inicio` y `fecha_fin`. Basta con esto para que `Dim_Calendario` se extienda al año nuevo y las medidas de tiempo lo incluyan, sin cambiar código. Las fechas deben ser semestres de 6 meses exactos: `AAAA-01` del 1 de enero al 30 de junio y `AAAA-02` del 1 de julio al 31 de diciembre (ver "Inteligencia de tiempo" en `03_modelo_estrella.md`).
5. Refrescar Power Query.
6. Revisar `Control_SinMapeo`.
7. Guardar una nueva versión del `.pbix`.

### 8.2. Nuevo año

Igual que el anterior, creando `2026/2026-01` y `2026/2026-02`. No se cambia código si el layout es el mismo.

### 8.3. Nueva disciplina

1. Crear el par de archivos `estudiantes` / `no-estudiantes` si aplica.
2. Agregar filas al mapeo.
3. Agregar la disciplina/grupo a `catalogos.xlsx`.
4. Refrescar.

### 8.4. Nuevo proceso o grupo

No se crea archivo. Se agrega una hoja o una columna `proceso`/`grupo` dentro del archivo existente.

### 8.5. Nuevo layout

1. Agregar un valor nuevo en `layout`, por ejemplo `2026-04-06`.
2. Agregar una rama en `fnNormalizarHoja`.
3. Probar con un archivo.
4. Documentar en `02_reglas_y_decisiones.md`.

### 8.6. Nuevas columnas

1. Agregarlas al esquema común.
2. Agregarlas al mapeo si es necesario.
3. Los archivos viejos quedan con `null`.
4. Documentar.

### 8.7. Nueva versión de un archivo

1. Guardar como `..._v02.xlsx`.
2. Mover `_v01` a `03-Historico`.
3. Actualizar el mapeo.
4. Registrar en la bitácora.

---

## 9. Mantenibilidad

### 9.1. Consultas de control

Crear en Power Query:

| Consulta | Para qué |
|---|---|
| `Control_SinMapeo` | Archivos u hojas que no están en el mapeo |
| `Control_MapeoInvalido` | Filas del mapeo que apuntan a archivos que no existen |
| `Control_GruposSinCatalogo` | Grupos que no están en `catalogos.xlsx` |
| `Control_ProgramasSinCatalogo` | Programas sin facultad |
| `Control_Duplicados` | Persona + periodo + grupo + proceso repetidos |
| `Control_FechasInvalidas` | Fechas nulas, futuras o imposibles |
| `Control_PromediosFueraRango` | Promedios fuera de 0–5 |
| `Control_Calidad` | Resumen de filas crudas, excluidas y marcadas |

### 9.2. Versionado

- Archivos fuente: `_v01`, `_v02`; el anterior a `03-Historico`.
- `.pbix`: antes de cada cambio se copia `proyecto.pbix` como `proyecto_backup_AAAAMMDD_HHMM.pbix` en `02-PowerBI` (fecha y hora de la copia).
- `catalogos.xlsx`: antes de editarlo se copia a `01-Datos/03-Historico/catalogos_antes_vX.Y_AAAAMMDD.xlsx`.
- No usar “final”, “final2”, “corregido”.

### 9.3. Registro de decisiones

Cada decisión de limpieza se documenta en `02_reglas_y_decisiones.md`:

- Qué se excluyó.
- Por qué se excluyó.
- Cuántas filas afectó.
- Cómo se puede revertir.

### 9.4. Privacidad

Aunque los datos sean de prueba, no exponer en capturas:

- Documento de identidad.
- Nombre completo.
- Teléfono.
- Correo.
- Fecha de nacimiento.
- EPS.
- Discapacidad.
- Etnia.
- Condición de víctima.

En el dashboard, usar agregados y nombres enmascarados.

---

## 10. Excepciones y pendientes conocidos

| Pendiente | Archivo | Acción | Estado |
|---|---|---|---|
| Comunidad/división intercambiadas | `2025-01_danza-folclorica_no-estudiantes.xlsx` | Intercambiar en Power Query. Sigue sin resolver en v1.8: 1 inscripción queda con comunidad "No aplica" y dependencia "Extensión Social" | Pendiente |
| Fecha imposible `2025-08-21` | `2025-02_danza-folclorica_no-estudiantes.xlsx` | Dejar nula y marcar. Sigue cargada como fecha de nacimiento en v1.8 | Pendiente |
| Hojas ocultas `Obj 2,4` | Folk S2 estudiantes y no-estudiantes | Excluidas con `incluir = No` en el mapeo; 0 filas cargadas | Hecho |
| Copia de Salsa | `2025-02_danza-urbana_estudiantes.xlsx` | Movida a `03-Historico/2025/2025-02/danza-urbana-copia-salsa.xlsx` | Hecho |
| Duplicados internos | Música, Folk, Salsa | Deduplicados en `08_Fact_Limpia` (540 → 529 filas) | Hecho |
| Bloque de prueba | `2025-01_salsa-bachata_estudiantes.xlsx` | Se conserva tal cual; documentar como dataset simulado | Decidido |
| Filas fantasma | Teatro S2 | Ya eliminadas | Hecho |
| Cruces con catálogos sensibles a tildes y mayúsculas | `08_Fact_Limpia` | Llave normalizada `fnClave` (v1.8) | Hecho |
| Categorías con tilde mal clasificadas | `08_Fact_Limpia` | `fnU` en etnia, comunidad, beneficio y discapacidad (v1.8) | Hecho |
| Variantes de grupo artístico | `catalogos.xlsx` | Hoja `grupos_artisticos` (v1.8) | Hecho |
| Facultades en mayúsculas sostenidas | `catalogos.xlsx` | Nombres unificados (v1.8) | Hecho |
| Archivos temporales `~$` rompen la actualización | `01_Archivos`, `02_Hojas` | Paso `SoloExcel` (v1.8) | Hecho |
| Staging 01–08 cargado con datos personales | `proyecto.pbix` | Convertido en consultas no cargadas (v1.8) | Hecho |
| 10 documentos con dos `persona_key` | `08_Fact_Limpia` | Se conservan: la llave incluye el nombre para evitar colisiones (ver `05_limpieza_power_query.md`) | Decidido |
| `% Victimas`: 44,3 % frente a 44,6 % esperado | `Dim_Persona` | 1 persona de 2025-2 difiere de la simulación (163 frente a 164 "Sí"). Revisar el criterio de qué fila de la persona usa `Dim_Persona` | Pendiente |
| Archivo suelto `2026-01_musica_estudiantes.xlsx` | Raíz del proyecto | Ubicarlo en `01-Crudos/2026/2026-01` con su mapeo, o moverlo a histórico | Pendiente |

### Decisión sobre Danza Urbana S2

El archivo `2025-02_danza-urbana_estudiantes.xlsx` contenía la misma nómina de `2025-02_salsa-bachata_estudiantes.xlsx`. Se movió a `03-Historico/2025/2025-02/danza-urbana-copia-salsa.xlsx` y se eliminaron sus filas del mapeo y del catálogo de grupos. Danza Urbana S2 queda sin datos; si más adelante aparece una nómina real, se agrega como archivo nuevo.

---

## 11. Bitácora de cambios

### Cómo llevarla

Registrar cada cambio relevante:

- Fecha.
- Versión del documento o del archivo.
- Qué se hizo.
- Archivos afectados.
- Por qué se hizo.
- Responsable.

### Plantilla

| Fecha | Versión | Cambio | Archivos afectados | Responsable | Notas |
|---|---|---|---|---|---|
| 2026-10-28 | 1.0 | Creación del documento de estructura | Todo el proyecto | Nicolás | Estructura inicial |
| 2026-10-29 | 1.1 | Copia de Danza Urbana S2 movida a histórico; mapeo y catálogo de grupos actualizados | `01-Datos/01-Crudos`, `01-Datos/03-Historico`, `02-Externos` | Nicolás | Danza Urbana S2 queda sin datos |
| 2026-11-01 | 1.2 | Creación de `08_Fact_Limpia` en el modelo: 524 filas, 48 columnas visibles, sin EPS con correo | `02-PowerBI/proyecto.pbix`, `02-PowerBI/08_Fact_Limpia.pq`, `03-Documentacion/05_limpieza_power_query.md` | Nicolás | Fact table lista para dimensiones |
| 2026-11-01 | 1.3 | Corrección de codificación UTF-8, bandera `bloque_desplazado` sin nulos y eliminación de tablas automáticas de fecha | `02-PowerBI/proyecto.pbix`, `02-PowerBI/08_Fact_Limpia.pq` | Nicolás | Validado tras reabrir el PBIX |
| 2026-11-01 | 1.4 | Centralización de rutas: `RutaExternos`, `RutaMapeo` y `RutaCatalogos`; `03_Mapeo` y `08` sin rutas fijas | `02-PowerBI/proyecto.pbix`, `02-PowerBI/08_Fact_Limpia.pq` | Nicolás | `03_Mapeo` quedó en 26 filas |
| 2026-11-01 | 1.5 | Creación del modelo estrella: `Dim_Periodo`, `Dim_Oferta`, `Dim_Programa`, `Dim_Ubicacion`, `Dim_Persona`, `Fact_Inscripciones` y 8 medidas | `02-PowerBI/proyecto.pbix`, `03-Documentacion/03_modelo_estrella.md` | Nicolás | 5 relaciones; staging oculto |
| 2026-11-01 | 1.6 | Ajuste del grano: `programa`, `publico` y `grupo_artistico` en la deduplicación; 529 hechos | `02-PowerBI/proyecto.pbix`, `02-PowerBI/08_Fact_Limpia.pq` | Nicolás | Se conservaron 5 combinaciones válidas |
| 2026-11-09 | 1.7 | Creación de Dim_Calendario desde Cat_Periodos, fecha_periodo en el hecho, relación por fecha, eliminación de Dim_Periodo y de fechas automáticas, 13 medidas de tiempo | `02-PowerBI/proyecto.pbix`, `02-PowerBI/Cat_Periodos.pq`, `02-PowerBI/Dim_Calendario.pq`, `02-PowerBI/Medidas_Tiempo.dax`, `03-Documentacion/03_modelo_estrella.md` | Juan Manuel | `RutaDatos` corregida a `Proyecto\Proyecto`; respaldo `proyecto_backup_20261109_0926.pbix` |
| 2026-11-09 | 1.8 | Corrección de pendientes: cruces con catálogos por llave normalizada; tildes en etnia, comunidad, beneficio y discapacidad; hoja `grupos_artisticos`; facultades unificadas; `Dim_Oferta` con modalidad y orden; `Table.Buffer` antes de deduplicar; bandera de promedio sin nulos; filtro `.xlsx`/`~$`; nuevo `% Victimas`; formatos de "Indicadores"; columnas personales y llaves ocultas; staging 01–08 no cargado | `01-Datos/02-Externos/catalogos.xlsx`, `02-PowerBI/proyecto.pbix`, `02-PowerBI/08_Fact_Limpia.pq`, `02-PowerBI/Dim_Oferta.pq`, `02-PowerBI/Dim_Persona.pq`, `02-PowerBI/01_02_Filtro_Excel.pq`, `03-Documentacion/03_modelo_estrella.md`, `03-Documentacion/05_limpieza_power_query.md`, `01-Datos/02-Externos/README.md` | Juan Manuel | Respaldos `proyecto_backup_20261109_0951.pbix` y `03-Historico/catalogos_antes_v1.8_20261109.xlsx`; `% Victimas` = 44,3 % (esperado 44,6 %) |

### Reglas

- Si se agrega un archivo, se registra.
- Si se renombra, se registra.
- Si se mueve, se registra.
- Si se cambia una regla de limpieza, se registra.
- Si se cambia el mapeo, se registra.

---

## 12. Glosario

| Término | Significado |
|---|---|
| **Original** | Archivo tal como llegó, sin modificar |
| **Crudo** | Archivo renombrado y organizado, listo para Power Query |
| **Histórico** | Duplicados y versiones anteriores |
| **Mapeo** | Tabla que dice qué es cada archivo/hoja |
| **Catálogo** | Tabla de referencia para normalizar valores |
| **Layout** | Estructura de columnas: 04-06, 04-05, 04-06-EXT |
| **Proceso** | Formación, planta, semillero, representativo, extensión |
| **Público** | Estudiantes o no estudiantes |
| **Hecho** | Tabla de eventos o inscripciones |
| **Dimensión** | Tabla de contexto: persona, periodo, grupo, programa |
| **Staging** | Capa intermedia de limpieza en Power Query |
| **PBIP** | Proyecto de Power BI basado en archivos, opcional para Git |

---

## 13. Próximos pasos

1. Revisar `02-Externos/mapeo_fuentes.xlsx` con las 26 filas de 2025 (24 visibles + 2 ocultas).
2. Revisar `02-Externos/catalogos.xlsx` con las hojas de periodos, grupos, programas, dependencias, municipios, EPS, beneficios y comunidades.
3. Conectar Power BI a `01-Crudos`.
4. Crear `Staging_04_06` y `Staging_04_05`.
5. Construir `Fact_Inscripciones`.
6. Crear dimensiones y relaciones.
7. Crear medidas DAX.
8. Construir el dashboard.
9. Documentar las decisiones de limpieza.
10. Agregar la página de calidad.

---

## 14. Resumen final

- **Un archivo** = periodo + disciplina + población.
- **Una hoja** = proceso o grupo.
- **Una fila** = persona.
- **El mapeo** = contrato entre archivos y modelo.
- **Los catálogos** = normalización.
- **Power BI** lee solo `01-Crudos` y `02-Externos`.
- **La documentación** es para humanos y para la sustentación.
- **La escalabilidad** se logra agregando carpetas, archivos y filas al mapeo, no rehaciendo el modelo.

Con esta estructura, el proyecto puede crecer a 2026, 2027 o más disciplinas sin romper el dashboard, siempre que se mantengan la convención de nombres, el mapeo y los catálogos.
