// lib/widgets/file_upload.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FileUploadField extends StatefulWidget {
  final String label;
  final String uploadPath;
  final bool isAllFileTypes; // 모든 파일 타입 허용 여부
  final Function(String)? onFileUploaded;

  const FileUploadField({
    Key? key,
    required this.label,
    required this.uploadPath,
    this.isAllFileTypes = false, // 기본값은 false (제한된 파일 타입)
    this.onFileUploaded,
  }) : super(key: key);

  @override
  State<FileUploadField> createState() => _FileUploadFieldState();
}

class _FileUploadFieldState extends State<FileUploadField> {
  String? _selectedFileName;
  Uint8List? _selectedFile;
  bool _isUploading = false;

  Future<void> pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: widget.isAllFileTypes ? FileType.any : FileType.custom,
        allowedExtensions:
            widget.isAllFileTypes ? null : ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        final file = result.files.first;
        // 파일 크기 체크 (20MB)
        if (file.size > 20 * 1024 * 1024) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일 크기는 20MB를 초과할 수 없습니다.')),
            );
          }
          return;
        }

        setState(() {
          _selectedFileName = file.name;
          _selectedFile = file.bytes;
        });

        if (_selectedFile != null) {
          await uploadFileToFirebase();
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
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.uploadPath)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putData(
        _selectedFile!,
        SettableMetadata(contentType: 'application/octet-stream'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 콜백으로 URL 전달
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
              onTap: _isUploading ? null : pickAndUploadFile,
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
