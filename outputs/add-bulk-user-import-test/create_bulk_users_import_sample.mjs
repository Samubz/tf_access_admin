import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "/Users/samugomez/Documents/Development/projects/rails/tf_access_admin/outputs/add-bulk-user-import-test";
const outputPath = `${outputDir}/bulk_users_import_sample.xlsx`;

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Usuarios");
sheet.showGridLines = false;

const headers = [
  "nombre",
  "apellido",
  "documento",
  "telefono",
  "email",
  "fecha_nacimiento",
];

const users = [
  ["Sofia", "Rojas", "11111111-1", "+56911110001", "sofia.rojas@example.com", "14/03/1988"],
  ["Mateo", "Fernandez", "11111112-2", "+56911110002", "mateo.fernandez@example.com", "27/07/1991"],
  ["Valentina", "Morales", "11111113-3", "+56911110003", "valentina.morales@example.com", "05/11/1985"],
  ["Benjamin", "Castillo", "11111114-4", "+56911110004", "benjamin.castillo@example.com", "22/01/1994"],
  ["Isidora", "Vargas", "11111115-5", "+56911110005", "isidora.vargas@example.com", "09/09/1990"],
  ["Tomas", "Silva", "11111116-6", "+56911110006", "tomas.silva@example.com", "18/06/1982"],
  ["Emilia", "Gonzalez", "11111117-7", "+56911110007", "emilia.gonzalez@example.com", "30/12/1996"],
  ["Agustin", "Munoz", "11111118-8", "+56911110008", "agustin.munoz@example.com", "03/04/1989"],
  ["Florencia", "Navarro", "11111119-9", "+56911110009", "florencia.navarro@example.com", "25/08/1993"],
  ["Lucas", "Torres", "11111120-0", "+56911110010", "lucas.torres@example.com", "12/10/1987"],
  ["Josefa", "Herrera", "11111121-1", "+56911110011", "josefa.herrera@example.com", "06/02/1995"],
  ["Vicente", "Molina", "11111122-2", "+56911110012", "vicente.molina@example.com", "19/05/1984"],
  ["Antonia", "Fuentes", "11111123-3", "+56911110013", "antonia.fuentes@example.com", "28/11/1992"],
  ["Martin", "Araya", "11111124-4", "+56911110014", "martin.araya@example.com", "01/01/1986"],
  ["Catalina", "Pizarro", "11111125-5", "+56911110015", "catalina.pizarro@example.com", "16/07/1998"],
  ["Diego", "Contreras", "11111126-6", "+56911110016", "diego.contreras@example.com", "23/03/1990"],
  ["Trinidad", "Espinoza", "11111127-7", "+56911110017", "trinidad.espinoza@example.com", "11/09/1983"],
  ["Maximiliano", "Cortes", "11111128-8", "+56911110018", "maximiliano.cortes@example.com", "04/12/1997"],
  ["Amanda", "Soto", "11111129-9", "+56911110019", "amanda.soto@example.com", "20/06/1991"],
  ["Joaquin", "Reyes", "11111130-0", "+56911110020", "joaquin.reyes@example.com", "08/08/1989"],
];

sheet.getRange("A1:F1").values = [headers];
sheet.getRange(`A2:F${users.length + 1}`).values = users;

const headerRange = sheet.getRange("A1:F1");
headerRange.format.fill.color = "#1F4E79";
headerRange.format.font.color = "#FFFFFF";
headerRange.format.font.bold = true;
headerRange.format.horizontalAlignment = "center";
headerRange.format.borders = { preset: "outside", style: "thin", color: "#1F4E79" };

const dataRange = sheet.getRange(`A2:F${users.length + 1}`);
dataRange.format.borders = {
  insideHorizontal: { style: "thin", color: "#E5E7EB" },
  bottom: { style: "thin", color: "#D1D5DB" },
};
dataRange.format.verticalAlignment = "center";

sheet.getRange(`A1:F${users.length + 1}`).format.autofitColumns();
sheet.getRange("A:A").format.columnWidth = 15;
sheet.getRange("B:B").format.columnWidth = 18;
sheet.getRange("C:C").format.columnWidth = 16;
sheet.getRange("D:D").format.columnWidth = 18;
sheet.getRange("E:E").format.columnWidth = 34;
sheet.getRange("F:F").format.columnWidth = 20;
sheet.getRange("A1:F1").format.rowHeight = 24;
sheet.freezePanes.freezeRows(1);

const textFormats = Array.from({ length: users.length }, () => ["@", "@", "@", "@", "@", "@"]);
sheet.getRange("A2:F21").format.numberFormat = textFormats;

await fs.mkdir(outputDir, { recursive: true });

const inspect = await workbook.inspect({
  kind: "table",
  range: "Usuarios!A1:F21",
  include: "values",
  tableMaxRows: 22,
  tableMaxCols: 6,
  maxChars: 5000,
});
console.log(inspect.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 50 },
  summary: "formula error scan",
});
console.log(errors.ndjson);

const preview = await workbook.render({ sheetName: "Usuarios", range: "A1:F21", scale: 2 });
const previewBytes = new Uint8Array(await preview.arrayBuffer());
await fs.writeFile(`${outputDir}/bulk_users_import_sample_preview.png`, previewBytes);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(outputPath);
