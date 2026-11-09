# Tarea: corregir los pendientes de limpieza y modelo (versión 1.8)

Trabaja en español. Lee toda la instrucción antes de empezar. Es la continuación de `Instruccion_ClaudeCode_Dim_Calendario.md`, que ya se ejecutó: `Dim_Calendario`, `Cat_Periodos` y las medidas de "Tiempo" existen y **no se tocan**.

## Contexto

- Raíz del proyecto: `C:\Users\juanm\Downloads\Proyecto\Proyecto`
- Modelo: `02-PowerBI\proyecto.pbix`, abierto en Power BI Desktop y conectado por el MCP `powerbi-modeling-mcp`.
- Catálogos: `01-Datos\02-Externos\catalogos.xlsx`
- El código nuevo está en la carpeta `cambios_v1.8\` de la raíz:
  - `08_Fact_Limpia.pq`: la consulta completa corregida, que reemplaza la partición actual.
  - `Dim_Oferta.pq`: la consulta completa nueva.
  - `Dim_Persona.pq`: la consulta completa nueva.

Problemas que se corrigen. Fueron diagnosticados contra los datos del modelo:

| # | Problema | Efecto actual |
|---|---|---|
| 1 | Los cruces con catálogos exigen texto idéntico (tildes, mayúsculas, espacios) | 217 de 475 inscripciones de estudiantes sin facultad; 325 de 529 sin departamento |
| 2 | `fnEtnia`, `fnComunidad`, `fnBeneficio` y `fnDiscapacidad` no ignoran tildes | "Pueblo Indígena" → "Otro"; "Extensión Social" → "No aplica"; "Generación E", "Jóvenes en acción" y "Renta jóven" → "Otro" |
| 3 | Grupo artístico sin normalizar | 21 variantes para 13 grupos reales; `Dim_Oferta` tiene 27 filas |
| 4 | `Dim_Oferta` no tiene modalidad ni orden | No se puede agrupar formación/representativo ni ordenar los ejes |
| 5 | `% Victimas` cuenta inscripciones e incluye a los no estudiantes, cuyo formato no pregunta eso | Da 39 %; lo correcto es cerca de 45 % |
| 6 | Nombres de facultad inconsistentes ("CIENCIAS DE LA SALUD" frente a "Ciencias de la Educación") | Ejes desordenados |
| 7 | `01_Archivos` y `02_Hojas` no filtran `.xlsx` ni los archivos temporales `~$` | Si alguien tiene un crudo abierto en Excel, la actualización falla |
| 8 | `Table.Distinct` después de `Table.Sort` sin `Table.Buffer` (en `08_Fact_Limpia` y `Dim_Persona`) | No se garantiza que se conserve la fila correcta |
| 9 | `promedio_escala_corregida` tiene nulos | La bandera queda vacía en 182 filas |
| 10 | Datos personales visibles; las tablas de staging 01–08 se cargan al modelo | Privacidad y tamaño |
| 11 | Formatos inconsistentes en las medidas de "Indicadores" | Presentación |

## Reglas

1. **Copias de seguridad antes de cualquier cambio:**
   - `02-PowerBI\proyecto_backup_AAAAMMDD_HHMM.pbix`
   - `01-Datos\03-Historico\catalogos_antes_v1.8_AAAAMMDD.xlsx`
2. Haz solo lo que pide esta instrucción. Problemas fuera del alcance van al informe, sin corregirlos.
3. No muestres nombres, documentos, correos ni teléfonos en tus respuestas. Solo conteos.
4. Si un paso falla o una validación no coincide, **detente**, explica qué pasó y propón la corrección. No improvises.
5. Para editar `catalogos.xlsx`, verifica primero que no esté abierto en Excel. Usa Python con `openpyxl` y conserva todas las demás hojas y filas tal como están.
6. Al final, recuérdame guardar el `.pbix` con Ctrl+S.

## Paso 0. Verificaciones previas

1. Confirma la conexión MCP con el modelo `proyecto` y que existen `Dim_Calendario`, `Cat_Periodos`, `Fact_Inscripciones` (529 filas), `Dim_Oferta` (27 filas) y `Dim_Persona` (399 filas).
2. Confirma que la partición actual de `08_Fact_Limpia` es igual a `02-PowerBI\08_Fact_Limpia.pq`, ignorando espacios al final de línea y la línea 5 del comentario (`Requiere: ...`). Si hay otras diferencias, detente y muéstramelas: significa que alguien cambió la consulta después del análisis.
3. Haz las dos copias de seguridad.

## Paso 1. Actualizar `catalogos.xlsx`

**1.1 Hoja `programas`, columna `facultad`.** Reemplaza estos valores; los demás quedan igual:

| Valor actual | Valor nuevo |
|---|---|
| CIENCIAS DE LA EDUCACIÓN | Ciencias de la Educación |
| Ciencias de la Educación | Ciencias de la Educación |
| INGENIERÍA | Ingeniería |
| CIENCIAS CONTABLES, ECONÓMICAS Y ADMINISTRATIVAS | Ciencias Contables, Económicas y Administrativas |
| CIENCIAS AGROPECUARIAS | Ciencias Agropecuarias |
| CIENCIAS BÁSICAS | Ciencias Básicas |
| CIENCIAS DE LA SALUD | Ciencias de la Salud |
| CIENCIAS POLÍTICAS | Derecho y Ciencias Políticas |
| DISTANCIA | Educación a Distancia |

`No aplica` y `Por confirmar` se mantienen.

**1.2 Hoja `grupos`.** En las 2 filas donde `grupo` = `Formación en Salsa (Danza)` (claves `salsa_planta` y `salsa_semillero`), cambia `grupo` a `Salsa y Bachata`. No toques ninguna otra columna.

**1.3 Hoja nueva `grupos_artisticos`**, al final del libro. Encabezados en la fila 1: `grupo_artistico_original`, `grupo_artistico_normalizado`, `disciplina`, `notas`.

| grupo_artistico_original | grupo_artistico_normalizado | disciplina | notas |
|---|---|---|---|
| Formación en Danza Folclórica | Formación en Danza Folclórica | Danza Folclórica | Canónico |
| Formación en Danza Urbana (Baile Deportivo) | Formación en Danza Folclórica | Danza Folclórica | 1 registro en el roster de folclor con el nombre de otro grupo; se asigna al grupo del roster |
| Grupo Quynza | Quynza | Danza Folclórica | Variante |
| Quynza | Quynza | Danza Folclórica | Canónico |
| Baile deportivo | Baile Deportivo | Danza Urbana | Variante |
| Formación en Guitarra | Formación en Guitarra | Música | Canónico |
| Formación en Canto | Formación en Canto | Música | Canónico |
| Formación en Guitarra y Canto | Formación en Guitarra y Canto | Música | Canónico |
| Formación en Canto, Guitarra | Formación en Guitarra y Canto | Música | Variante |
| Música (Guitarra -  Tiple - Bajo - Canto) | Formación en Guitarra y Canto | Música | Variante no estudiantes |
| Música (Guitarra -  Tiple - Bajo) | Formación en Guitarra | Música | Variante no estudiantes |
| Armonía Amazónica | Armonía Amazónica | Música | Canónico |
| Grupo Armonia Amazónica | Armonía Amazónica | Música | Variante |
| Ensamble de Guitarras | Ensamble de Guitarras | Música | Canónico |
| Ensamble de guitarras | Ensamble de Guitarras | Música | Variante |
| Ensamble de Guitarra | Ensamble de Guitarras | Música | Variante |
| Waira | Waira | Música | Canónico |
| Salsa y Bachata | Salsa y Bachata | Salsa y Bachata | Canónico |
| Formación en Salsa (Danza) | Salsa y Bachata | Salsa y Bachata | Variante |
| Artes Escénicas (Zancos y Performance) | Artes Escénicas (Zancos y Performance) | Teatro | Canónico |
| Artes Escénicas ( Zancos y Performance) | Artes Escénicas (Zancos y Performance) | Teatro | Variante |
| Formación en Teatro y Actuación | Formación en Teatro y Actuación | Teatro | Canónico |
| Formación en Teatro | Formación en Teatro | Teatro | Canónico |

**1.4 Hoja `LEEME`.** Agrega en la lista de hojas la línea: `- grupos_artisticos: normalización del nombre del grupo artístico.`

**1.5 Verificación.** Vuelve a abrir el archivo con `pandas` y confirma:
- Las hojas y el número de filas de cada una.
- `programas` tiene 10 valores distintos de facultad: las 7 facultades, `Educación a Distancia`, `No aplica` y `Por confirmar`, sin mayúsculas sostenidas.
- `grupos_artisticos` tiene 23 filas.

## Paso 2. Consultas de Power Query (particiones M)

**2.1 `01_Archivos` y `02_Hojas`.** En ambas, agrega después del paso `Origen = Folder.Files(RutaDatos),`:

```m
    SoloExcel = Table.SelectRows(
        Origen,
        each Text.Lower([Extension]) = ".xlsx" and not Text.StartsWith([Name], "~$")
    ),
