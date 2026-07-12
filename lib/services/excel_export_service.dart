import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';

class ExcelExportService {
  Future<String?> exportStudentsToExcel(List<UserModel> students) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['الطلاب المشتركين'];
      excel.delete('Sheet1'); // Remove default sheet

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('الرقم'),
        TextCellValue('الاسم الكامل'),
        TextCellValue('البريد الإلكتروني'),
        TextCellValue('رقم الهاتف'),
        TextCellValue('القسم/التوجيه'),
        TextCellValue('حالة الاشتراك'),
        TextCellValue('معرّف الجهاز (Device ID)'),
        TextCellValue('تاريخ الإنشاء'),
      ]);

      // Add Rows
      for (int i = 0; i < students.length; i++) {
        final s = students[i];
        sheetObject.appendRow([
          IntCellValue(i + 1),
          TextCellValue(s.name),
          TextCellValue(s.email),
          TextCellValue(s.phone),
          TextCellValue(s.category),
          TextCellValue(s.isSubscribed ? 'مشترك تفعيل كامل' : 'غير مشترك (مجاني بس)'),
          TextCellValue(s.deviceId),
          TextCellValue(s.createdAt?.toString() ?? ''),
        ]);
      }

      // Save file
      Directory? directory;
      if (Platform.isAndroid) {
        // Try getting external storage directory first
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }

      final String filePath = '${directory.path}/students_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      print('Excel export error: $e');
      return null;
    }
  }
}
