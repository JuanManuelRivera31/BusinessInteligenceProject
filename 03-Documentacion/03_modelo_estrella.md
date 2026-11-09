# Modelo estrella

## Objetivo

Organizar `08_Fact_Limpia` en un modelo estrella para el dashboard de inscripciones de Arte y Cultura.

## Grano del hecho

Una fila de `Fact_Inscripciones` representa:

```text
persona
× periodo
× disciplina
× público
× grupo
× grupo artístico
× proceso
× programa
```

La llave de deduplicación de `08_Fact_Limpia` incluye `programa` para no perder personas con más de una carrera en el mismo periodo, disciplina, grupo y proceso.

## Tablas del modelo

### Hecho

`Fact_Inscripciones`

| Campo | Tipo | Uso |
|---|---|---|
| `inscripcion_id` | Int64 | Identificador de la inscripción |
| `periodo` | Texto | Código del periodo ("2025-01"). Oculto; se conserva para trazabilidad |
| `fecha_periodo` | Fecha | Primer día del semestre (`fecha_inicio` de `Cat_Periodos`). Relación con `Dim_Calendario`. Oculto |
| `oferta_key` | Texto | Relación con `Dim_Oferta` |
| `programa_key` | Texto | Relación con `Dim_Programa` |
| `persona_key` | Texto | Relación con `Dim_Persona` |
| `ubicacion_key` | Texto | Relación con `Dim_Ubicacion` |
| `edad` | Int64 | Edad al momento de la inscripción |
| `promedio_semestre` | Decimal | Promedio del semestre |
| `promedio_acumulado` | Decimal | Promedio acumulado |
| `peso_kg` | Decimal | Peso en kilogramos |
| `estatura_m` | Decimal | Estatura en metros |
| Banderas | Booleano | Calidad y trazabilidad |
| `archivo`, `hoja`, `fila_origen`, `layout`, `notas` | Texto | Trazabilidad |
| `logros`, `seguimiento` | Texto | Detalle descriptivo |

### Dimensiones

| Tabla | Llave | Atributos |
|---|---|---|
| `Dim_Calendario` | `fecha` | `anio`, `mes_num` (oculta), `mes`, `anio_mes`, `trimestre`, `periodo`, `periodo_nombre`, `periodo_orden` (oculta), `semestre`, `semestre_nombre`, `inicio_periodo`, `fin_periodo`, `es_inicio_periodo` (oculta) |
| `Dim_Oferta` | `oferta_key` | `disciplina`, `disciplina_orden`, `modalidad`, `modalidad_orden`, `proceso`, `grupo_artistico`, `grupo_orden`, `publico`, `grupo` |
| `Dim_Programa` | `programa_key` | `programa`, `facultad`, `nivel` |
| `Dim_Ubicacion` | `ubicacion_key` | `municipio`, `departamento` |
| `Dim_Persona` | `persona_key` | `documento`, `nombre`, `sexo`, `fecha_nacimiento`, `grupo_etnico`, `victima`, `eps`, `beneficio`, `discapacidad`, `comunidad`, `dependencia`, `codigo` |

### `Dim_Oferta` (v1.8)

Código: `02-PowerBI/Dim_Oferta.pq`. Tiene 22 filas: el grupo artístico ya está normalizado con la hoja `grupos_artisticos`.

| Columna | Contenido | Orden |
|---|---|---|
| `disciplina` | Disciplina | Se ordena por `disciplina_orden` |
| `disciplina_orden` | Mínimo `orden` de la disciplina en la hoja `grupos` de `catalogos.xlsx` | — |
| `modalidad` | Formación (Formación, Semillero), Representativo (Planta, Representativo) o Extensión | Se ordena por `modalidad_orden` |
| `modalidad_orden` | 1 Formación, 2 Representativo, 3 Extensión | — |
| `grupo_artistico` | Grupo artístico normalizado | Se ordena por `grupo_orden` |
| `grupo_orden` | Mínimo `orden` del grupo en la hoja `grupos` | — |

Los valores que no están en el catálogo reciben 999 en `grupo_orden` o `disciplina_orden` y quedan al final del eje. Eso indica que falta una fila en el catálogo. En v1.8 no hay ninguno.

### Columnas ocultas

| Tabla | Columnas ocultas |
|---|---|
| `Dim_Calendario` | `mes_num`, `periodo_orden`, `es_inicio_periodo` |
| `Dim_Oferta` | `oferta_key`, `grupo`, `disciplina_orden`, `modalidad_orden`, `grupo_orden` |
| `Dim_Persona` | `persona_key`, `documento`, `nombre`, `codigo`, `fecha_nacimiento`, `eps` |
| `Dim_Programa` | `programa_key` |
| `Dim_Ubicacion` | `ubicacion_key` |
| `Fact_Inscripciones` | `periodo`, `fecha_periodo`, `persona_key`, `oferta_key`, `programa_key`, `ubicacion_key`, `peso_kg`, `estatura_m` |

