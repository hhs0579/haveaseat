// lib/widgets/file_upload.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FileUploadField extends StatefulWidget {
  final String label;
  final String uploadPath;
  final bool isAllFileTypes;
  final Function(String)? onFileUploaded;
  final Function(File)? onFileSelected;

  const FileUploadField({
    Key? key,
    required this.label,
    required this.uploadPath,
    this.isAllFileTypes = false,
    this.onFileUploaded,
    this.onFileSelected,
  }) : super(key: key);

  @override
  State<FileUploadField> createState() => _FileUploadFieldState();
}

class _FileUploadFieldState extends State<FileUploadField> {
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: widget.isAllFileTypes ? FileType.any : FileType.custom,
        allowedExtensions:
            widget.isAllFileTypes ? null : ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;

        if (platformFile.size > 20 * 1024 * 1024) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일 크기는 20MB를 초과할 수 없습니다.')),
            );
          }
          return;
        }

        setState(() {
          _selectedFileName = platformFile.name;
        });

        // 파일 업로드 시작
        setState(() {
          _isUploading = true;
        });

        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${platformFile.name}';
          final ref = FirebaseStorage.instance
              .ref()
              .child(widget.uploadPath)
              .child(fileName);

          // 웹 환경에서는 bytes를 사용
          final uploadTask = ref.putData(
            platformFile.bytes!,
            SettableMetadata(contentType: 'application/octet-stream'),
          );

          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          print('File uploaded successfully, URL: $downloadUrl');
          widget.onFileUploaded?.call(downloadUrl);
        } catch (e) {
          print('Error uploading file: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('파일 업로드 실패: $e')),
            );
          }
        } finally {
          setState(() {
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> uploadFileToFirebase() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName';
      final ref = FirebaseStorage.instance
          .ref()
          .child(widget.uploadPath)
          .child(fileName);

      final uploadTask = ref.putFile(_selectedFile!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      widget.onFileUploaded?.call(downloadUrl);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColor.font1,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          height: widget.isAllFileTypes ? 0.0 : 12.0,
        ),
        Row(
          children: [
            Container(
              width: 604,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.line1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedFileName ?? '파일을 업로드 해주세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedFileName != null
                            ? AppColor.font1
                            : AppColor.font2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  if (_selectedFileName != null && !_isUploading)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _selectedFileName = null;
                          _selectedFile = null;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _isUploading ? null : pickFile,
              child: Container(
                width: 104,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: _isUploading ? AppColor.font2 : AppColor.primary,
                  ),
                ),
                child: Center(
                  child: Text(
                    '파일 업로드',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isUploading ? AppColor.font2 : AppColor.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.isAllFileTypes
              ? '* 최대 20MB 크기의 파일을 업로드할 수 있습니다.'
              : '* PDF, JPG, JPEG, PNG 파일만 업로드 가능합니다.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColor.font2,
          ),
        ),
      ],
    );
  }
}
