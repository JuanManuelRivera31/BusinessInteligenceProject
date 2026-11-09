# Tarea: crear la Dimensión Calendario e inteligencia de tiempo en `proyecto.pbix`

Trabaja en español. Lee esta instrucción completa antes de empezar.

## Contexto

Proyecto de Inteligencia de Negocios sobre las inscripciones a los grupos de Arte y Cultura (Universidad de la Amazonia).

- Raíz del proyecto: `C:\Users\juanm\Downloads\Proyecto\Proyecto`
- Modelo: `02-PowerBI\proyecto.pbix` (Power BI Desktop)
- Catálogos: `01-Datos\02-Externos\catalogos.xlsx`. La hoja `periodos` tiene las columnas `periodo` (texto "2025-01"), `anio`, `semestre`, `nombre` ("2025-1"), `orden`, `fecha_inicio` y `fecha_fin`.
- Documentación: `03-Documentacion\00_estructura_proyecto.md` y `03-Documentacion\03_modelo_estrella.md`

Estado actual del modelo:
- Hecho: `Fact_Inscripciones` (529 filas). Tiene la columna de texto `periodo` ("2025-01"/"2025-02") y no tiene ninguna fecha.
- Dimensiones: `Dim_Periodo`, `Dim_Oferta`, `Dim_Programa`, `Dim_Ubicacion` y `Dim_Persona`.
- Medidas existentes en `Fact_Inscripciones`, carpeta "Indicadores": `[Total Inscripciones]` y `[Personas Distintas]`, entre otras.
- Expresiones M (parámetros): `RutaDatos`, `RutaExternos`, `RutaMapeo` y `RutaCatalogos`.
- Las consultas `01_Archivos` a `08_Fact_Limpia` son la capa de staging y están ocultas.

Objetivo: los datos no traen fechas, así que el tiempo se modela con las fechas de inicio y fin de cada semestre del catálogo.
- Se crea un calendario diario de años completos.
- Cada inscripción se ancla al primer día de su semestre.
- "Semestre anterior" se calcula como `DATEADD(-6, MONTH)`. Esto funciona porque el catálogo define semestres de 6 meses exactos (ene–jun y jul–dic).
- Al agregar 2026 al catálogo, todo debe extenderse sin cambiar código.

## Reglas

1. **Haz una copia de seguridad antes de cualquier cambio:** copia `proyecto.pbix` como `02-PowerBI\proyecto_backup_AAAAMMDD_HHMM.pbix`, con la fecha y hora actuales.
2. Usa el servidor MCP de modelado de Power BI conectado a la instancia abierta de Power BI Desktop. Si Power BI Desktop no está abierto con `proyecto.pbix`, o no hay conexión MCP, detente y pídeme que lo abra.
3. Haz solo lo que pide esta instrucción. No corrijas otras consultas, catálogos ni medidas, aunque veas problemas. Anótalos en el informe final.
4. No muestres en tus respuestas nombres, documentos, correos ni teléfonos de personas, ni siquiera en los resultados de las consultas DAX. Solo conteos.
5. Si algo falla o una validación no coincide, no improvises arreglos fuera del alcance: detente, explica qué pasó y propón la corrección.
6. Al final, recuérdame guardar el archivo en Power BI Desktop (Ctrl+S). Los cambios hechos por MCP no se guardan solos en el `.pbix`.

## Paso 0. Verificaciones previas

1. Lee el valor del parámetro `RutaDatos`. Debe ser `C:\Users\juanm\Downloads\Proyecto\Proyecto\01-Datos\01-Crudos`. Si apunta a otra ruta (por ejemplo `...\Proyecto (2)\...`), cámbialo a esa ruta y verifica que la carpeta exista.
2. Confirma que existe `01-Datos\02-Externos\catalogos.xlsx` con la hoja `periodos` y las columnas indicadas.
3. Lista las tablas del modelo con su conteo de filas y anótalas como línea base.

## Paso 1. Expresión `Cat_Periodos` (no se carga como tabla)

Créala como **expresión M compartida** (igual que `RutaCatalogos`), no como tabla del modelo:

```m
let
    Origen = Excel.Workbook(File.Contents(RutaCatalogos), null, true),
    Hoja = Origen{[Item = "periodos", Kind = "Sheet"]}[Data],
    Encabezados = Table.PromoteHeaders(Hoja, [PromoteAllScalars = true]),
    SinVacias = Table.SelectRows(
        Encabezados,
        each [periodo] <> null and Text.Trim(Text.From([periodo])) <> ""
    ),
    PeriodoTexto = Table.TransformColumns(
        SinVacias,
        {{"periodo", each Text.Trim(Text.From(_)), type text}}
    ),
    Tipos = Table.TransformColumnTypes(
        PeriodoTexto,
        {
            {"anio", Int64.Type},
            {"semestre", Int64.Type},
            {"nombre", type text},
            {"orden", Int64.Type},
            {"fecha_inicio", type date},
            {"fecha_fin", type date}
        }
    ),
    Ordenado = Table.Sort(Tipos, {{"orden", Order.Ascending}})
in
    Ordenado
```

Descripción: "Catálogo de periodos académicos con fechas de inicio y fin. Fuente única de fechas del modelo."

## Paso 2. Tabla `Dim_Calendario`

Crea la tabla con una partición M:

```m
let
    Periodos = Table.Buffer(Cat_Periodos),

    AnioInicio  = List.Min(List.Transform(Periodos[fecha_inicio], each Date.Year(_))),
    AnioFin     = List.Max(List.Transform(Periodos[fecha_fin], each Date.Year(_))),
    FechaInicio = #date(AnioInicio, 1, 1),
    FechaFin    = #date(AnioFin, 12, 31),
    NumDias     = Duration.Days(FechaFin - FechaInicio) + 1,

    ListaFechas = List.Dates(FechaInicio, NumDias, #duration(1, 0, 0, 0)),
    Base = Table.FromList(ListaFechas, Splitter.SplitByNothing(), type table [fecha = date]),

    ConAnio      = Table.AddColumn(Base, "anio", each Date.Year([fecha]), Int64.Type),
    ConMesNum    = Table.AddColumn(ConAnio, "mes_num", each Date.Month([fecha]), Int64.Type),
    ConMes       = Table.AddColumn(ConMesNum, "mes", each Text.Proper(Date.MonthName([fecha], "es-CO")), type text),
    ConAnioMes   = Table.AddColumn(
        ConMes, "anio_mes",
        each Text.From([anio]) & "-" & Text.PadStart(Text.From([mes_num]), 2, "0"), type text),
    ConTrimestre = Table.AddColumn(ConAnioMes, "trimestre", each "T" & Text.From(Date.QuarterOfYear([fecha])), type text),

    fnPeriodo = (f as date) as nullable record =>
        let
            Coincide = Table.SelectRows(Periodos, each [fecha_inicio] <= f and [fecha_fin] >= f)
        in
            if Table.IsEmpty(Coincide) then null else Coincide{0},

    ConRegistro = Table.AddColumn(ConTrimestre, "_p", each fnPeriodo([fecha])),

    ConPeriodo = Table.AddColumn(ConRegistro, "periodo",
        each if [_p] = null then "Sin periodo" else [_p][periodo], type text),
    ConPeriodoNombre = Table.AddColumn(ConPeriodo, "periodo_nombre",
        each if [_p] = null then "Sin periodo" else [_p][nombre], type text),
    ConPeriodoOrden = Table.AddColumn(ConPeriodoNombre, "periodo_orden",
        each if [_p] = null then null else [_p][orden], Int64.Type),
    ConSemestre = Table.AddColumn(ConPeriodoOrden, "semestre",
        each if [_p] = null then null else [_p][semestre], Int64.Type),
    ConSemestreNombre = Table.AddColumn(ConSemestre, "semestre_nombre",
        each if [semestre] = null then "Sin periodo" else "Semestre " & Text.From([semestre]), type text),
    ConInicio = Table.AddColumn(ConSemestreNombre, "inicio_periodo",
        each if [_p] = null then null else [_p][fecha_inicio], type date),
    ConFin = Table.AddColumn(ConInicio, "fin_periodo",
        each if [_p] = null then null else [_p][fecha_fin], type date),
    ConEsInicio = Table.AddColumn(ConFin, "es_inicio_periodo",
        each [inicio_periodo] <> null and [fecha] = [inicio_periodo], type logical),

    Resultado = Table.RemoveColumns(ConEsInicio, {"_p"})
in
    Resultado
```