Las llaves se ocultan porque no tienen uso en el informe. Los datos personales y sensibles (documento, nombre, código, fecha de nacimiento, EPS, peso y estatura) se ocultan por privacidad.

`codigo` es el código del estudiante y queda en `Dim_Persona`.

`Dim_Calendario` reemplaza a `Dim_Periodo`, que se eliminó del modelo. Es un calendario diario de años completos generado desde la expresión M `Cat_Periodos` (hoja `periodos` de `catalogos.xlsx`, no se carga como tabla). Está marcada como tabla de fechas con `fecha` como columna clave. `mes` se ordena por `mes_num` y `periodo_nombre` por `periodo_orden`. Código: `02-PowerBI/Cat_Periodos.pq` y `02-PowerBI/Dim_Calendario.pq`.

La fecha y hora automáticas están desactivadas: no hay tablas `LocalDateTable_*` ni `DateTableTemplate_*`.

## Relaciones

Todas son de muchos a uno, con filtro en una sola dirección:

```text
Fact_Inscripciones[fecha_periodo] → Dim_Calendario[fecha]
Fact_Inscripciones[oferta_key]    → Dim_Oferta[oferta_key]
Fact_Inscripciones[programa_key]  → Dim_Programa[programa_key]
Fact_Inscripciones[ubicacion_key] → Dim_Ubicacion[ubicacion_key]
Fact_Inscripciones[persona_key]   → Dim_Persona[persona_key]
```

## Medidas

| Medida | Fórmula | Formato |
|---|---|---|
| `Total Inscripciones` | `COUNTROWS('Fact_Inscripciones')` | `#,0` |
| `Personas Distintas` | `DISTINCTCOUNT('Fact_Inscripciones'[persona_key])` | `#,0` |
| `Edad Promedio` | `AVERAGE('Fact_Inscripciones'[edad])` | `0.0` |
| `Promedio Semestre` | `AVERAGE('Fact_Inscripciones'[promedio_semestre])` | `0.00` |
| `Promedio Acumulado` | `AVERAGE('Fact_Inscripciones'[promedio_acumulado])` | `0.00` |
| `% Victimas` | Personas víctimas / personas con dato (Sí o No); ver abajo | `0.0 %` |
| `% Documento Faltante` | Inscripciones con documento faltante / total | `0.0 %` |
| `% Bloque Desplazado` | Inscripciones con bloque desplazado / total | `0.0 %` |

Las medidas anteriores están en la carpeta "Indicadores".

**`% Victimas` (v1.8).** Antes contaba inscripciones e incluía a los no estudiantes, cuyo formato no pregunta esta condición, y daba 39 %. Ahora cuenta personas y solo sobre las que tienen dato:

```dax
% Victimas =
DIVIDE (
    CALCULATE ( [Personas Distintas], Dim_Persona[victima] = "Sí" ),
    CALCULATE ( [Personas Distintas], Dim_Persona[victima] IN { "Sí", "No" } )
)
```

Resultado: total 163 / 368 = 44,3 %; 2025-1: 119 / 266 = 44,7 %; 2025-2: 67 / 170 = 39,4 %. El valor de `victima` sale de `Dim_Persona`, que guarda los atributos del periodo más reciente de cada persona.

### Carpeta "Tiempo"

Código completo en `02-PowerBI/Medidas_Tiempo.dax`.

| Medida | Formato | Qué calcula |
|---|---|---|
| `Personas Semestre Anterior` | `#,0` | `[Personas Distintas]` con `DATEADD(-6, MONTH)`; solo con un periodo único |
| `Inscripciones Semestre Anterior` | `#,0` | `[Total Inscripciones]` con `DATEADD(-6, MONTH)`; solo con un periodo único |
| `Var Personas vs Semestre Anterior` | `#,0` | Personas actuales − personas del semestre anterior |
| `% Var Personas vs Semestre Anterior` | `0.0 %` | Variación / personas del semestre anterior |
| `Personas Mismo Semestre Año Anterior` | `#,0` | `[Personas Distintas]` con `SAMEPERIODLASTYEAR` |
| `% Var Personas Interanual` | `0.0 %` | Variación frente al mismo semestre del año anterior |
| `Personas Año Anterior` | `#,0` | `[Personas Distintas]` con `PARALLELPERIOD(-1, YEAR)` |
| `Personas Acumuladas Año` | `#,0` | `[Personas Distintas]` con `DATESYTD` |
| `Inscripciones Acumuladas Año` | `#,0` | `TOTALYTD([Total Inscripciones])` |
| `Personas que Continúan` | `#,0` | Personas inscritas en el semestre actual y en el anterior |
| `% Continuidad` | `0.0 %` | Personas que continúan / personas del semestre anterior |
| `Personas Nuevas` | `#,0` | Personas actuales − personas que continúan |
| `Personas que No Continúan` | `#,0` | Personas del semestre anterior − personas que continúan |

