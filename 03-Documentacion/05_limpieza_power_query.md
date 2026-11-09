# Limpieza de datos en Power Query

## Archivo

La consulta está en:

```text
02-PowerBI/08_Fact_Limpia.pq
```

No es un archivo que Power BI abra automáticamente. Es un script M para pegar en el **Editor avanzado** de Power Query.

> Estado actual (v1.8): `08_Fact_Limpia` es una **consulta de staging no cargada**: existe en Power Query como expresión M compartida, pero no se carga al modelo, porque contiene nombres, documentos, correos y teléfonos. Lo mismo ocurre con `01_Archivos` a `07_Fact_Staging`. Las dimensiones y `Fact_Inscripciones` leen de ella. Este archivo queda como fuente reproducible. Los demás archivos de código están en `02-PowerBI/` (`01_02_Filtro_Excel.pq`, `Dim_Oferta.pq`, `Dim_Persona.pq`, `Cat_Periodos.pq` y `Dim_Calendario.pq`).

## Requisitos

Antes de pegarla, deben existir en el `.pbix`:

- El parámetro `RutaDatos`.
- Las expresiones `RutaExternos`, `RutaMapeo` y `RutaCatalogos`.
- La consulta `07_Fact_Staging` con 540 filas.
- Los catálogos en:

```text
01-Datos/02-Externos/catalogos.xlsx
```

Las rutas se centralizan así:

```m
RutaExternos = Text.Replace(RutaDatos, "01-Crudos", "02-Externos")
RutaMapeo = RutaExternos & "\mapeo_fuentes.xlsx"
RutaCatalogos = RutaExternos & "\catalogos.xlsx"
```

`03_Mapeo` usa `RutaMapeo`; `08_Fact_Limpia` usa `RutaCatalogos`.

`01_Archivos` y `02_Hojas` filtran los archivos con el paso `SoloExcel` (ver `02-PowerBI/01_02_Filtro_Excel.pq`). Solo leen archivos `.xlsx` e ignoran los temporales `~$` que Excel crea al abrir un libro. Así la actualización no falla si alguien tiene un crudo abierto.

## Cómo pegarla

1. Abre `proyecto.pbix`.
2. Ve a `Transformar datos`.
3. En Power Query Editor:

```text
Inicio → Nuevo origen → Consulta en blanco
```

4. Abre el Editor avanzado:

```text
Inicio → Editor avanzado
```

5. Borra todo el contenido.
6. Copia el contenido completo de `08_Fact_Limpia.pq`.
7. Pégalo.
8. Clic en `Listo`.
9. Renombra la consulta como:

```text
08_Fact_Limpia
```

10. Revisa que no haya errores en los pasos.

## Qué hace la consulta

### 1. Quita columnas de staging

Elimina:

```text
datos
tipo
oculta
incluir
```

### 2. Corrige columnas desplazadas

Si `EPS` contiene un correo (`@`), asume que el bloque está corrido y corrige:

```text
ProgramaSocial → EPS
EPS            → Correo
Correo         → Celular
```

Agrega la bandera:

```text
bloque_desplazado
```

### 3. Separa beneficio y discapacidad

- Crea `Beneficio` a partir de `ProgramaSocial` y `Discapacidad`.
- Limpia `Discapacidad` para que solo tenga `Sí`, `No` o `Sin dato`.
- Agrega `beneficio_en_discapacidad`.

### 4. Limpia nombres y documentos

- Corrige espacios dobles.
- Corrige `S Tefany` → `Stefany`.
- Une nombres partidos con el documento cuando el documento contiene letras.
- Convierte documentos a texto sin espacios, puntos ni guiones.
- Marca `documento_faltante` y `nombre_partido`.

El caso `John Faber` / `Gutiérrez Restrepo` queda:

```text
nombre = John Faber Gutiérrez Restrepo
documento = null
nombre_partido = true
documento_faltante = true
```

### 5. Convierte fechas, edades y promedios

- Fechas de texto `dd/MM/yyyy`.
- Seriales de Excel.
- Fechas inválidas a nulo.
- Edad numérica.
- Promedios 39/40/42 a 3.9/4.0/4.2.
- Textos como `N/A`, `No aplica`, `segundo` a nulo.
- Peso y estatura a kg/m.
- Los números con coma decimal se convierten a punto y se interpretan con cultura `en-US` para evitar que `37,8` se lea como `378`.
- Banderas `fecha_invalida`, `edad_invalida`, `promedio_escala_corregida`, `peso_estatura_corregido`.

### 6. Normaliza categorías

