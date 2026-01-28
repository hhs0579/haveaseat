import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:haveaseat/pages/login/signup.dart';
import 'package:haveaseat/riverpod/signupmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:haveaseat/widget/address.dart';
import 'package:haveaseat/widget/fileupload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haveaseat/components/colors.dart';
import 'dart:html' as html;
import 'package:screenshot/screenshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrderEstimatePage extends ConsumerStatefulWidget {
  final String customerId;
  final String estimateId;

  const OrderEstimatePage({
    super.key,
    required this.customerId,
    required this.estimateId,
  });

  @override
  ConsumerState<OrderEstimatePage> createState() => _OrderEstimatePageState();
}

class _OrderEstimatePageState extends ConsumerState<OrderEstimatePage> {
  final TextEditingController _memoController = TextEditingController();
  final screenshotController = ScreenshotController();
  final String _orderMemo = '';
  final ScrollController _scrollController = ScrollController();

  // 데이터 캐싱을 위한 변수 추가
  Map<String, dynamic>? _cachedData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndCacheData();
  }

  @override
  void dispose() {
    _memoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCacheData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _cachedData = await _loadEstimateData();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadEstimateData() async {
    try {
      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null) throw Exception('고객 정보를 찾을 수 없습니다');

      // 견적 정보 가져오기 (URL에서 전달받은 estimateId 사용)
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .get();

      if (!estimateDoc.exists) throw Exception('견적 정보를 찾을 수 없습니다');

      // 담당자 정보 가져오기 (assignedTo 필드 사용)
      final managerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customer.assignedTo)
          .get();

      return {
        'customer': customer,
        'estimate': estimateDoc.data(),
        'userData': managerDoc.data(), // 담당자 정보 추가
      };
    } catch (e) {
      print('Error loading estimate data: $e');
      rethrow;
    }
  }

  Widget _buildInfoCell(String label, String value) {
    return Container(
      width: 396, // 화면 비율에 맞게 조정할 예정
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            color: AppColor.back2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      context.go('/login'); // 로그인 페이지로 이동
    } catch (e) {
      print('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Widget _buildFileCell(String label, String value) {
    String getFileName(String url) {
      try {
        // URL의 마지막 '/' 이후의 문자열을 가져옴
        String fileName = url.split('/').last;
        // URL 인코딩 디코드
        fileName = Uri.decodeFull(fileName);
        // '?' 이전의 실제 파일명만 추출
        fileName = fileName.split('?').first;
        return fileName;
      } catch (e) {
        return url;
      }
    }

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            color: AppColor.back2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: value.isEmpty
                ? const Text('미첨부', style: TextStyle(color: Colors.red))
                : InkWell(
                    onTap: () {
                      html.window.open(value, '_blank');
                    },
                    child: Text(
                      getFileName(value),
                      style: const TextStyle(
                        color: AppColor.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ))
        ],
      ),
    );
  }

  Widget _buildFullWidthCell(String label, String value) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            color: AppColor.back2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// 각 섹션 위젯들
  Widget _buildCustomerSection(Map<String, dynamic> data) {
    final customer = data['customer'] as Customer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '고객 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 48) / 2;

            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('고객명', customer.name),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('연락처', customer.phone),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('이메일주소', customer.email),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('배송지주소', customer.address),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child:
                          _buildFileCell('사업자등록증', customer.businessLicenseUrl),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildFileCell(
                          '기타서류', customer.otherDocumentUrls.join(', ')),
                    ),
                  ],
                ),
                _buildFullWidthCell('기타입력사항', customer.note),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpaceSection(Map<String, dynamic> data) {
    final estimate = data['estimate'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '공간 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 48) / 2;

            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child:
                          _buildInfoCell('현장주소', estimate['siteAddress'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '공간오픈일정', _formatDate(estimate['openingDate'])),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('예산',
                          '${estimate['minBudget']?.toString() ?? '0'} ~ ${estimate['maxBudget']?.toString() ?? '0'}원'),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('공간면적',
                          '${estimate['spaceArea']?.toString() ?? '0'} ㎡'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child:
                          _buildInfoCell('업종', estimate['businessType'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '공간컨셉', estimate['concept']?.join(', ') ?? ''),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('수령자', estimate['recipient'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '수령자 연락처', estimate['contactNumber'] ?? ''),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '배송방법', estimate['shippingMethod'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '결제방법', estimate['paymentMethod'] ?? ''),
                    ),
                  ],
                ),
                _buildFileCell(
                    '공간도면 및 설계파일',
                    (estimate['designFileUrls'] as List<dynamic>?)
                            ?.join(', ') ??
                        ''),
                _buildFullWidthCell('기타입력사항', estimate['basicNotes'] ?? ''),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEstimateSection(Map<String, dynamic> data) {
    final estimate = data['estimate'] as Map<String, dynamic>;
    final furnitureList = (estimate['furnitureList'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '견적 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: Column(
            children: [
              // 테이블 헤더 - 모든 세로 구분선 추가
              Container(
                decoration: const BoxDecoration(
                  color: AppColor.back2,
                  border: Border(
                    bottom: BorderSide(color: AppColor.line1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTableHeader('상품명', 4, textAlign: TextAlign.left),
                    _buildVerticalDivider(),
                    _buildTableHeader('규격', 3, textAlign: TextAlign.center),
                    _buildVerticalDivider(),
                    _buildTableHeader('단가', 2, textAlign: TextAlign.center),
                    _buildVerticalDivider(),
                    _buildTableHeader('수량', 1, textAlign: TextAlign.center),
                    _buildVerticalDivider(),
                    _buildTableHeader('금액', 2, textAlign: TextAlign.center),
                  ],
                ),
              ),
              // 테이블 내용 - 모든 행에 구분선 추가
              ...furnitureList.map((furniture) {
                final price = furniture['price'] ?? 0;
                final quantity = furniture['quantity'] ?? 0;
                final itemTotal = price * quantity;

                return Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColor.line1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTableCell(furniture['name'] ?? '', 4),
                      _buildVerticalDivider(),
                      _buildTableCell(furniture['specification'] ?? '', 3,
                          textAlign: TextAlign.center),
                      _buildVerticalDivider(),
                      _buildTableCell('${_formatNumber(price)}원', 2,
                          textAlign: TextAlign.center),
                      _buildVerticalDivider(),
                      _buildTableCell(quantity.toString(), 1,
                          textAlign: TextAlign.center),
                      _buildVerticalDivider(),
                      _buildTableCell('${_formatNumber(itemTotal)}원', 2,
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }).toList(),
              // 총금액 행
              Container(
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColor.back2,
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 2),
                    bottom: BorderSide(color: AppColor.line1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 총금액 레이블
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: const Text(
                        '총금액',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // 총금액 값
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text(
                        '${_formatNumber(_calculateTotal(furnitureList))}원',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagerSection(Map<String, dynamic> data) {
    final customer = data['customer'] as Customer;
    final userData = data['userData'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '담당자 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 48) / 2;

            return Row(
              children: [
                SizedBox(
                  width: cellWidth,
                  child: _buildInfoCell('담당자 성함', userData?['name'] ?? ''),
                ),
                SizedBox(
                  width: cellWidth,
                  child: _buildInfoCell('연락처', userData?['phoneNumber'] ?? ''),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderSection(Map<String, dynamic> data) {
    final estimate = data['estimate'] as Map<String, dynamic>;
    final furnitureList = (estimate['furnitureList'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '발주 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: Column(
            children: [
              // 테이블 헤더
              Container(
                color: AppColor.back2,
                child: Row(
                  children: [
                    _buildTableHeader('제품명', 3),
                    _buildTableHeader('발주상태', 2),
                    _buildTableHeader('입고상태', 2),
                    _buildTableHeader('입고예정일', 3),
                  ],
                ),
              ),
              // 테이블 내용
              ...furnitureList.map((furniture) {
                int index = furnitureList.indexOf(furniture);
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColor.line1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 제품명
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            furniture['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      // 발주상태
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              hoverColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: furniture['orderStatus'] ?? '발주 신청',
                                items: const [
                                  DropdownMenuItem(
                                      value: '발주 신청',
                                      child: Text(
                                        '발주 신청',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      )),
                                  DropdownMenuItem(
                                      value: '발주 진행',
                                      child: Text(
                                        '발주 진행',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      )),
                                  DropdownMenuItem(
                                      value: '발주 완료',
                                      child: Text(
                                        '발주 완료',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      )),
                                ],
                                onChanged: (String? newValue) async {
                                  if (newValue != null) {
                                    final updatedList =
                                        List<Map<String, dynamic>>.from(
                                            furnitureList);
                                    updatedList[index] = {
                                      ...updatedList[index],
                                      'orderStatus': newValue,
                                    };
                                    await FirebaseFirestore.instance
                                        .collection('estimates')
                                        .doc(widget.estimateId)
                                        .update({
                                      'furnitureList': updatedList,
                                    });

                                    // 캐시된 데이터 업데이트 (스크롤 위치 유지)
                                    if (_cachedData != null) {
                                      (_cachedData!['estimate'] as Map<String,
                                              dynamic>)['furnitureList'] =
                                          updatedList;
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 입고상태
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              hoverColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: furniture['receivingStatus'] ?? '미입고',
                                items: const [
                                  DropdownMenuItem(
                                      value: '미입고',
                                      child: Text(
                                        '미입고',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      )),
                                  DropdownMenuItem(
                                      value: '입고',
                                      child: Text(
                                        '입고',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      )),
                                ],
                                onChanged: (String? newValue) async {
                                  if (newValue != null) {
                                    final updatedList =
                                        List<Map<String, dynamic>>.from(
                                            furnitureList);
                                    updatedList[index] = {
                                      ...updatedList[index],
                                      'receivingStatus': newValue,
                                    };
                                    await FirebaseFirestore.instance
                                        .collection('estimates')
                                        .doc(widget.estimateId)
                                        .update({
                                      'furnitureList': updatedList,
                                    });

                                    // 캐시된 데이터 업데이트 (스크롤 위치 유지)
                                    if (_cachedData != null) {
                                      (_cachedData!['estimate'] as Map<String,
                                              dynamic>)['furnitureList'] =
                                          updatedList;
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 입고예정일
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Colors.transparent,
                                        onPrimary: Colors.white,
                                        onSurface: AppColor.font1,
                                        surface: Colors.white,
                                        brightness: Brightness.light,
                                      ),
                                      dialogBackgroundColor: Colors.white,
                                      scaffoldBackgroundColor: Colors.white,
                                      canvasColor: Colors.white,
                                      cardColor: Colors.white,
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColor.primary,
                                        ),
                                      ),
                                      datePickerTheme: DatePickerThemeData(
                                        dayStyle: const TextStyle(fontSize: 14),
                                        yearStyle:
                                            const TextStyle(fontSize: 14),
                                        todayBorder: const BorderSide(
                                            color: AppColor.primary, width: 1),
                                        todayBackgroundColor:
                                            MaterialStateProperty.all(
                                                Colors.transparent),
                                        todayForegroundColor:
                                            MaterialStateProperty.all(
                                                AppColor.primary),
                                        dayBackgroundColor:
                                            MaterialStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return AppColor.primary;
                                          }
                                          if (states.contains(
                                              MaterialState.hovered)) {
                                            return Colors.transparent;
                                          }
                                          return Colors.transparent;
                                        }),
                                        dayForegroundColor:
                                            MaterialStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return Colors.white;
                                          }
                                          return Colors.black;
                                        }),
                                        yearBackgroundColor:
                                            MaterialStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return AppColor.primary;
                                          }
                                          if (states.contains(
                                              MaterialState.hovered)) {
                                            return Colors.transparent;
                                          }
                                          return Colors.transparent;
                                        }),
                                        yearForegroundColor:
                                            MaterialStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return Colors.white;
                                          }
                                          return Colors.black;
                                        }),
                                        headerForegroundColor: Colors.black,
                                        weekdayStyle: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                final updatedList =
                                    List<Map<String, dynamic>>.from(
                                        furnitureList);
                                updatedList[index] = {
                                  ...updatedList[index],
                                  'expectedDate': Timestamp.fromDate(picked),
                                };

                                await FirebaseFirestore.instance
                                    .collection('estimates')
                                    .doc(widget.estimateId)
                                    .update({
                                  'furnitureList': updatedList,
                                });

                                if (_cachedData != null) {
                                  (_cachedData!['estimate'] as Map<String,
                                      dynamic>)['furnitureList'] = updatedList;
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              }
                            },
                            child: Text(
                              furniture['expectedDate'] != null
                                  ? _formatDate(furniture['expectedDate'])
                                  : '날짜 선택',
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

// 유틸리티 함수들
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      color: AppColor.line1,
    );
  }

  Widget _buildTableHeader(String text, int flex,
      {TextAlign textAlign = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(16),
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }

  Future<void> _saveOrderStatus() async {
    try {
      // 캐시된 데이터에서 최신 가구 목록 가져오기
      if (_cachedData == null) {
        throw Exception('데이터를 찾을 수 없습니다');
      }

      final furnitureList = (_cachedData!['estimate']
          as Map<String, dynamic>)['furnitureList'] as List<dynamic>?;

      if (furnitureList == null) {
        throw Exception('가구 목록을 찾을 수 없습니다');
      }

      // Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .update({
        'furnitureList': furnitureList,
        'orderMemo': _memoController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 캐시 업데이트 (저장 후 자동 반영)
      if (_cachedData != null) {
        (_cachedData!['estimate'] as Map<String, dynamic>)['furnitureList'] =
            furnitureList;
        (_cachedData!['estimate'] as Map<String, dynamic>)['orderMemo'] =
            _memoController.text;

        if (mounted) {
          setState(() {});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
      }
    } catch (e) {
      print('Error saving order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _buildTableCell(String text, int flex,
      {bool isHeader = false, TextAlign textAlign = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(16),
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  int _calculateTotal(List<dynamic> furnitureList) {
    return furnitureList.fold(0, (total, furniture) {
      return total +
          ((furniture['quantity'] as int?) ?? 0) *
              ((furniture['price'] as int?) ?? 0);
    });
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    }
    return '';
  }

  Future<void> generatePDF(Map<String, dynamic> data) async {
    try {
      final regularFont = await rootBundle.load(
          'assets/fonts/notosans/Noto_Sans_KR/static/NotoSansKR-Regular.ttf');
      final boldFont = await rootBundle.load(
          'assets/fonts/notosans/Noto_Sans_KR/static/NotoSansKR-Bold.ttf');

      final ttf = pw.Font.ttf(regularFont);
      final ttfBold = pw.Font.ttf(boldFont);

      final pdf = pw.Document();

      // 넓은 페이지 크기 설정 (A4 너비의 두 배, 높이는 자동)
      final pageFormat = PdfPageFormat(
        PdfPageFormat.a4.width * 1.5, // 너비를 1.5배로
        PdfPageFormat.a4.height * 2, // 높이를 2배로 (필요에 따라 조정)
        marginAll: 40,
      );

      // 페이지 분리 여부 결정을 위한 높이 계산
      final estimate = data['estimate'] as Map<String, dynamic>;
      final furnitureList = (estimate['furnitureList'] as List<dynamic>?) ?? [];
      final memo = data['memo'];
      final hasMemo = memo != null && memo.toString().isNotEmpty;

      // 첫 페이지 높이: 제목(24) + 여백(32) + 견적 정보 섹션
      const titleHeight = 24 + 32;
      const estimateSectionHeaderHeight =
          18 + 12 + 2 + 16; // 제목 + 여백 + 구분선 + 여백
      const estimateTableHeaderHeight = 50;
      const estimateRowHeight = 50;
      final estimateTableHeight = estimateTableHeaderHeight +
          (furnitureList.length * estimateRowHeight);
      final estimateSectionHeight =
          estimateSectionHeaderHeight + estimateTableHeight;
      final firstPageHeight = titleHeight + estimateSectionHeight;

      // 두 번째 페이지 높이: 여백(48) + 발주 정보 + 여백(48) + 메모(있는 경우) + 담당자 정보
      const orderSectionHeaderHeight = 18 + 12 + 2 + 24; // 제목 + 여백 + 구분선 + 여백
      const orderTableHeaderHeight = 50;
      const orderRowHeight = 50;
      final orderTableHeight =
          orderTableHeaderHeight + (furnitureList.length * orderRowHeight);
      final orderSectionHeight = orderSectionHeaderHeight + orderTableHeight;
      final memoHeight = hasMemo ? 150 : 0; // 메모 섹션 높이 추정
      const managerSectionHeight = 150; // 담당자 정보 섹션 높이 추정
      final secondPageHeight = 48 +
          orderSectionHeight +
          48 +
          (hasMemo ? memoHeight + 48 : 0) +
          managerSectionHeight;

      // 전체 높이 계산
      final totalHeight = firstPageHeight + secondPageHeight;
      final availablePageHeight = pageFormat.availableHeight;
      final shouldSplit =
          totalHeight > availablePageHeight * 0.9; // 90% 이상이면 분리

      // 첫 번째 페이지: 견적 정보
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 제목
                pw.Text(
                  '발주서',
                  style: pw.TextStyle(fontSize: 24, font: ttfBold),
                ),
                pw.SizedBox(height: 32),
                // 견적 정보
                _buildPDFEstimateSection(data['estimate'], ttf, ttfBold),
                // 페이지가 충분히 크면 두 번째 페이지 내용도 함께 표시
                if (!shouldSplit) ...[
                  pw.SizedBox(height: 48),
                  _buildPDFOrderSection(
                      data['estimate'], furnitureList, ttf, ttfBold),
                  pw.SizedBox(height: 48),
                  if (hasMemo) _buildPDFMemoSection(memo, ttf, ttfBold),
                  if (hasMemo) pw.SizedBox(height: 48),
                  _buildPDFManagerSection(data['userData'], ttf, ttfBold),
                ],
              ],
            );
          },
        ),
      );

      // 페이지가 충분히 크지 않으면 두 번째 페이지로 분리
      if (shouldSplit) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              return _buildPDFSecondPage(data, ttf, ttfBold);
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..style.display = 'none'
        ..download = _generateFileName(data);
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print('Error generating PDF: $e');
    }
  }

  pw.Widget _buildPDFFirstPage(
      Map<String, dynamic> data, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 제목
        pw.Text(
          '발주서',
          style: pw.TextStyle(fontSize: 24, font: ttfBold),
        ),
        pw.SizedBox(height: 32),

        // 견적 정보만
        _buildPDFEstimateSection(data['estimate'], ttf, ttfBold),
      ],
    );
  }

  pw.Widget _buildPDFSecondPage(
      Map<String, dynamic> data, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 48),
        _buildPDFOrderSection(
            data['estimate'],
            (data['estimate']['furnitureList'] as List<dynamic>?) ?? [],
            ttf,
            ttfBold),
        pw.SizedBox(height: 48),

        // 메모 섹션 추가
        if (data['memo'] != null && data['memo'].toString().isNotEmpty)
          _buildPDFMemoSection(data['memo'], ttf, ttfBold),

        if (data['memo'] != null && data['memo'].toString().isNotEmpty)
          pw.SizedBox(height: 48),

        _buildPDFManagerSection(data['userData'], ttf, ttfBold),
      ],
    );
  }

  String _generateFileName(Map<String, dynamic> data) {
    // 현재 날짜 가져오기
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // 고객 정보 가져오기
    final customer = data['customer'] as Customer;
    final customerName = customer.name.replaceAll(' ', '_'); // 공백을 언더스코어로 변경

    // 발주번호나 견적번호가 있다면 사용
    final estimateId =
        customer.estimateIds.isNotEmpty ? customer.estimateIds[0] : '';
    final shortEstimateId =
        estimateId.length > 8 ? estimateId.substring(0, 8) : estimateId;

    // 파일명 생성
    return '발주서_${customerName}_${dateStr}_$shortEstimateId.pdf';
  }

// PDF 헤더 위젯
  pw.Widget _buildPDFHeader(pw.Font ttfBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
          style: pw.TextStyle(
            fontSize: 18,
            font: ttfBold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFOrderSection(Map<String, dynamic> estimate,
      List<dynamic> furnitureList, pw.Font ttf, pw.Font ttfBold) {
    // furnitureList가 비어있으면 빈 섹션 반환
    if (furnitureList.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        pw.Text(
          '발주 정보',
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),

        // 구분선
        pw.Container(
          width: double.infinity,
          height: 2,
        ),
        pw.SizedBox(height: 24),

        // 테이블 컨테이너
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Column(
            children: [
              // 테이블 헤더
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('제품명',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.left)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(),
                        ),
                      ),
                    ),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('발주상태',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(),
                        ),
                      ),
                    ),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('입고상태',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(),
                        ),
                      ),
                    ),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('입고예정일',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                  ],
                ),
              ),

              // 테이블 내용
              ...furnitureList
                  .map((furniture) => pw.Container(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(),
                          ),
                        ),
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                furniture['name'] ?? '',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.left,
                              ),
                            ),
                            pw.Container(
                              width: 1,
                              height: 20,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  left: pw.BorderSide(),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                furniture['orderStatus'] ?? '발주 신청',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Container(
                              width: 1,
                              height: 20,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  left: pw.BorderSide(),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                furniture['receivingStatus'] ?? '미입고',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Container(
                              width: 1,
                              height: 20,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  left: pw.BorderSide(),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                furniture['expectedDate'] != null
                                    ? _formatDate(furniture['expectedDate'])
                                    : '-',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
        ),

        // 참고 사항 (옵션)
        if (estimate['orderNotes'] != null &&
            estimate['orderNotes'].toString().isNotEmpty)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '참고사항',
                  style: pw.TextStyle(font: ttfBold, fontSize: 14),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  estimate['orderNotes'].toString(),
                  style: pw.TextStyle(font: ttf, fontSize: 12),
                ),
              ],
            ),
          ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 메모 헤더
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: pw.Text(
                  '메모',
                  style: pw.TextStyle(font: ttfBold, fontSize: 14),
                ),
              ),
              // 메모 내용
              pw.Container(
                width: double.infinity,
                constraints: const pw.BoxConstraints(minHeight: 100),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Text(
                  _memoController.text.isEmpty ? '메모 없음' : _memoController.text,
                  style: pw.TextStyle(font: ttf, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// PDF 고객 정보 섹션
  pw.Widget _buildPDFCustomerSection(
      Customer customer, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '고객 정보',
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          height: 2,
        ),
        pw.SizedBox(height: 24),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(children: [
                _buildPDFInfoCell('고객명', customer.name, ttf),
                _buildPDFInfoCell('연락처', customer.phone, ttf),
              ]),
              pw.TableRow(children: [
                _buildPDFInfoCell('이메일주소', customer.email, ttf),
                _buildPDFInfoCell('배송지주소', customer.address, ttf,
                    isAddress: true),
              ]),
              pw.TableRow(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 120,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                        child: pw.Text(
                          '사업자등록증',
                          style: pw.TextStyle(fontSize: 14, font: ttf),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Text(
                            customer.businessLicenseUrl.isEmpty
                                ? '미첨부'
                                : getFileName(customer.businessLicenseUrl),
                            style: pw.TextStyle(fontSize: 14, font: ttf),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 120,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                        child: pw.Text(
                          '기타서류',
                          style: pw.TextStyle(fontSize: 14, font: ttf),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Text(
                            customer.otherDocumentUrls.isEmpty
                                ? '미첨부'
                                : getFileName(customer.otherDocumentUrls.first),
                            style: pw.TextStyle(fontSize: 14, font: ttf),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

// PDF 공간 정보 섹션
  pw.Widget _buildPDFSpaceSection(
      Map<String, dynamic> estimate, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '공간 정보',
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          height: 2,
        ),
        pw.SizedBox(height: 24),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(children: [
                _buildPDFInfoCell('현장주소', estimate['siteAddress'] ?? '', ttf,
                    isAddress: true),
                _buildPDFInfoCell(
                    '공간오픈일정', _formatDate(estimate['openingDate']), ttf),
              ]),
              pw.TableRow(children: [
                _buildPDFInfoCell(
                    '예산',
                    '${estimate['minBudget']?.toString() ?? '0'} ~ ${estimate['maxBudget']?.toString() ?? '0'}원',
                    ttf),
                _buildPDFInfoCell('공간면적',
                    '${estimate['spaceArea']?.toString() ?? '0'} ㎡', ttf),
              ]),
              pw.TableRow(children: [
                _buildPDFInfoCell('업종', estimate['businessType'] ?? '', ttf),
                _buildPDFInfoCell(
                    '공간컨셉',
                    (estimate['concept'] as List<dynamic>?)?.join(', ') ?? '',
                    ttf),
              ]),
              pw.TableRow(children: [
                _buildPDFInfoCell('수령자', estimate['recipient'] ?? '', ttf),
                _buildPDFInfoCell('연락처', estimate['contactNumber'] ?? '', ttf),
              ]),
              pw.TableRow(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 120,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                        child: pw.Text(
                          '배송방법',
                          style: pw.TextStyle(fontSize: 14, font: ttf),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Text(
                            estimate['shippingMethod'] ?? '',
                            style: pw.TextStyle(fontSize: 14, font: ttf),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 120,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                        child: pw.Text(
                          '결제방법',
                          style: pw.TextStyle(fontSize: 14, font: ttf),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Text(
                            estimate['paymentMethod'] ?? '',
                            style: pw.TextStyle(fontSize: 14, font: ttf),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

// PDF 메모 섹션
  pw.Widget _buildPDFMemoSection(String memo, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        pw.Text(
          '메모',
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),

        // 구분선
        pw.Container(
          width: double.infinity,
          height: 2,
        ),
        pw.SizedBox(height: 24),

        // 메모 내용
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Text(
            memo,
            style: pw.TextStyle(
              fontSize: 14,
              font: ttf,
            ),
          ),
        ),
      ],
    );
  }

// PDF 담당자 정보 섹션
  pw.Widget _buildPDFManagerSection(
      Map<String, dynamic>? userData, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        pw.Text(
          '담당자 정보',
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),

        // 구분선
        pw.Container(
          width: double.infinity,
          height: 2,
        ),
        pw.SizedBox(height: 24),

        // 담당자 정보 테이블
        pw.Row(
          children: [
            // 담당자 성함
            pw.Expanded(
              child: pw.Container(
                height: 48,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 120,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: pw.Text(
                        '담당자 성함',
                        style: pw.TextStyle(
                          fontSize: 14,
                          font: ttf,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                        child: pw.Text(
                          userData?['name'] ?? '',
                          style: pw.TextStyle(
                            fontSize: 14,
                            font: ttf,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 24),
            // 연락처
            pw.Expanded(
              child: pw.Container(
                height: 48,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 120,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: pw.Text(
                        '연락처',
                        style: pw.TextStyle(
                          fontSize: 14,
                          font: ttf,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                        child: pw.Text(
                          userData?['phoneNumber'] ?? '',
                          style: pw.TextStyle(
                            fontSize: 14,
                            font: ttf,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

// PDF용 정보 셀 위젯
  pw.Widget _buildPDFInfoCell(String label, String value, pw.Font ttf,
      {bool isAddress = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 14, font: ttf),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 14, font: ttf),
              ),
            ),
          ),
        ],
      ),
      height: isAddress ? 72 : null,
    );
  }

// PDF용 전체 너비 셀 위젯
  pw.Widget _buildPDFFullWidthCell(String label, String value, pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 14, font: ttf),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 14, font: ttf),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getFileName(String url) {
    try {
      String fileName = url.split('/').last;
      fileName = Uri.decodeFull(fileName);
      fileName = fileName.split('?').first;
      return fileName;
    } catch (e) {
      return url;
    }
  }

  pw.Widget _buildPDFSection(
      String title, List<pw.Widget> content, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 2),
            ),
          ),
        ),
        pw.SizedBox(height: 24),
        ...content,
      ],
    );
  }

  pw.Widget _buildPDFInfoRow(String label, String value, pw.Font ttf) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(),
        ),
      ),
      height: 48,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 120,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 14, font: ttf),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 14, font: ttf),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFEstimateSection(
      Map<String, dynamic> estimate, pw.Font ttf, pw.Font ttfBold) {
    final furnitureList = (estimate['furnitureList'] as List<dynamic>?) ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '견적 정보',
          style: pw.TextStyle(fontSize: 18, font: ttfBold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 2),
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Column(
            children: [
              // 테이블 헤더 - 구분선 추가
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(),
                  ),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 4,
                        child:
                            pw.Text('상품명', style: pw.TextStyle(font: ttfBold))),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(),
                    ),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('규격',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(),
                    ),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('단가',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(),
                    ),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text('수량',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: const pw.BoxDecoration(),
                    ),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('금액',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                  ],
                ),
              ),
              // 테이블 내용 - 모든 행에 구분선 추가
              ...furnitureList.map((furniture) => pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(),
                      ),
                    ),
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                            flex: 4,
                            child: pw.Text(furniture['name'] ?? '',
                                style: pw.TextStyle(font: ttf))),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: const pw.BoxDecoration(),
                        ),
                        pw.Expanded(
                            flex: 3,
                            child: pw.Text(furniture['specification'] ?? '',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: const pw.BoxDecoration(),
                        ),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                                '${_formatNumber(furniture['price'])}원',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: const pw.BoxDecoration(),
                        ),
                        pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                                furniture['quantity']?.toString() ?? '',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: const pw.BoxDecoration(),
                        ),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                                '${_formatNumber((furniture['price'] ?? 0) * (furniture['quantity'] ?? 0))}원',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                      ],
                    ),
                  )),
              // 총금액 행
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 2),
                  ),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '총 합계',
                      style: pw.TextStyle(font: ttfBold, fontSize: 14),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Text(
                      '${_formatNumber(_calculateTotal(furnitureList))}원',
                      style: pw.TextStyle(fontSize: 14, font: ttfBold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // PDF 테이블 셀 생성 헬퍼 함수
  pw.Widget _buildPDFTableCell(String text, {bool header = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: header ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    final customers = ref.watch(customerDataProvider);

    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사이드바
            Container(
              width: 240,
              height: MediaQuery.of(context).size.height,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColor.line1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  InkWell(
                    onTap: () => context.go('/main'),
                    child: SizedBox(
                      width: 137,
                      height: 17,
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),
                  const SizedBox(height: 56),
                  userData.when(
                    data: (data) {
                      if (data != null) {
                        return Column(
                          children: [
                            Text(
                              UserProvider.getUserName(data),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1,
                              ),
                            ),
                          ],
                        );
                      }
                      return const Text('사용자 정보를 불러올 수 없습니다.');
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => Text('오류: $error'),
                  ),
                  const SizedBox(height: 40),
                  // 메뉴 버튼들
                  InkWell(
                    onTap: () => context.go('/main'),
                    child: Container(
                        width: 200,
                        height: 48,
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 17.87,
                            ),
                            SizedBox(
                                width: 16.25,
                                height: 16.25,
                                child: Image.asset(
                                  'assets/images/user.png',
                                  color: AppColor.font1,
                                )),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '담당 고객정보',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1,
                                  fontSize: 16),
                            ),
                          ],
                        )),
                  ),
                  InkWell(
                    onTap: () => context.go('/all-customers'),
                    child: Container(
                        width: 200,
                        height: 48,
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 17.87,
                            ),
                            SizedBox(
                                width: 16.25,
                                height: 16.25,
                                child: Image.asset('assets/images/group.png')),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '전체 고객정보',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1,
                                  fontSize: 16),
                            ),
                          ],
                        )),
                  ),

                  const SizedBox(
                    height: 48,
                  ),
                  InkWell(
                    onTap: () => context.go('/temp'),
                    child: Container(
                        width: 200,
                        height: 48,
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 17.87,
                            ),
                            SizedBox(
                                width: 16.25,
                                height: 16.25,
                                child: Image.asset('assets/images/draft.png')),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '임시저장',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1,
                                  fontSize: 16),
                            ),
                          ],
                        )),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: InkWell(
                      onTap: _handleLogout,
                      child: Container(
                        width: 200,
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout,
                                color: Colors.red.shade300, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '로그아웃',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 메인 컨텐츠
// 테이블 영역 부분만 수정
// 메인 컨텐츠 영역
            Expanded(
              child: Screenshot(
                controller: screenshotController,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(24.0),
                      child: _isLoading || _cachedData == null
                          ? const Center(child: CircularProgressIndicator())
                          : _buildContent(_cachedData!),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                context.pop();
              },
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios),
                  SizedBox(width: 4),
                  Text(
                    '이전',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        const Text(
          '발주서',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColor.font1,
          ),
        ),
        const SizedBox(height: 32),
        _buildEstimateSection(data),
        const SizedBox(height: 48),
        _buildOrderSection(data),
        const SizedBox(height: 24),

        // 메모 섹션
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메모 헤더
              Container(
                width: double.infinity,
                color: AppColor.back2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: const Text(
                  '메모',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              // 메모 입력 영역
              Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _memoController,
                  maxLines: null,
                  minLines: 10,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '메모를 입력하세요...',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),
        _buildManagerSection(data),
        const SizedBox(height: 48),
        Row(
          children: [
            InkWell(
              onTap: () {
                _saveOrderStatus();
              },
              child: Container(
                height: 48,
                width: 87,
                color: AppColor.main,
                child: const Center(
                  child: Text(
                    '저장하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                // 캐시된 데이터를 사용하여 PDF 생성
                if (_cachedData != null) {
                  final dataForPDF = Map<String, dynamic>.from(_cachedData!);
                  dataForPDF['memo'] = _memoController.text;
                  generatePDF(dataForPDF);
                }
              },
              child: Container(
                height: 48,
                width: 131,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: AppColor.line1, width: 1),
                ),
                child: const Center(
                  child: Text(
                    '발주서 다운로드',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