Luego configura la tabla:
- **Márcala como tabla de fechas** con la columna `fecha`: categoría de datos "Time" en la tabla y `fecha` como columna clave. Es obligatorio; sin esto, `DATEADD` no quita el filtro de periodo.
- **Ordenar por columna:** `mes` → `mes_num`; `periodo_nombre` → `periodo_orden`.
- **Formato:** `fecha`, `inicio_periodo` y `fin_periodo` en formato de fecha corta.
- **Columnas ocultas:** `mes_num`, `periodo_orden` y `es_inicio_periodo`.
- **Descripción de la tabla:** "Calendario diario de años completos generado desde Cat_Periodos. Cada día pertenece al semestre académico que lo contiene."

## Paso 3. Agregar `fecha_periodo` a `Fact_Inscripciones`

En la partición M de `Fact_Inscripciones`, la consulta termina en el paso `Tipos` (`in Tipos`). Agrega estos pasos al final y cambia la salida a `TiposFinal`:

```m
    ConFechaPeriodo = Table.NestedJoin(
        Tipos, {"periodo"},
        Cat_Periodos, {"periodo"},
        "cat_periodo", JoinKind.LeftOuter
    ),
    FechaExpandida = Table.ExpandTableColumn(
        ConFechaPeriodo, "cat_periodo",
        {"fecha_inicio"}, {"fecha_periodo"}
    ),
    TiposFinal = Table.TransformColumnTypes(FechaExpandida, {{"fecha_periodo", type date}})
in
    TiposFinal
```

No modifiques ningún otro paso de la consulta.

## Paso 4. Relaciones y limpieza del modelo

1. Crea la relación `Dim_Calendario[fecha]` (1) → `Fact_Inscripciones[fecha_periodo]` (*), activa, con filtro en una sola dirección.
2. Elimina la relación `Fact_Inscripciones[periodo]` → `Dim_Periodo[periodo]`.
3. Verifica que ninguna medida, columna calculada ni visual use `Dim_Periodo`. Si nada la usa, elimina la tabla `Dim_Periodo`: el calendario la reemplaza. Si algo la usa, no la elimines; ocúltala e infórmalo.
4. Oculta `Fact_Inscripciones[fecha_periodo]` y `Fact_Inscripciones[periodo]`.
5. Desactiva la fecha y hora automáticas:
   - Elimina las tablas `LocalDateTable_*` y `DateTableTemplate_*`.
   - Pon la anotación del modelo `__PBI_TimeIntelligenceEnabled` en `0`.
   - Si el MCP no lo permite, dímelo para hacerlo a mano en Archivo → Opciones → Archivo actual → Carga de datos → "Fecha y hora automáticas".

## Paso 5. Refrescar

Refresca `Dim_Calendario` y `Fact_Inscripciones`, o el modelo completo. Si hay errores, detente e infórmalos con el mensaje exacto.

## Paso 6. Medidas de tiempo

Créalas en la tabla `Fact_Inscripciones`, carpeta **"Tiempo"**, con el formato indicado:

| Medida | Formato |
|---|---|
| Personas Semestre Anterior, Inscripciones Semestre Anterior, Var Personas vs Semestre Anterior, Personas Mismo Semestre Año Anterior, Personas Año Anterior, Personas Acumuladas Año, Inscripciones Acumuladas Año, Personas que Continúan, Personas Nuevas, Personas que No Continúan | `#,0` |
| % Var Personas vs Semestre Anterior, % Var Personas Interanual, % Continuidad | `0.0 %` |