```

Luego cambia el paso siguiente (`#"Otras columnas quitadas"`) para que lea de `SoloExcel` en lugar de `Origen`. No cambies nada más.

**2.2 `08_Fact_Limpia`.** Reemplaza toda la partición por el contenido de `cambios_v1.8\08_Fact_Limpia.pq`. Resumen de los cambios, para tu informe:
- Funciones nuevas `fnClave` (llave normalizada) y `fnU` (mayúsculas sin tildes).
- `MergeCatalogo` cruza por llave normalizada en ambos lados y quita duplicados del catálogo.
- `fnEtnia`, `fnComunidad`, `fnBeneficio` y `fnDiscapacidad` usan `fnU`.
- `fnBeneficio` reconoce "NINGUNA" y valores que solo contienen negaciones (por ejemplo "NA No").
- Merge nuevo con la hoja `grupos_artisticos` → columna `GrupoArtisticoFinal`. La deduplicación y la columna de salida `grupo_artistico` usan ese valor.
- `Table.Buffer` antes de `Table.Distinct`.
- `promedio_escala_corregida` sin nulos (`?? 0`).

**2.3 `Dim_Oferta`.** Reemplaza la partición por `cambios_v1.8\Dim_Oferta.pq`.

**2.4 `Dim_Persona`.** Reemplaza la partición por `cambios_v1.8\Dim_Persona.pq`.

