import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  var sheet = excel['Sheet1'];
  sheet.appendRow([
    TextCellValue('matric'),
    TextCellValue('name'),
  ]);
  
  for (var row in sheet.rows) {
    for (int i=0; i<row.length; i++) {
      var header = row[i]?.value?.toString().toLowerCase().trim() ?? '';
      print('header $i: $header');
    }
  }
}