```dax
Personas Semestre Anterior =
IF (
    HASONEVALUE ( Dim_Calendario[periodo] ),
    CALCULATE ( [Personas Distintas], DATEADD ( Dim_Calendario[fecha], -6, MONTH ) )
)

Inscripciones Semestre Anterior =
IF (
    HASONEVALUE ( Dim_Calendario[periodo] ),
    CALCULATE ( [Total Inscripciones], DATEADD ( Dim_Calendario[fecha], -6, MONTH ) )
)

Var Personas vs Semestre Anterior =
VAR Actual = [Personas Distintas]
VAR Anterior = [Personas Semestre Anterior]
RETURN
    IF ( NOT ISBLANK ( Actual ) && NOT ISBLANK ( Anterior ), Actual - Anterior )

% Var Personas vs Semestre Anterior =
DIVIDE ( [Var Personas vs Semestre Anterior], [Personas Semestre Anterior] )

Personas Mismo Semestre Año Anterior =
CALCULATE ( [Personas Distintas], SAMEPERIODLASTYEAR ( Dim_Calendario[fecha] ) )

% Var Personas Interanual =
VAR Actual = [Personas Distintas]
VAR Anterior = [Personas Mismo Semestre Año Anterior]
RETURN
    IF ( NOT ISBLANK ( Actual ) && NOT ISBLANK ( Anterior ), DIVIDE ( Actual - Anterior, Anterior ) )

Personas Año Anterior =
CALCULATE ( [Personas Distintas], PARALLELPERIOD ( Dim_Calendario[fecha], -1, YEAR ) )

Personas Acumuladas Año =
CALCULATE ( [Personas Distintas], DATESYTD ( Dim_Calendario[fecha] ) )

Inscripciones Acumuladas Año =
TOTALYTD ( [Total Inscripciones], Dim_Calendario[fecha] )

Personas que Continúan =
VAR PersonasActuales =
    VALUES ( Fact_Inscripciones[persona_key] )
VAR PersonasAnteriores =
    CALCULATETABLE (
        VALUES ( Fact_Inscripciones[persona_key] ),
        DATEADD ( Dim_Calendario[fecha], -6, MONTH )
    )
RETURN
    IF (
        HASONEVALUE ( Dim_Calendario[periodo] )
            && NOT ISBLANK ( [Personas Distintas] )
            && NOT ISBLANK ( [Personas Semestre Anterior] ),
        COUNTROWS ( INTERSECT ( PersonasActuales, PersonasAnteriores ) ) + 0
    )

% Continuidad =
DIVIDE ( [Personas que Continúan], [Personas Semestre Anterior] )

Personas Nuevas =
IF (
    NOT ISBLANK ( [Personas que Continúan] ),
    [Personas Distintas] - [Personas que Continúan]
)

Personas que No Continúan =
IF (
    NOT ISBLANK ( [Personas que Continúan] ),
    [Personas Semestre Anterior] - [Personas que Continúan]
)
```

Ponle a cada medida una descripción breve en español que diga qué calcula.

## Paso 7. Validación con consultas DAX

Ejecuta estas consultas y compara con los valores esperados.

**7.1 Calendario**

```dax
EVALUATE
SUMMARIZECOLUMNS (
    Dim_Calendario[periodo_nombre],
    "Dias", COUNTROWS ( Dim_Calendario ),
    "Desde", MIN ( Dim_Calendario[fecha] ),
    "Hasta", MAX ( Dim_Calendario[fecha] )
)
```

Esperado: 365 días en total. 2025-1 tiene 181 días (del 2025-01-01 al 2025-06-30) y 2025-2 tiene 184 días (del 2025-07-01 al 2025-12-31). No debe aparecer "Sin periodo".

**7.2 Integridad del hecho**

```dax
EVALUATE
ROW (
    "Filas hecho", COUNTROWS ( Fact_Inscripciones ),
    "Sin fecha_periodo", COUNTROWS ( FILTER ( Fact_Inscripciones, ISBLANK ( Fact_Inscripciones[fecha_periodo] ) ) )
)
```

Esperado: 529 filas en el hecho y 0 sin `fecha_periodo`.

**7.3 Medidas por periodo**