**2.5 Refrescar.** Refresca el modelo completo. Si hay un error, detente e informa el mensaje exacto y la consulta.

## Paso 3. Validación de datos (con `08_Fact_Limpia` todavía cargada)

Ejecuta consultas DAX y compara. Los valores esperados vienen de una simulación de estas mismas reglas sobre los datos actuales.

| Control | Esperado |
|---|---|
| Filas de `08_Fact_Limpia` y de `Fact_Inscripciones` | 529 (2025-01: 308, 2025-02: 221) |
| Personas distintas | 399 (2025-1: 291, 2025-2: 200) |
| Filas de `Dim_Oferta` | 22 |
| `grupo_artistico` distintos | 13 |
| `Dim_Programa` | 24 filas (23 programas + 1 vacío de no estudiantes) |
| `Dim_Ubicacion` | 47 filas |
| Inscripciones con `publico` = "Estudiantes" y `facultad` vacía | **0** (antes 217) |
| Inscripciones con `departamento` vacío | **0** (antes 325) |
| Departamentos distintos | 17. Caquetá 443, Huila 46, Bogotá D.C. 11 |
| Facultad (inscripciones de estudiantes) | Ciencias de la Educación 175, Ingeniería 89, Ciencias Contables, Económicas y Administrativas 54, Ciencias de la Salud 52, Derecho y Ciencias Políticas 36, Ciencias Básicas 35, Ciencias Agropecuarias 32, Educación a Distancia 1, Por confirmar 1 |
| `grupo_etnico` en `08_Fact_Limpia` | No aplica 509, Indígena 11, Afrocolombiano 8, Palenquero 1, **Otro 0** |
| `comunidad` en `08_Fact_Limpia` | Estudiante 475, Egresado/Graduado 21, Docente 14, Extensión Social 13, Administrativo 3, Pensionado 2, No aplica 1 |
| `beneficio` en `08_Fact_Limpia` | Ninguno / No aplica 172, Gratuidad 125, Renta Joven 84, Subsidio Alimentario 69, vacío 56, Generación E 9, Tablets Uniamazonia 9, Jóvenes en Acción 5, **Otro 0** |
| `promedio_escala_corregida` | Verdadero 46, Falso 483, **vacío 0** |
| Inscripciones por disciplina y grupo artístico | Folclórica: Formación 82, Quynza 48 · Urbana: Baile Deportivo 54 · Música: Formación en Guitarra 102, Formación en Canto 53, Formación en Guitarra y Canto 6, Armonía Amazónica 26, Ensamble de Guitarras 11, Waira 6 · Salsa y Bachata 105 · Teatro: Artes Escénicas 16, Formación en Teatro y Actuación 16, Formación en Teatro 4 |
| `Dim_Oferta[modalidad]` | Solo Formación, Representativo y Extensión; **ninguna "Otro"** |
| `Dim_Oferta[grupo_orden]` y `[disciplina_orden]` | Ningún 999 |
| Medidas de "Tiempo", 2025-2 | Personas 200, Semestre anterior 291, Continúan 92, Nuevas 108 (sin cambios frente a la versión 1.7) |

