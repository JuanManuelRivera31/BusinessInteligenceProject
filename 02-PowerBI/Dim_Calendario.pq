let
    // ============================================================
    // Dim_Calendario
    // Calendario diario de años completos generado desde Cat_Periodos.
    // Cada día pertenece al semestre académico que lo contiene.
    // Requiere: Cat_Periodos
    // Configuración en el modelo:
    //   - Marcada como tabla de fechas (fecha = columna clave)
    //   - mes ordenado por mes_num; periodo_nombre por periodo_orden
    //   - Ocultas: mes_num, periodo_orden, es_inicio_periodo
    //   - Relación: Dim_Calendario[fecha] (1) -> Fact_Inscripciones[fecha_periodo] (*)
    // ============================================================

    Periodos = Table.Buffer(Cat_Periodos),

    // Rango: del 1 de enero del primer año al 31 de diciembre del último
    AnioInicio  = List.Min(List.Transform(Periodos[fecha_inicio], each Date.Year(_))),
    AnioFin     = List.Max(List.Transform(Periodos[fecha_fin], each Date.Year(_))),
    FechaInicio = #date(AnioInicio, 1, 1),
    FechaFin    = #date(AnioFin, 12, 31),
    NumDias     = Duration.Days(FechaFin - FechaInicio) + 1,

    ListaFechas = List.Dates(FechaInicio, NumDias, #duration(1, 0, 0, 0)),
    Base = Table.FromList(ListaFechas, Splitter.SplitByNothing(), type table [fecha = date]),

    // ============================================================
    // Atributos de calendario
    // ============================================================
    ConAnio      = Table.AddColumn(Base, "anio", each Date.Year([fecha]), Int64.Type),
    ConMesNum    = Table.AddColumn(ConAnio, "mes_num", each Date.Month([fecha]), Int64.Type),
    ConMes       = Table.AddColumn(ConMesNum, "mes", each Text.Proper(Date.MonthName([fecha], "es-CO")), type text),
    ConAnioMes   = Table.AddColumn(
        ConMes, "anio_mes",
        each Text.From([anio]) & "-" & Text.PadStart(Text.From([mes_num]), 2, "0"), type text),
    ConTrimestre = Table.AddColumn(ConAnioMes, "trimestre", each "T" & Text.From(Date.QuarterOfYear([fecha])), type text),

    // ============================================================
    // Atributos de periodo académico (desde Cat_Periodos)
    // ============================================================
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