```dax
EVALUATE
SUMMARIZECOLUMNS (
    Dim_Calendario[periodo_nombre],
    "Personas", [Personas Distintas],
    "Pers Sem Ant", [Personas Semestre Anterior],
    "Var", [Var Personas vs Semestre Anterior],
    "Pct Var", [% Var Personas vs Semestre Anterior],
    "Continuan", [Personas que Continúan],
    "Pct Continuidad", [% Continuidad],
    "Nuevas", [Personas Nuevas],
    "No Continuan", [Personas que No Continúan],
    "Pers Acum Año", [Personas Acumuladas Año],
    "Insc Acum Año", [Inscripciones Acumuladas Año],
    "Mismo Sem Año Ant", [Personas Mismo Semestre Año Anterior]
)
```

Esperado:

| Medida | 2025-1 | 2025-2 |
|---|---:|---:|
| Personas | 291 | 200 |
| Pers Sem Ant | vacío | 291 |
| Var | vacío | −91 |
| Pct Var | vacío | −0,313 |
| Continuan | vacío | 92 |
| Pct Continuidad | vacío | 0,316 |
| Nuevas | vacío | 108 |
| No Continuan | vacío | 199 |
| Pers Acum Año | 291 | 399 |
| Insc Acum Año | 308 | 529 |
| Mismo Sem Año Ant | vacío | vacío |

Si los valores base (Personas o Insc Acum Año) no coinciden, puede ser que el modelo cambió desde que se calcularon estos valores. En ese caso **no "corrijas" nada**: informa los valores obtenidos y verifica que la lógica sea coherente. Por ejemplo, para 2025-2 debe cumplirse Continúan + Nuevas = Personas, y Continúan + No Continúan = Pers Sem Ant.

**7.4 Filtro de periodo**

Ejecuta `[Personas Semestre Anterior]` filtrando por `Dim_Calendario[anio] = 2025`, sin un periodo único. Debe devolver vacío: el comportamiento es intencional.

## Paso 8. Guardar código y documentación

1. **Guarda el código** en `02-PowerBI`, siguiendo la convención de `08_Fact_Limpia.pq`:
   - `Cat_Periodos.pq`
   - `Dim_Calendario.pq`
   - `Medidas_Tiempo.dax`, con todas las medidas del paso 6.
2. **Actualiza `03-Documentacion\03_modelo_estrella.md`:**
   - Agrega `Dim_Calendario` con sus columnas y llave en la tabla de dimensiones.
   - Quita `Dim_Periodo`, o márcala como oculta si no se eliminó.
   - Agrega `fecha_periodo` al hecho.
   - Cambia la relación de periodo por `Fact_Inscripciones[fecha_periodo] → Dim_Calendario[fecha]`.
   - Agrega las medidas de la carpeta "Tiempo".
   - Agrega una sección "Inteligencia de tiempo" que explique el ancla al inicio del semestre, por qué se usa `DATEADD -6 MONTH`, y que las fechas del catálogo deben mantenerse como semestres de 6 meses (ene–jun y jul–dic).
3. **Actualiza `03-Documentacion\00_estructura_proyecto.md`:**
   - Sube la versión a 1.7 y la fecha a hoy.
   - Actualiza el campo "Estado".
   - Agrega una fila a la bitácora: "Creación de Dim_Calendario desde Cat_Periodos, fecha_periodo en el hecho, relación por fecha, eliminación de Dim_Periodo y de fechas automáticas, 13 medidas de tiempo", con los archivos afectados y como responsable "Juan Manuel".
   - En la sección 8.1 (Nuevo semestre), aclara que basta con agregar el periodo en la hoja `periodos` de `catalogos.xlsx`, con sus fechas, para que el calendario se extienda.

## Informe final

Entrégame un resumen con:
1. Qué se creó, modificó y eliminó (tablas, expresiones, relaciones, medidas, archivos).
2. Los resultados de las validaciones 7.1 a 7.4, comparados con lo esperado.
3. Cualquier paso que no pudiste hacer por MCP y que debo hacer a mano.
4. Problemas que viste fuera del alcance, sin corregirlos.
5. El recordatorio de guardar el `.pbix` con Ctrl+S.