- Sexo: Hombre, Mujer, Sin dato.
- Víctima: Sí, No, Sin dato.
- Grupo étnico: No aplica, Indígena, Afrocolombiano, Palenquero, Otro.
- Comunidad: Estudiante, Docente, Egresado/Graduado, Administrativo, Pensionado, Extensión Social.

**Corrección de tildes (v1.8).** `fnEtnia`, `fnComunidad`, `fnBeneficio` y `fnDiscapacidad` comparan con `fnU`, que convierte a mayúsculas y quita las tildes. Antes, "Pueblo Indígena" caía en "Otro", "Extensión Social" en "No aplica", y "Generación E", "Jóvenes en acción" y "Renta jóven" en "Otro". `fnBeneficio` también reconoce "NINGUNA" y los valores formados solo por negaciones (por ejemplo "NA No"), que se clasifican como "Ninguno / No aplica".

### 7. Cruza con catálogos

- `programas` → programa normalizado, facultad y nivel.
- `eps` → EPS normalizada.
- `municipios` → municipio normalizado y departamento.
- `dependencias` → dependencia normalizada.
- `grupos_artisticos` → grupo artístico normalizado (nuevo en v1.8).

Si un valor no está en el catálogo, conserva el valor original.

**Llave normalizada (v1.8).** `MergeCatalogo` ya no exige texto idéntico. Calcula una llave con `fnClave` en ambos lados: sin tildes, en mayúsculas, solo letras y dígitos, con los signos convertidos en espacio y los espacios dobles reducidos a uno. Por ejemplo, "Ingenieria  de Sistemas " y "Ingeniería de Sistemas" dan la misma llave. Antes de cruzar, quita las filas del catálogo con llave vacía y las llaves repetidas, para no duplicar filas del hecho. Con esto, las inscripciones de estudiantes sin facultad pasaron de 217 a 0 y las inscripciones sin departamento de 325 a 0.

**Catálogo `grupos_artisticos` (v1.8).** La hoja nueva de `catalogos.xlsx` (23 filas) une las 21 variantes escritas del grupo artístico en 13 grupos reales. El resultado va a la columna `GrupoArtisticoFinal`, que se usa en la deduplicación y sale como `grupo_artistico`. Si un valor no está en la hoja, se conserva recortado (`Text.Trim`). Por eso `Dim_Oferta` pasó de 27 a 22 filas.

### 8. Crea la llave de persona

```text
D|documento|nombre_normalizado
```

Si no hay documento:

```text
N|nombre_normalizado|fecha_nacimiento
```

Así se evitan colisiones de documento como:

- Laura Camila Peña vs Daniela Arango.
- Martin Zarrilla vs Steven Mendez.

### 9. Deduplica

Deduplica por:

```text
persona_key + periodo + disciplina + publico + grupo + grupo_artistico (normalizado)
+ proceso + programa + facultad + nivel
```

`codigo` es el código del estudiante y no forma parte de la llave.

Conserva la fila más completa según:

```text
documento, correo, celular, EPS, programa, promedio, fecha
```

No elimina a la misma persona en dos semestres, dos disciplinas o dos programas.

**`Table.Buffer` (v1.8).** `Table.Distinct` conserva la primera fila de cada grupo, pero Power Query no garantiza que respete un `Table.Sort` anterior si no se fija el orden. Por eso la tabla ordenada se pasa por `Table.Buffer` (`OrdenadoBuffer`) antes de deduplicar. `Dim_Persona` hace lo mismo: ordena por `periodo` descendente e `inscripcion_id` ascendente, aplica `Table.Buffer` y después `Table.Distinct`, para quedarse de forma determinística con la fila del periodo más reciente.

**Bandera sin nulos (v1.8).** `promedio_escala_corregida` se calcula como `(fnNumero([PromedioSemestre]) ?? 0) > 10`. Antes quedaba vacía en 182 filas cuando el promedio era nulo; ahora siempre es verdadero o falso.

### Limitación conocida: documentos con dos `persona_key`

La llave de persona incluye el nombre normalizado para evitar colisiones cuando dos personas distintas comparten el mismo documento. Como consecuencia, **10 documentos tienen dos `persona_key`** porque el nombre está escrito de forma distinta en las fuentes. Unos 6 parecen ser la misma persona con el nombre escrito de otra manera, y unos 4 son documentos repetidos de personas distintas. Se dejan así a propósito: unificar por documento juntaría a personas distintas. Si se corrigen, debe hacerse en la fuente o con un catálogo explícito de equivalencias.

## Validaciones después de pegarla

