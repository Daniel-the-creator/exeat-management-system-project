import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class AllocateStudentsScreen extends StatefulWidget {
  const AllocateStudentsScreen({super.key});

  @override
  State<AllocateStudentsScreen> createState() => _AllocateStudentsScreenState();
}

class _AllocateStudentsScreenState extends State<AllocateStudentsScreen> {
  bool isUploading = false;
  int totalRows = 0;
  int processedRows = 0;

  Future<void> pickAndUploadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          isUploading = true;
          processedRows = 0;
          totalRows = 0;
        });

        var bytes = result.files.single.bytes;
        if (bytes == null) {
          Get.snackbar('Error', 'Failed to read file data.');
          setState(() {
            isUploading = false;
          });
          return;
        }
        var excel = Excel.decodeBytes(bytes);

        Map<String, Map<String, dynamic>> studentsData = {};

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          bool isFirstRow = true;
          int matricIndex = -1;
          int nameIndex = -1;
          int emailIndex = -1;
          int deptIndex = -1;
          int hallIndex = -1;
          int phoneIndex = -1;

          for (var row in sheet.rows) {
            if (matricIndex == -1) {
              for (int i = 0; i < row.length; i++) {
                String header =
                    row[i]?.value?.toString().toLowerCase().trim() ?? '';
                if (header.contains('matric')) {
                  matricIndex = i;
                } else if (header.contains('name')) {
                  nameIndex = i;
                } else if (header.contains('email')) {
                  emailIndex = i;
                } else if (header.contains('dept') ||
                    header.contains('department')) {
                  deptIndex = i;
                } else if (header.contains('hall') ||
                    header.contains('hostel')) {
                  hallIndex = i;
                } else if (header.contains('phone')) {
                  phoneIndex = i;
                }
              }
              if (matricIndex != -1) {
                continue;
              }
            } else {
              if (row[matricIndex] != null) {
                String matricNo = row[matricIndex]?.value?.toString() ?? '';
                if (matricNo.isNotEmpty) {
                  studentsData[matricNo] = {
                    'matricNo': matricNo,
                    'fullName': nameIndex != -1
                        ? (row[nameIndex]?.value?.toString() ?? '')
                        : '',
                    'email': emailIndex != -1
                        ? (row[emailIndex]?.value?.toString() ?? '')
                        : '',
                    'department': deptIndex != -1
                        ? (row[deptIndex]?.value?.toString() ?? '')
                        : '',
                    'hall': hallIndex != -1
                        ? (row[hallIndex]?.value?.toString() ?? '')
                        : '',
                    'phone': phoneIndex != -1
                        ? (row[phoneIndex]?.value?.toString() ?? '')
                        : '',
                    'role': 'student',
                    'profileImage': '',
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                }
              }
            }
          }
        }

        setState(() {
          totalRows = studentsData.length;
        });

        if (totalRows == 0) {
          Get.snackbar('Error',
              'No student data found or invalid format. Please ensure headers include Matric, Name, Email, Dept, Hall.');
          setState(() {
            isUploading = false;
          });
          return;
        }

        final batch = FirebaseFirestore.instance.batch();
        for (var data in studentsData.values) {
          String matric = data['matricNo'];
          var docRef = FirebaseFirestore.instance
              .collection('allocated_students')
              .doc(matric);
          batch.set(docRef, data, SetOptions(merge: true));

          setState(() {
            processedRows++;
          });
        }
        await batch.commit();

        Get.snackbar('Success', 'Successfully allocated $totalRows students.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload file: $e');
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocate Students'),
        backgroundColor: const Color(0xff060121),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.upload_file,
                size: 80,
                color: Color(0xff2d1b5e),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Excel File to Allocate Students',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff060121),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Ensure the Excel file has columns for: Matric, Name, Email, Dept, Hall, Phone.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (isUploading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Processing... $processedRows / $totalRows'),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: pickAndUploadExcel,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Select Excel File to allocate students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2d1b5e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
