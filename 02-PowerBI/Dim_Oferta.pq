let
    // ============================================================
    // Dim_Oferta  (v1.8)
    // Oferta artística: disciplina, modalidad, proceso, grupo artístico, público.
    // La llave oferta_key se calcula igual que en Fact_Inscripciones (no cambiar).
    // Nuevo en v1.8: modalidad, modalidad_orden, disciplina_orden y grupo_orden.
    // El orden sale de la hoja "grupos" de catalogos.xlsx.
    // Requiere: 08_Fact_Limpia y RutaCatalogos
    // ============================================================
    Origen = #"08_Fact_Limpia",
    fnKeyPart = (v as nullable any) as text => if v = null then "" else Text.Upper(Text.Trim(Text.From(v))),

    Base = Table.SelectColumns(Origen, {"disciplina", "grupo", "proceso", "publico", "grupo_artistico"}),
    ConClave = Table.AddColumn(
        Base,
        "oferta_key",
        each Text.Combine(
            {
                fnKeyPart([disciplina]),
                fnKeyPart([grupo]),
                fnKeyPart([proceso]),
                fnKeyPart([publico]),
                fnKeyPart([grupo_artistico])
            },
            "|"
        ),
        type text
    ),
    Unico = Table.Distinct(ConClave, {"oferta_key"}),

    // ---- Modalidad: agrupa los procesos ----
    ConModalidad = Table.AddColumn(
        Unico,
        "modalidad",
        each
            if [proceso] = "Formación" or [proceso] = "Semillero" then "Formación"
            else if [proceso] = "Planta" or [proceso] = "Representativo" then "Representativo"
            else if [proceso] = "Extensión" then "Extensión"
            else "Otro",
        type text
    ),
    ConModalidadOrden = Table.AddColumn(
        ConModalidad,
        "modalidad_orden",
        each
            if [modalidad] = "Formación" then 1
            else if [modalidad] = "Representativo" then 2
            else if [modalidad] = "Extensión" then 3
            else 9,
        Int64.Type
    ),

    // ---- Orden de visualización desde catalogos.xlsx (hoja grupos) ----
    Catalogo = Excel.Workbook(File.Contents(RutaCatalogos), null, true),
    Grupos = Table.PromoteHeaders(Catalogo{[Item = "grupos", Kind = "Sheet"]}[Data], [PromoteAllScalars = true]),
    GruposBase = Table.TransformColumnTypes(
        Table.SelectRows(Table.SelectColumns(Grupos, {"disciplina", "grupo", "orden"}), each [grupo] <> null),
        {{"orden", Int64.Type}}
    ),
    GruposClaves = Table.AddColumn(
        Table.AddColumn(GruposBase, "_g", each fnKeyPart([grupo]), type text),
        "_d", each fnKeyPart([disciplina]), type text
    ),
    OrdenGrupo = Table.Group(GruposClaves, {"_g"}, {{"grupo_orden", each List.Min([orden]), Int64.Type}}),
    OrdenDisciplina = Table.Group(GruposClaves, {"_d"}, {{"disciplina_orden", each List.Min([orden]), Int64.Type}}),

    ConClavesAux = Table.AddColumn(
        Table.AddColumn(ConModalidadOrden, "_g", each fnKeyPart([grupo_artistico]), type text),
        "_d", each fnKeyPart([disciplina]), type text
    ),
    ConOrdenGrupo = Table.ExpandTableColumn(
        Table.NestedJoin(ConClavesAux, {"_g"}, OrdenGrupo, {"_g"}, "og", JoinKind.LeftOuter),
        "og", {"grupo_orden"}
    ),
    ConOrdenDisciplina = Table.ExpandTableColumn(
        Table.NestedJoin(ConOrdenGrupo, {"_d"}, OrdenDisciplina, {"_d"}, "od", JoinKind.LeftOuter),
        "od", {"disciplina_orden"}
    ),
    SinAux = Table.RemoveColumns(ConOrdenDisciplina, {"_g", "_d"}),

    // Valores sin catálogo van al final (999) y quedan visibles para corregir el catálogo
    ConDefault = Table.TransformColumns(
        SinAux,
        {
            {"grupo_orden", each if _ = null then 999 else _, Int64.Type},
            {"disciplina_orden", each if _ = null then 999 else _, Int64.Type}
        }
    ),

    Resultado = Table.Sort(
        Table.ReorderColumns(
            ConDefault,
            {"oferta_key", "disciplina", "disciplina_orden", "modalidad", "modalidad_orden", "proceso",
             "grupo_artistico", "grupo_orden", "publico", "grupo"}
        ),
        {{"disciplina_orden", Order.Ascending}, {"grupo_orden", Order.Ascending}, {"proceso", Order.Ascending}}
    )
in
    Resultado