| Control | Valor esperado / resultado |
|---|---:|
| Filas iniciales | 540 |
| Filas después de deduplicar | 529 |
| `EPS` con `@` | 0 |
| `Sexo` distintos | Hombre, Mujer, Sin dato |
| `Victima` distintos | Sí, No, Sin dato |
| `bloque_desplazado = true` | 60 |
| `promedio_escala_corregida` | Verdadero 46 (47 antes de deduplicar), Falso 483, vacío 0 |
| `documento_faltante = true` | 1 (John Faber; los otros dos documentos no numéricos se normalizaron) |
| `fecha_invalida = true` | 4 |
| `nombre_partido = true` | 1 |
| `peso_estatura_corregido = true` | 87 (incluye estaturas en centímetros) |
| `sin_fecha_nacimiento` | 14 |
| `sin_sexo` | 10 |
| `sin_victima` | 55 |

La diferencia entre 47 y 46 en `promedio_escala_corregida` se debe a que una fila con promedio en escala 0–100 quedó eliminada al deduplicar por `persona_key + periodo + disciplina + grupo + proceso`.

### Validación v1.8 (2026-11-09)

| Control | Resultado |
|---|---|
| Filas de `08_Fact_Limpia` y de `Fact_Inscripciones` | 529 (2025-01: 308; 2025-02: 221) |
| Personas distintas | 399 (2025-1: 291; 2025-2: 200) |
| Filas de `Dim_Oferta` | 22 (antes 27) |
| `grupo_artistico` distintos | 13 |
| `Dim_Programa` | 24 filas (23 programas y 1 vacío de no estudiantes) |
| `Dim_Ubicacion` | 47 filas |
| Inscripciones de estudiantes sin facultad | 0 (antes 217) |
| Inscripciones sin departamento | 0 (antes 325) |
| Departamentos distintos | 17. Caquetá 443, Huila 46, Bogotá D.C. 11 |
| Facultad (inscripciones de estudiantes) | Ciencias de la Educación 175, Ingeniería 89, Ciencias Contables, Económicas y Administrativas 54, Ciencias de la Salud 52, Derecho y Ciencias Políticas 36, Ciencias Básicas 35, Ciencias Agropecuarias 32, Educación a Distancia 1, Por confirmar 1 |
| `grupo_etnico` | No aplica 509, Indígena 11, Afrocolombiano 8, Palenquero 1, Otro 0 |
| `comunidad` | Estudiante 475, Egresado/Graduado 21, Docente 14, Extensión Social 13, Administrativo 3, Pensionado 2, No aplica 1 |
| `beneficio` | Ninguno / No aplica 172, Gratuidad 125, Renta Joven 84, Subsidio Alimentario 69, vacío 56, Generación E 9, Tablets Uniamazonia 9, Jóvenes en Acción 5, Otro 0 |
| `promedio_escala_corregida` | Verdadero 46, Falso 483, vacío 0 |
| Inscripciones por grupo artístico | Folclórica: Formación 82, Quynza 48 · Urbana: Baile Deportivo 54 · Música: Formación en Guitarra 102, Formación en Canto 53, Formación en Guitarra y Canto 6, Armonía Amazónica 26, Ensamble de Guitarras 11, Waira 6 · Salsa y Bachata 105 · Teatro: Artes Escénicas 16, Formación en Teatro y Actuación 16, Formación en Teatro 4 |
| `victima` en `Dim_Persona` (personas) | Sí 163, No 205, Sin dato 31 |

Validación de codificación: la consulta guardada en el PBIX no debe contener textos con `Ã`; `victima` debe quedar en 204 Sí / 265 No / 55 Sin dato, `discapacidad` debe tener 7 casos de `Sí/Por confirmar`, y `persona_key` no debe contener tildes.

## Problemas posibles

### “No se reconoce el nombre 'RutaDatos'”

Falta el parámetro `RutaDatos` o está mal escrito.

### “No se reconoce el nombre '07_Fact_Staging'”

La consulta `07_Fact_Staging` no existe o tiene otro nombre.

### “No se encuentra el archivo catalogos.xlsx”

La ruta de `RutaDatos` no termina en `01-Crudos`, o el archivo no está en `02-Externos`.

### “No se encuentra la columna X”

El nombre de una columna cambió en `07_Fact_Staging`. Revisa que las columnas sigan siendo las mismas.

### “La columna datos no existe”

La consulta asume que `07_Fact_Staging` todavía tiene la columna `datos`. Si ya la quitaste, elimina `"datos"` de la lista de `Table.RemoveColumns`.

## Siguiente paso

Cuando `08_Fact_Limpia` cargue sin errores:

1. Revisar los conteos.
2. Crear `Fact_Inscripciones` con las columnas finales.
3. Crear las dimensiones.
4. Crear las relaciones.
5. Crear las medidas DAX.
6. Construir el dashboard.
