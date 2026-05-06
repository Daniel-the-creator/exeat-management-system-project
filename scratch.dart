import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  var sheet = excel['Sheet1'];
  sheet.appendRow([
    TextCellValue('matric'),
    TextCellValue('name'),
  ]);
  sheet.appendRow([
    TextCellValue('12345'),
    TextCellValue('John Doe'),
  ]);

  for (var row in sheet.rows) {
    for (var cell in row) {
      print('Value: ${cell?.value}');
      print('ToString: ${cell?.value?.toString()}');
    }
  }
}
