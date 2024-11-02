import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'dart:js' as js;

class AddressSearchField extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController detailController;

  const AddressSearchField({
    Key? key,
    required this.controller,
    required this.detailController,
  }) : super(key: key);

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  @override
  void initState() {
    super.initState();
    // JavaScript 이벤트 리스너 설정
    html.window.addEventListener('message', (event) {
      if (event is html.MessageEvent) {
        try {
          final data = json.decode(event.data);
          if (data['type'] == 'address') {
            if (mounted) {
              // mounted 체크 추가
              setState(() {
                widget.controller.text = data['address'];
              });
            } else {
              widget.controller.text = data['address'];
            }
          }
        } catch (e) {
          print('Error parsing message: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    // 이벤트 리스너 제거
    html.window.removeEventListener('message', (event) {});
    super.dispose();
  }

  void searchAddress() {
    // eval을 사용한 방법
    js.context.callMethod('eval', ['searchAddress()']);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '배송지 주소',
          style: TextStyle(
            fontSize: 14,
            color: AppColor.font1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              height: 48,
              width: 618,
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.line1),
              ),
              child: TextFormField(
                controller: widget.controller,
                readOnly: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                  hintText: '주소를 검색해 주세요',
                  hintStyle: TextStyle(
                    color: AppColor.font2,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: searchAddress,
              child: Container(
                height: 48,
                width: 90,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: AppColor.primary),
                ),
                child: const Center(
                  child: Text(
                    '주소 검색',
                    style: TextStyle(
                      color: AppColor.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 48,
          width: 720,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: TextFormField(
            controller: widget.detailController,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
              hintText: '상세 주소를 입력해 주세요',
              hintStyle: TextStyle(
                color: AppColor.font2,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
