let
    // ============================================================
    // Cat_Periodos
    // Catálogo de periodos académicos con fechas de inicio y fin.
    // Fuente única de fechas del modelo.
    // Expresión M compartida: no se carga como tabla.
    // Requiere: RutaCatalogos (hoja "periodos" de catalogos.xlsx)
    // ============================================================

    Origen = Excel.Workbook(File.Contents(RutaCatalogos), null, true),
    Hoja = Origen{[Item = "periodos", Kind = "Sheet"]}[Data],
    Encabezados = Table.PromoteHeaders(Hoja, [PromoteAllScalars = true]),

    // Quitar filas vacías del catálogo
    SinVacias = Table.SelectRows(
        Encabezados,
        each [periodo] <> null and Text.Trim(Text.From([periodo])) <> ""
    ),

    // periodo siempre como texto ("2025-01")
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