Si algún conteo difiere, no corrijas por tu cuenta. Investiga la causa (por ejemplo, un valor nuevo que no está en el catálogo), muéstrame el detalle y propón la corrección.

## Paso 4. Propiedades del modelo

**4.1 Ordenar por columna**, en `Dim_Oferta`:
- `disciplina` → `disciplina_orden`
- `modalidad` → `modalidad_orden`
- `grupo_artistico` → `grupo_orden`

**4.2 Ocultar columnas:**
- `Dim_Oferta`: `oferta_key`, `grupo`, `disciplina_orden`, `modalidad_orden`, `grupo_orden`
- `Dim_Persona`: `persona_key`, `documento`, `nombre`, `codigo`, `fecha_nacimiento`, `eps`
- `Dim_Programa`: `programa_key`
- `Dim_Ubicacion`: `ubicacion_key`
- `Fact_Inscripciones`: `persona_key`, `oferta_key`, `programa_key`, `ubicacion_key`, `peso_kg`, `estatura_m`

**4.3 Medida `% Victimas`.** Reemplaza la expresión por la de abajo. Descripción: "Porcentaje de personas que se declaran víctimas, sobre las personas con dato (Sí o No). Excluye a los no estudiantes, cuyo formato no pregunta esta condición." Formato `0.0 %`.

```dax
DIVIDE (
    CALCULATE ( [Personas Distintas], Dim_Persona[victima] = "Sí" ),
    CALCULATE ( [Personas Distintas], Dim_Persona[victima] IN { "Sí", "No" } )
)
```

Esperado (verifícalo también como Sí ÷ (Sí + No) con una consulta aparte):
- Total: 164 / 368 = **44,6 %**
- 2025-1: 119 / 266 = 44,7 %
- 2025-2: 68 / 170 = 40,0 %

Si el total no coincide exactamente pero la verificación aparte sí, informa ambos valores: la diferencia vendría del orden de `Dim_Persona`, no de la medida.

**4.4 Formatos** de la carpeta "Indicadores":
- `Total Inscripciones` y `Personas Distintas`: `#,0`
- `Edad Promedio`: `0.0`
- `Promedio Semestre` y `Promedio Acumulado`: `0.00`
- `% Victimas`, `% Documento Faltante` y `% Bloque Desplazado`: `0.0 %`

