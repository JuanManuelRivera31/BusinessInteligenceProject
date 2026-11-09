let
    // ============================================================
    // Dim_Persona  (v1.8)
    // Una fila por persona. Los atributos se toman del periodo más reciente
    // (Slowly Changing Dimension tipo 1).
    // v1.8: Table.Buffer antes de Table.Distinct para que se conserve
    // de forma determinística la fila del periodo más reciente.
    // Requiere: 08_Fact_Limpia
    // ============================================================
    Origen = #"08_Fact_Limpia",
    Filtrado = Table.SelectRows(Origen, each [persona_key] <> null),
    Ordenado = Table.Buffer(Table.Sort(Filtrado, {{"periodo", Order.Descending}, {"inscripcion_id", Order.Ascending}})),
    Unico = Table.Distinct(Ordenado, {"persona_key"}),
    Base = Table.SelectColumns(
        Unico,
        {"persona_key", "documento", "nombre", "sexo", "fecha_nacimiento", "grupo_etnico", "victima", "eps", "beneficio", "discapacidad", "comunidad", "dependencia", "codigo"}
    ),
    Resultado = Table.Sort(Base, {{"nombre", Order.Ascending}})
in
    Resultado
