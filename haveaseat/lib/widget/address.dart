import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'dart:js' as js;

class AddressSearchField extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController detailController;
  final String labelText;
  final FocusNode? focusNode; // FocusNode 추가
  final FocusNode? detailFocusNode; // 상세주소 FocusNode 추가
  final FocusNode? nextFocusNode; // 다음 필드로 이동할 FocusNode 추가

  const AddressSearchField({
    Key? key,
    required this.controller,
    required this.detailController,
    this.labelText = '배송지 주소',
    this.focusNode, // 생성자에 추가
    this.detailFocusNode, // 생성자에 추가
    this.nextFocusNode, // 생성자에 추가
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

                // 주소가 입력되면 상세주소 필드로 포커스 이동
                if (widget.detailFocusNode != null) {
                  FocusScope.of(context).requestFocus(widget.detailFocusNode);
                }
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
        Text(
          widget.labelText,
          style: const TextStyle(
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
              width: 538,
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.line1),
              ),
              child: TextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode, // FocusNode 사용
                textInputAction: TextInputAction.next, // 다음 필드로 이동 액션 추가
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
                onTap: searchAddress, // 텍스트필드 클릭시 주소 검색 실행
                onFieldSubmitted: (_) {
                  if (widget.detailFocusNode != null) {
                    FocusScope.of(context).requestFocus(widget.detailFocusNode);
                  }
                },
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
          width: 640,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: TextFormField(
            controller: widget.detailController,
            focusNode: widget.detailFocusNode, // 상세주소 FocusNode 사용
            textInputAction: TextInputAction.next, // 다음 필드로 이동 액션 추가
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
            onFieldSubmitted: (_) {
              // 다음 필드로 포커스 이동
              if (widget.nextFocusNode != null) {
                FocusScope.of(context).requestFocus(widget.nextFocusNode);
              }
            },
          ),
        ),
      ],
    );
  }
}
