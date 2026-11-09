# 02-Externos

Esta carpeta contiene la configuración y las tablas de referencia que Power Query usa además de `01-Crudos`.

## Archivos

### `mapeo_fuentes.xlsx`

Una fila por archivo y hoja de `01-Crudos`. Indica:

- `periodo`
- `disciplina`
- `publico`
- `proceso`
- `grupo`
- `layout`
- `incluir`
- `notas`

La hoja `mapeo` es la que se conecta en Power Query. La hoja `resumen` es solo para auditoría.

### `catalogos.xlsx`

Tablas de referencia para normalizar valores:

- `periodos`
- `grupos`
- `programas`
- `dependencias`
- `municipios`
- `eps`
- `beneficios`
- `comunidades`
- `grupos_artisticos`: normalización del nombre del grupo artístico (`grupo_artistico_original` → `grupo_artistico_normalizado`)

Power Query cruza los catálogos por una llave normalizada: sin tildes, en mayúsculas, sin signos y sin espacios dobles. No hace falta repetir una fila solo porque cambien las tildes o las mayúsculas.

## Reglas

1. No cambiar los nombres de las columnas.
2. Agregar filas al final, no insertar filas en medio.
3. Si aparece un valor nuevo, agregarlo al catálogo correspondiente.
4. Si un archivo o hoja nueva no está en `mapeo_fuentes.xlsx`, no se carga.
5. Las notas son para humanos; Power Query no las usa.
6. No borrar filas de catálogo sin revisar el impacto en el dashboard.

## Qué lee Power BI

```text
01-Datos/01-Crudos
01-Datos/02-Externos/mapeo_fuentes.xlsx
01-Datos/02-Externos/catalogos.xlsx
```
