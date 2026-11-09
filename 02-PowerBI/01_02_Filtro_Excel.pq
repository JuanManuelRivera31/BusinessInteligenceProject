    // ============================================================
    // 01_02_Filtro_Excel  (v1.8)
    // Paso SoloExcel de las consultas 01_Archivos y 02_Hojas.
    // Va justo después de  Origen = Folder.Files(RutaDatos),
    // y el paso siguiente (#"Otras columnas quitadas") lee de SoloExcel
    // en lugar de Origen.
    // Evita que la actualización falle si un crudo está abierto en Excel
    // (archivos temporales ~$) o si hay archivos que no son .xlsx.
    // ============================================================
    SoloExcel = Table.SelectRows(
        Origen,
        each Text.Lower([Extension]) = ".xlsx" and not Text.StartsWith([Name], "~$")
    ),
