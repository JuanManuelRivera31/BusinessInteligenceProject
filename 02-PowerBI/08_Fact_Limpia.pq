let
    // ============================================================
    // 08_Fact_Limpia
    // Limpieza de 07_Fact_Staging
    // Requiere: RutaCatalogos y 07_Fact_Staging
    // v1.8 (2026-11-09):
    //   - Cruce con catálogos por llave normalizada (fnClave): sin tildes,
    //     mayúsculas, sin signos y sin espacios dobles, en ambos lados.
    //   - fnEtnia, fnComunidad, fnBeneficio y fnDiscapacidad ignoran tildes.
    //   - Grupo artístico normalizado con la hoja grupos_artisticos.
    //   - Table.Buffer antes de deduplicar.
    //   - promedio_escala_corregida sin nulos.
    // ============================================================

    Origen = #"07_Fact_Staging",

    // Quitar columnas que solo servían para el staging
    SinStaging = Table.RemoveColumns(Origen, {"datos", "tipo", "oculta", "incluir"}),

    // ============================================================
    // Funciones auxiliares
    // ============================================================
    Digitos = {"0","1","2","3","4","5","6","7","8","9"},

    fnSinAcentos = (t as nullable any) as text =>
        List.Accumulate(
            {
                {"á","a"},{"é","e"},{"í","i"},{"ó","o"},{"ú","u"},
                {"Á","A"},{"É","E"},{"Í","I"},{"Ó","O"},{"Ú","U"},
                {"ñ","n"},{"Ñ","N"},{"ü","u"},{"Ü","U"}
            },
            if t = null then "" else Text.From(t),
            (state, current) => Text.Replace(state, current{0}, current{1})
        ),

    // Llave de comparación: sin tildes, mayúsculas, solo letras y dígitos,
    // espacios simples. "Ingenieria  de Sistemas " = "Ingeniería de Sistemas".
    Permitidos = {"A".."Z"} & Digitos,
    fnClave = (v as nullable any) as text =>
        let
            s = Text.Upper(fnSinAcentos(if v = null then "" else Text.Trim(Text.From(v)))),
            soloAlnum = Text.Combine(
                List.Transform(Text.ToList(s), each if List.Contains(Permitidos, _) then _ else " ")
            ),
            limpio = Text.Combine(List.Select(Text.Split(soloAlnum, " "), each _ <> ""), " ")
        in
            limpio,

    // Mayúsculas sin tildes para las reglas de texto
    fnU = (v as nullable any) as text =>
        if v = null then "" else Text.Upper(fnSinAcentos(Text.Trim(Text.From(v)))),

    fnNombre = (v as nullable any) as text =>
        let
            s = if v = null then "" else Text.Trim(Text.Clean(Text.From(v))),
            s2 = Text.Combine(List.Select(Text.Split(s, " "), each _ <> ""), " "),
            s3 = Text.Replace(s2, "S Tefany", "Stefany")
        in
            Text.Proper(s3),

    fnDocumento = (v as nullable any) as text =>
        let
            s = if v = null then "" else Text.Trim(Text.From(v)),
            s2 = if Text.EndsWith(s, ".0") then Text.Start(s, Text.Length(s) - 2) else s,
            s3 = Text.Remove(s2, {" ", "-", ".", ",", "'"})
        in
            s3,

    fnFecha = (v as nullable any) as nullable date =>
        let
            s = if v = null then "" else Text.Trim(Text.From(v)),
            porTexto = try Date.FromText(s, [Culture = "es-CO"]) otherwise null,
            porSerial = try Date.From(#datetime(1899,12,30,0,0,0) + #duration(Number.FromText(s, "en-US"),0,0,0)) otherwise null
        in
            if s = "" then null else if porTexto <> null then porTexto else porSerial,

    fnNumero = (v as nullable any) as nullable number =>
        let
            s = if v = null then "" else Text.Replace(Text.Trim(Text.From(v)), ",", "."),
            n = try Number.FromText(s, "en-US") otherwise null
        in
            n,

    fnPromedio = (v as nullable any) as nullable number =>
        let
            n = fnNumero(v)
        in
            if n = null then null
            else if n > 10 then n / 10
            else if n < 0 or n > 5 then null
            else n,

    fnBeneficio = (v as nullable any) as nullable text =>
        let
            u = fnU(v),
            soloNegaciones = u <> "" and List.AllTrue(
                List.Transform(Text.Split(u, " "), each List.Contains({"NO", "NA", "NN", ""}, _))
            ),
            esEPS = if u = "" then false else
                List.AnyTrue(
                    List.Transform(
                        {"EPS","SALUD","SANITAS","FAMAC","EMSSANAR","SANIDAD","ASMET"},
                        each Text.Contains(u, _)
                    )
                )
        in
            if u = "" then null
            else if esEPS then null
            else if Text.Contains(u, "GRATUIDAD")
                or Text.Contains(u, "GRATUITAD")
                or Text.Contains(u, "GRATIIDAD")
                or Text.Contains(u, "GRATUITIDAD") then "Gratuidad"
            else if Text.Contains(u, "RENTA JOVEN")
                or Text.Contains(u, "RENTA JOVEB") then "Renta Joven"
            else if Text.Contains(u, "SUBSIDIO")
                or Text.Contains(u, "SUB SIDIO") then "Subsidio Alimentario"
            else if Text.Contains(u, "GENERACION E") then "Generación E"
            else if Text.Contains(u, "JOVENES EN ACCION")
                or Text.Contains(u, "JOVEN EN ACCION") then "Jóvenes en Acción"
            else if Text.Contains(u, "TABLETS") then "Tablets Uniamazonia"
            else if Text.Contains(u, "NINGUNO")
                or Text.Contains(u, "NINGUNA")
                or soloNegaciones
                or Text.Contains(u, "NO APLICA")
                or Text.Contains(u, "NO APLICO")
                or u = "NO"
                or u = "NA" then "Ninguno / No aplica"
            else "Otro",

    fnDiscapacidad = (v as nullable any) as text =>
        let
            u = fnU(v),
            esBeneficio = if u = "" then false else
                List.AnyTrue(
                    List.Transform(
                        {"GRATUIDAD","RENTA","GENERACION","JOVEN","SUBSIDIO","TABLETS","EPS","SALUD","SANITAS"},
                        each Text.Contains(u, _)
                    )
                )
        in
            if u = "" then "Sin dato"
            else if esBeneficio then "No"
            else if Text.Contains(u, "NO") or Text.Contains(u, "NINGUN") then "No"
            else if u = "NN" then "Sin dato"
            else "Sí/Por confirmar",

    fnSexo = (v as nullable any) as text =>
        let u = if v = null then "" else Text.Upper(Text.Trim(Text.From(v))) in
            if u = "M" or u = "HOMBRE" or u = "MASCULINO" then "Hombre"
            else if u = "F" or u = "MUJER" or u = "FEMENINO" then "Mujer"
            else "Sin dato",

    fnVictima = (v as nullable any) as text =>
        let u = if v = null then "" else Text.Upper(Text.Trim(Text.From(v))) in
            if u = "SI" or u = "SÍ" then "Sí"
            else if u = "NO" then "No"
            else "Sin dato",

    fnEtnia = (v as nullable any) as text =>
        let u = fnU(v) in
            if u = "" or u = "NO APLICA" then "No aplica"
            else if Text.Contains(u, "INDIGENA") then "Indígena"
            else if Text.Contains(u, "NEGRA") or Text.Contains(u, "AFRO") then "Afrocolombiano"
            else if Text.Contains(u, "PALENQUERO") then "Palenquero"
            else "Otro",

    fnComunidad = (v as nullable any) as text =>
        let u = fnU(v) in
            if u = "" then "Sin dato"
            else if Text.Contains(u, "EGRES") or Text.Contains(u, "GRADUD") then "Egresado/Graduado"
            else if Text.Contains(u, "DOCENTE") then "Docente"
            else if Text.Contains(u, "ADMINISTRATIV") then "Administrativo"
            else if Text.Contains(u, "PENSION") then "Pensionado"
            else if Text.Contains(u, "EXTENSION") then "Extensión Social"
            else if Text.Contains(u, "ESTUDIANTE") then "Estudiante"
            else "No aplica",

    // ============================================================
    // 1. Corregir columnas desplazadas
    // ============================================================
    ConDesplazamiento = Table.AddColumn(
        SinStaging,
        "bloque_desplazado",
        each if [EPS] = null then false else try Text.Contains(Text.From([EPS]), "@") otherwise false,
        type logical
    ),
    ConEPS_Corr = Table.AddColumn(
        ConDesplazamiento,
        "EPS_Corr",
        each try Text.From(if [bloque_desplazado] then [ProgramaSocial] else [EPS]) otherwise null,
        type text
    ),
    ConCorreo_Corr = Table.AddColumn(
        ConEPS_Corr,
        "Correo_Corr",
        each try Text.From(if [bloque_desplazado] then [EPS] else [Correo]) otherwise null,
        type text
    ),
    ConCelular_Corr = Table.AddColumn(
        ConCorreo_Corr,
        "Celular_Corr",
        each try Text.From(if [bloque_desplazado] then [Correo] else [Celular]) otherwise null,
        type text
    ),
    ConProgramaSocial_Corr = Table.AddColumn(
        ConCelular_Corr,
        "ProgramaSocial_Corr",
        each if [bloque_desplazado] then null else try Text.From([ProgramaSocial]) otherwise null,
        type text
    ),
    SinColumnasViejas = Table.RemoveColumns(
        ConProgramaSocial_Corr,
        {"EPS", "Correo", "Celular", "ProgramaSocial"}
    ),
    ColumnasCorregidas = Table.RenameColumns(
        SinColumnasViejas,
        {
            {"EPS_Corr", "EPS"},
            {"Correo_Corr", "Correo"},
            {"Celular_Corr", "Celular"},
            {"ProgramaSocial_Corr", "ProgramaSocial"}
        }
    ),

    // ============================================================
    // 2. Beneficio y discapacidad
    // ============================================================
    ConBeneficioRaw = Table.AddColumn(
        ColumnasCorregidas,
        "BeneficioRaw",
        each Text.Combine(
            List.Select(
                {
                    if [ProgramaSocial] = null then null else Text.From([ProgramaSocial]),
                    if [Discapacidad] = null then null else Text.From([Discapacidad])
                },
                each _ <> null and _ <> ""
            ),
            " "
        ),
        type text
    ),
    ConBeneficio = Table.AddColumn(
        ConBeneficioRaw,
        "Beneficio",
        each fnBeneficio([BeneficioRaw]),
        type text
    ),
    ConDiscapacidadLimpia = Table.AddColumn(
        ConBeneficio,
        "DiscapacidadLimpia",
        each fnDiscapacidad([Discapacidad]),
        type text
    ),
    ConFlagBeneficio = Table.AddColumn(
        ConDiscapacidadLimpia,
        "beneficio_en_discapacidad",
        each try
            List.AnyTrue(
                List.Transform(
                    {"GRATUIDAD","RENTA","GENERACION","JOVEN","SUBSIDIO","TABLETS"},
                    each Text.Contains(fnU([Discapacidad]), _)
                )
            )
        otherwise false,
        type logical
    ),

    // ============================================================
    // 3. Nombres y documentos
    // ============================================================
    ConNombreDisplay = Table.AddColumn(
        ConFlagBeneficio,
        "NombreDisplay",
        each fnNombre([Nombre]),
        type text
    ),
    ConDocumentoTexto = Table.AddColumn(
        ConNombreDisplay,
        "DocumentoTexto",
        each if [Documento] = null then "" else Text.Trim(Text.From([Documento])),
        type text
    ),
    ConDocumentoTieneDigitos = Table.AddColumn(
        ConDocumentoTexto,
        "DocumentoTieneDigitos",
        each Text.Select([DocumentoTexto], Digitos) <> "",
        type logical
    ),
    ConEsNombreEnDocumento = Table.AddColumn(
        ConDocumentoTieneDigitos,
        "EsNombreEnDocumento",
        each
            [DocumentoTexto] <> ""
            and not List.Contains(
                {"NO APLICA", "N/A", "NA", "SIN DOCUMENTO"},
                Text.Upper([DocumentoTexto])
            )
            and not [DocumentoTieneDigitos],
        type logical
    ),
    ConNombreCorregido = Table.AddColumn(
        ConEsNombreEnDocumento,
        "NombreCorregido",
        each if [EsNombreEnDocumento]
            then [NombreDisplay] & " " & Text.Proper([DocumentoTexto])
            else [NombreDisplay],
        type text
    ),
    ConNombreNormalizado = Table.AddColumn(
        ConNombreCorregido,
        "NombreNormalizado",
        each fnSinAcentos(Text.Upper(Text.Trim([NombreCorregido]))),
        type text
    ),
    ConDocumentoLimpio = Table.AddColumn(
        ConNombreNormalizado,
        "DocumentoLimpio",
        each if [DocumentoTieneDigitos] then fnDocumento([Documento]) else null,
        type text
    ),
    ConDocumentoFaltante = Table.AddColumn(
        ConDocumentoLimpio,
        "documento_faltante",
        each not [DocumentoTieneDigitos],
        type logical
    ),
    ConNombrePartido = Table.AddColumn(
        ConDocumentoFaltante,
        "nombre_partido",
        each [EsNombreEnDocumento],
        type logical
    ),

    // ============================================================
    // 4. Fechas, edad, promedios, peso y estatura
    // ============================================================
    ConFecha = Table.AddColumn(
        ConNombrePartido,
        "FechaNacimientoDate",
        each fnFecha([FechaNacimiento]),
        type date
    ),
    ConFechaInvalida = Table.AddColumn(
        ConFecha,
        "fecha_invalida",
        each [FechaNacimientoDate] = null and [FechaNacimiento] <> null,
        type logical
    ),
    ConEdad = Table.AddColumn(
        ConFechaInvalida,
        "EdadNum",
        each try Number.FromText(Text.Select(Text.From([Edad]), Digitos), "en-US") otherwise null,
        Int64.Type
    ),
    ConEdadInvalida = Table.AddColumn(
        ConEdad,
        "edad_invalida",
        each [EdadNum] <> null and ([EdadNum] < 10 or [EdadNum] > 80),
        type logical
    ),
    ConPromSem = Table.AddColumn(
        ConEdadInvalida,
        "PromedioSemestreNum",
        each fnPromedio([PromedioSemestre]),
        type number
    ),
    ConPromAcum = Table.AddColumn(
        ConPromSem,
        "PromedioAcumuladoNum",
        each fnPromedio([PromedioAcumulado]),
        type number
    ),
    ConPromFlag = Table.AddColumn(
        ConPromAcum,
        "promedio_escala_corregida",
        each (fnNumero([PromedioSemestre]) ?? 0) > 10,
        type logical
    ),
    ConPesoRaw = Table.AddColumn(
        ConPromFlag,
        "PesoRaw",
        each try
            Number.FromText(
                Text.Replace(
                    Text.Select(
                        Text.From([Peso]),
                        {"0","1","2","3","4","5","6","7","8","9",".",","}
                    ),
                    ",",
                    "."
                ),
                "en-US"
            )
        otherwise null,
        type number
    ),
    ConEstaturaRaw = Table.AddColumn(
        ConPesoRaw,
        "EstaturaRaw",
        each try
            Number.FromText(
                Text.Replace(
                    Text.Select(
                        Text.From([Estatura]),
                        {"0","1","2","3","4","5","6","7","8","9",".",","}
                    ),
                    ",",
                    "."
                ),
                "en-US"
            )
        otherwise null,
        type number
    ),
    ConPesoKg = Table.AddColumn(
        ConEstaturaRaw,
        "PesoKg",
        each if [PesoRaw] = null or [PesoRaw] < 30 or [PesoRaw] > 150
            then null
            else [PesoRaw],
        type number
    ),
    ConEstaturaM = Table.AddColumn(
        ConPesoKg,
        "EstaturaM",
        each if [EstaturaRaw] = null then null
            else if [EstaturaRaw] > 3 then
                if [EstaturaRaw] / 100 < 1 or [EstaturaRaw] / 100 > 2.5
                    then null
                    else [EstaturaRaw] / 100
            else if [EstaturaRaw] < 1 or [EstaturaRaw] > 2.5 then null
            else [EstaturaRaw],
        type number
    ),
    ConPesoFlag = Table.AddColumn(
        ConEstaturaM,
        "peso_estatura_corregido",
        each
            ([PesoRaw] <> null and ([PesoRaw] < 30 or [PesoRaw] > 150))
            or ([EstaturaRaw] <> null and ([EstaturaRaw] < 1 or [EstaturaRaw] > 3)),
        type logical
    ),

    // ============================================================
    // 5. Categóricas
    // ============================================================
    ConSexo = Table.AddColumn(
        ConPesoFlag,
        "SexoNorm",
        each fnSexo([Sexo]),
        type text
    ),
    ConVictima = Table.AddColumn(
        ConSexo,
        "VictimaNorm",
        each fnVictima([Victima]),
        type text
    ),
    ConEtnia = Table.AddColumn(
        ConVictima,
        "GrupoEtnicoNorm",
        each fnEtnia([GrupoEtnico]),
        type text
    ),
    ConComunidad = Table.AddColumn(
        ConEtnia,
        "ComunidadNorm",
        each fnComunidad([Comunidad]),
        type text
    ),

    // ============================================================
    // 6. Catálogos externos
    // ============================================================
    Catalogo = Excel.Workbook(File.Contents(RutaCatalogos), null, true),
    GetSheet = (nombre as text) as table =>
        Table.PromoteHeaders(
            Table.SelectRows(
                Catalogo,
                each [Item] = nombre and [Kind] = "Sheet"
            ){0}[Data],
            [PromoteAllScalars = true]
        ),
    CatalogoProgramas = GetSheet("programas"),
    CatalogoDependencias = GetSheet("dependencias"),
    CatalogoMunicipios = GetSheet("municipios"),
    CatalogoEPS = GetSheet("eps"),
    CatalogoGruposArtisticos = GetSheet("grupos_artisticos"),

    MergeCatalogo = (
        tbl as table,
        col as text,
        cat as table,
        catcol as text,
        cols as list,
        names as list
    ) as table =>
        let
            CatConClave = Table.AddColumn(cat, "_clave_cat", each fnClave(Record.Field(_, catcol)), type text),
            CatValida = Table.SelectRows(CatConClave, each [_clave_cat] <> ""),
            CatUnica = Table.Distinct(CatValida, {"_clave_cat"}),
            TblConClave = Table.AddColumn(tbl, "_clave_tbl", each fnClave(Record.Field(_, col)), type text),
            Unido = Table.NestedJoin(TblConClave, {"_clave_tbl"}, CatUnica, {"_clave_cat"}, "Cat", JoinKind.LeftOuter),
            Expandido = Table.ExpandTableColumn(Unido, "Cat", cols, names)
        in
            Table.RemoveColumns(Expandido, {"_clave_tbl"}),

    ConPrograma = MergeCatalogo(
        ConComunidad,
        "Programa",
        CatalogoProgramas,
        "programa_original",
        {"programa_normalizado", "facultad", "nivel"},
        {"ProgramaNorm", "Facultad", "Nivel"}
    ),
    ConEPSMerge = MergeCatalogo(
        ConPrograma,
        "EPS",
        CatalogoEPS,
        "eps_original",
        {"eps_normalizada"},
        {"EPSNorm"}
    ),
    ConMunicipio = MergeCatalogo(
        ConEPSMerge,
        "Municipio",
        CatalogoMunicipios,
        "municipio_original",
        {"municipio_normalizado", "departamento"},
        {"MunicipioNorm", "Departamento"}
    ),
    ConDependencia = MergeCatalogo(
        ConMunicipio,
        "Dependencia",
        CatalogoDependencias,
        "dependencia_original",
        {"dependencia_normalizada"},
        {"DependenciaNorm"}
    ),
    ConGrupoArtistico = MergeCatalogo(
        ConDependencia,
        "GrupoArtistico",
        CatalogoGruposArtisticos,
        "grupo_artistico_original",
        {"grupo_artistico_normalizado"},
        {"GrupoArtisticoNorm"}
    ),

    // ============================================================
    // 7. Fallbacks
    // ============================================================
    ConProgramaFinal = Table.AddColumn(
        ConGrupoArtistico,
        "ProgramaFinal",
        each try Text.From(if [ProgramaNorm] = null then [Programa] else [ProgramaNorm]) otherwise null,
        type text
    ),
    ConEPSFinal = Table.AddColumn(
        ConProgramaFinal,
        "EPSFinal",
        each try Text.From(if [EPSNorm] = null then [EPS] else [EPSNorm]) otherwise null,
        type text
    ),
    ConMunicipioFinal = Table.AddColumn(
        ConEPSFinal,
        "MunicipioFinal",
        each try Text.From(if [MunicipioNorm] = null then [Municipio] else [MunicipioNorm]) otherwise null,
        type text
    ),
    ConDependenciaFinal = Table.AddColumn(
        ConMunicipioFinal,
        "DependenciaFinal",
        each try Text.From(if [DependenciaNorm] = null then [Dependencia] else [DependenciaNorm]) otherwise null,
        type text
    ),
    ConGrupoArtisticoFinal = Table.AddColumn(
        ConDependenciaFinal,
        "GrupoArtisticoFinal",
        each try Text.From(if [GrupoArtisticoNorm] = null then Text.Trim(Text.From([GrupoArtistico])) else [GrupoArtisticoNorm]) otherwise null,
        type text
    ),

    // ============================================================
    // 8. Llave de persona y deduplicación
    // ============================================================
    ConPersonaKey = Table.AddColumn(
        ConGrupoArtisticoFinal,
        "PersonaKey",
        each if [DocumentoLimpio] <> null
            then Text.Combine({"D", [DocumentoLimpio], [NombreNormalizado]}, "|")
            else Text.Combine(
                {
                    "N",
                    [NombreNormalizado],
                    if [FechaNacimientoDate] = null then "" else Date.ToText([FechaNacimientoDate], "yyyyMMdd")
                },
                "|"
            ),
        type text
    ),
    ConCompletitud = Table.AddColumn(
        ConPersonaKey,
        "Completitud",
        each List.NonNullCount(
            {
                [DocumentoLimpio],
                [Correo],
                [Celular],
                [EPSFinal],
                [ProgramaFinal],
                [PromedioSemestreNum],
                [FechaNacimientoDate]
            }
        ),
        Int64.Type
    ),
    Ordenado = Table.Sort(
        ConCompletitud,
        {
            {"PersonaKey", Order.Ascending},
            {"periodo", Order.Ascending},
            {"disciplina", Order.Ascending},
            {"grupo", Order.Ascending},
            {"proceso", Order.Ascending},
            {"Completitud", Order.Descending}
        }
    ),
    // Table.Buffer fija el orden: Table.Distinct conserva la primera fila (la más completa)
    OrdenadoBuffer = Table.Buffer(Ordenado),
    Deduplicado = Table.Distinct(
        OrdenadoBuffer,
        {"PersonaKey", "periodo", "disciplina", "publico", "grupo", "GrupoArtisticoFinal", "proceso", "ProgramaFinal", "Facultad", "Nivel"}
    ),
    ConID = Table.AddIndexColumn(
        Deduplicado,
        "inscripcion_id",
        1,
        1,
        Int64.Type
    ),

    // ============================================================
    // 9. Renombrar y seleccionar columnas finales
    // ============================================================
    RenombradoFinal = Table.RenameColumns(
        ConID,
        {
            {"PersonaKey", "persona_key"},
            {"NombreCorregido", "nombre"},
            {"DocumentoLimpio", "documento"},
            {"EdadNum", "edad"},
            {"FechaNacimientoDate", "fecha_nacimiento"},
            {"SexoNorm", "sexo"},
            {"MunicipioFinal", "municipio"},
            {"Departamento", "departamento"},
            {"GrupoEtnicoNorm", "grupo_etnico"},
            {"VictimaNorm", "victima"},
            {"EPSFinal", "eps"},
            {"Beneficio", "beneficio"},
            {"DiscapacidadLimpia", "discapacidad"},
            {"PromedioSemestreNum", "promedio_semestre"},
            {"PromedioAcumuladoNum", "promedio_acumulado"},
            {"PesoKg", "peso_kg"},
            {"EstaturaM", "estatura_m"},
            {"Logros", "logros"},
            {"Seguimiento", "seguimiento"},
            {"No", "fila_origen"},
            {"ProgramaFinal", "programa"},
            {"Facultad", "facultad"},
            {"Nivel", "nivel"},
            {"DependenciaFinal", "dependencia"},
            {"ComunidadNorm", "comunidad"},
            {"GrupoArtisticoFinal", "grupo_artistico"},
            {"Correo", "correo"},
            {"Celular", "celular"},
            {"Codigo", "codigo"},
            {"RH", "rh"}
        }
    ),
    Final = Table.SelectColumns(
        RenombradoFinal,
        {
            "inscripcion_id",
            "persona_key",
            "periodo",
            "disciplina",
            "publico",
            "proceso",
            "grupo",
            "grupo_artistico",
            "comunidad",
            "programa",
            "facultad",
            "nivel",
            "dependencia",
            "documento",
            "nombre",
            "edad",
            "fecha_nacimiento",
            "sexo",
            "municipio",
            "departamento",
            "grupo_etnico",
            "victima",
            "eps",
            "beneficio",
            "discapacidad",
            "promedio_semestre",
            "promedio_acumulado",
            "peso_kg",
            "estatura_m",
            "logros",
            "seguimiento",
            "correo",
            "celular",
            "codigo",
            "rh",
            "archivo",
            "hoja",
            "fila_origen",
            "layout",
            "notas",
            "bloque_desplazado",
            "documento_faltante",
            "nombre_partido",
            "fecha_invalida",
            "edad_invalida",
            "promedio_escala_corregida",
            "peso_estatura_corregido",
            "beneficio_en_discapacidad"
        }
    ),
    Tipos = Table.TransformColumnTypes(
        Final,
        {
            {"inscripcion_id", Int64.Type},
            {"edad", Int64.Type},
            {"fecha_nacimiento", type date},
            {"promedio_semestre", type number},
            {"promedio_acumulado", type number},
            {"peso_kg", type number},
            {"estatura_m", type number},
            {"bloque_desplazado", type logical},
            {"documento_faltante", type logical},
            {"nombre_partido", type logical},
            {"fecha_invalida", type logical},
            {"edad_invalida", type logical},
            {"promedio_escala_corregida", type logical},
            {"peso_estatura_corregido", type logical},
            {"beneficio_en_discapacidad", type logical}
        }
    )
in
    Tipos