## Paso 5. Desactivar la carga de las tablas de staging

Las tablas `01_Archivos` a `08_Fact_Limpia` deben seguir existiendo como consultas, porque las dimensiones y el hecho dependen de ellas, pero **no deben cargarse al modelo**: `08_Fact_Limpia` duplica nombres, documentos, correos y teléfonos.

1. Confirma que ninguna relación, medida ni columna calculada usa esas 8 tablas.
2. Convierte cada una en una **expresión M compartida con el mismo nombre y el mismo código** (como `Cat_Periodos`) y elimina la tabla. Respeta las dependencias para no dejar referencias rotas: 08 depende de 07, 07 de 05 y 06, y estas de 02 y 03.
3. Si el MCP no permite hacerlo de forma segura, **no lo fuerces**. Dime que lo haga a mano: en Power Query, clic derecho sobre cada consulta 01–08 → desmarcar "Habilitar carga".
4. Refresca y confirma que `Fact_Inscripciones` sigue con 529 filas, las 5 dimensiones con sus conteos del paso 3, y las medidas de "Tiempo" sin cambios.

## Paso 6. Archivos y documentación

1. **Código fuente en `02-PowerBI`:**
   - Reemplaza `08_Fact_Limpia.pq` con la versión nueva.
   - Agrega `Dim_Oferta.pq` y `Dim_Persona.pq`.
   - Crea `01_02_Filtro_Excel.pq` con el paso `SoloExcel`.
   - Actualiza `Medidas_Tiempo.dax` solo si cambió algo. No debería haber cambiado.
2. **Orden en la raíz:**
   - Mueve `Instruccion_ClaudeCode_Dim_Calendario.md` y esta instrucción a `03-Documentacion\instrucciones\`.
   - Elimina la carpeta `cambios_v1.8\` cuando su contenido ya esté en `02-PowerBI`.
3. **`03-Documentacion\05_limpieza_power_query.md`:**
   - Documenta la llave normalizada de los catálogos, la corrección de tildes en las funciones categóricas, el catálogo `grupos_artisticos`, `Table.Buffer` y la bandera sin nulos.
   - Actualiza la tabla de validaciones con los valores del paso 3.
   - Agrega la limitación conocida: 10 documentos tienen dos `persona_key` porque el nombre está escrito distinto. Unos 6 parecen la misma persona y unos 4 son documentos repetidos de personas distintas. Se conservan así porque la llave incluye el nombre para evitar colisiones.
4. **`03-Documentacion\03_modelo_estrella.md`:**
   - Las columnas nuevas de `Dim_Oferta` y su orden.
   - Las columnas ocultas.
   - La nueva definición de `% Victimas` y los formatos.
   - Que las consultas 01–08 son staging no cargado.
   - La tabla de validación actualizada.
5. **`03-Documentacion\00_estructura_proyecto.md`:**
   - Versión 1.8 y fecha de hoy.
   - Campo "Estado" actualizado.
   - Una fila en la bitácora con responsable "Juan Manuel".
   - Corregir las secciones 4 y 5.5: el archivo real es `proyecto.pbix` y no existe `tema.json` (déjalo como "pendiente: tema del dashboard").
   - Corregir la sección 9.2: las copias usan el formato `proyecto_backup_AAAAMMDD_HHMM.pbix`.
   - Actualizar la tabla de pendientes de la sección 10: marcar como hechos los que ya están resueltos en Power Query y agregar los de esta versión.
6. **`01-Datos\02-Externos\README.md`:** agrega `grupos_artisticos` a la lista de hojas de `catalogos.xlsx`.

## Informe final

1. Qué se creó, modificó y eliminó: catálogo, consultas, propiedades, medidas, archivos.
2. La tabla del paso 3 con lo esperado y lo obtenido, y el resultado de `% Victimas`.
3. Si el paso 5 se hizo por MCP o queda para hacerlo a mano.
4. Problemas fuera del alcance que viste, sin corregirlos.
5. El recordatorio de guardar el `.pbix` con Ctrl+S.