## Inteligencia de tiempo

Los datos fuente no traen fechas. El tiempo se modela con las fechas de inicio y fin de cada semestre definidas en la hoja `periodos` de `catalogos.xlsx`:

- **Ancla al inicio del semestre.** Cada inscripción recibe en `fecha_periodo` el primer día de su semestre (`fecha_inicio` del catálogo). Todas las inscripciones de 2025-01 caen el 2025-01-01 y todas las de 2025-02 el 2025-07-01. Así, cualquier filtro de `Dim_Calendario` (año, semestre, periodo, mes de inicio) incluye o excluye semestres completos.
- **Semestre anterior = `DATEADD(-6, MONTH)`.** Al desplazar 6 meses las fechas de un semestre se obtienen exactamente las fechas del semestre anterior: ene–jun pasa a jul–dic del año previo y jul–dic pasa a ene–jun del mismo año. Como `Dim_Calendario` está marcada como tabla de fechas, `DATEADD` quita el filtro de `periodo` y aplica el rango desplazado.
- **Solo con un periodo único.** `Personas Semestre Anterior`, `Inscripciones Semestre Anterior` y `Personas que Continúan` devuelven vacío si no hay un único `Dim_Calendario[periodo]` en contexto (por ejemplo, el total de un año). Es intencional: "semestre anterior" de un año completo no tiene sentido.
- **Regla de mantenimiento.** Las fechas del catálogo deben mantenerse como semestres de 6 meses exactos: **ene–jun** (`AAAA-01`, del 1 de enero al 30 de junio) y **jul–dic** (`AAAA-02`, del 1 de julio al 31 de diciembre). Si un periodo tuviera otras fechas, `DATEADD(-6, MONTH)` dejaría de coincidir con el semestre anterior.
- **Extensión automática.** El calendario va del 1 de enero del primer año al 31 de diciembre del último año del catálogo. Al agregar un periodo nuevo (por ejemplo 2026-01) con sus fechas en `catalogos.xlsx` y refrescar, el calendario y las medidas se extienden sin cambiar código.

## Validación del modelo

| Control | Resultado |
|---|---:|
| Filas de `Fact_Inscripciones` | 529 |
| Personas distintas en el hecho | 399 |
| Personas 2025-1 / 2025-2 | 291 / 200 |
| Periodos | 2 |
| Días en `Dim_Calendario` | 365 (2025-1: 181; 2025-2: 184) |
| Hechos sin `fecha_periodo` | 0 |
| Ofertas (`Dim_Oferta`) | 22 (antes 27) |
| Grupos artísticos distintos | 13 |
| Programas (`Dim_Programa`) | 24: 23 programas y 1 vacío de no estudiantes (antes 43) |
| Ubicaciones (`Dim_Ubicacion`) | 47 (antes 84) |
| Personas (`Dim_Persona`) | 399 |
| Inscripciones 2025-01 | 308 |
| Inscripciones 2025-02 | 221 |
| Inscripciones de estudiantes sin facultad | 0 (antes 217) |
| Inscripciones sin departamento | 0 (antes 325) |
| Departamentos distintos | 17 |
| `Dim_Oferta[modalidad]` | Formación 12 ofertas (347 inscripciones), Representativo 9 (178), Extensión 1 (4) |
| `grupo_orden` o `disciplina_orden` = 999 | 0 |
| Hechos sin dimensión (cualquier relación) | 0 |
| Medidas de tiempo, 2025-2 | Personas 200, semestre anterior 291, continúan 92, nuevas 108 |
| `% Victimas` | 44,3 % (163 / 368) |

La suma por periodo y por disciplina coincide con las 529 filas del hecho.

## Staging no cargado

Las consultas `01_Archivos` a `08_Fact_Limpia` **no se cargan al modelo** desde v1.8. Existen en Power Query como expresiones M compartidas (equivalentes a desmarcar "Habilitar carga"), con el mismo nombre y código. Las dimensiones y `Fact_Inscripciones` dependen de ellas:

```text
01_Archivos (no la usa otra consulta)
02_Hojas, 03_Mapeo → 05_Staging_04_06, 06_Staging_04_05 → 07_Fact_Staging → 08_Fact_Limpia
04_Hojas_Mapeadas (no la usa otra consulta)
08_Fact_Limpia → Dim_Oferta, Dim_Programa, Dim_Ubicacion, Dim_Persona, Fact_Inscripciones
```

Así, el modelo no guarda una copia de los nombres, documentos, correos y teléfonos de `08_Fact_Limpia`, y el `.pbix` pesa menos. Para auditar el staging, ábrelo en el Editor de Power Query.
