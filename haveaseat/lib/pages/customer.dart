import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:haveaseat/riverpod/customermodel.dart' as model;
import 'dart:async';

enum EstimateStatus {
  IN_PROGRESS, // 견적중
  CONTRACTED, // 계약완료
  CANCELED // 취소됨
}

enum CustomerStatus {
  ESTIMATE_IN_PROGRESS('견적진행중'),
  ESTIMATE_COMPLETE('견적완료'),
  CONTRACT_COMPLETE('계약완료'),
  ORDER_START('발주시작'),
  RECEIVING('입고'),
  INSPECTION('검수'),
  DELIVERY('납품'),
  REVIEW('후기'),
  COMPLETE('완료');

  final String label;
  const CustomerStatus(this.label);
}

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  Timer? _debounceTimer;
  final Set<String> _selectedCustomers = {};
  static const double CHECKBOX_WIDTH = 56;

// 고객 테이블용 기존 상수들 (그대로 유지)
  static const double CUSTOMER_NAME_RATIO = 0.08;
  static const double STATUS_RATIO = 0.08;
  static const double PHONE_RATIO = 0.1;
  static const double EMAIL_RATIO = 0.15;
  static const double ADDRESS_RATIO = 0.2;
  static const double LICENSE_RATIO = 0.09;
  static const double BUDGET_RATIO = 0.1;
  static const double NOTE_RATIO = 0.1;

// 견적 테이블용 새로운 상수들 (추가)
  static const double ESTIMATE_STATUS_RATIO = 0.07;
  static const double ESTIMATE_TYPE_RATIO = 0.07;
  static const double ESTIMATE_PRODUCT_RATIO = 0.11;
  static const double ESTIMATE_DATE_RATIO = 0.09;
  static const double ESTIMATE_AMOUNT_RATIO = 0.09;
  static const double ESTIMATE_ADDRESS_RATIO = 0.14;
  static const double ESTIMATE_DOC_RATIO = 0.06;
  static const double ESTIMATE_MANAGER_RATIO = 0.07;
  static const double ESTIMATE_NOTE_RATIO = 0.07;
  Widget buildEstimateTableHeaderWithData(
      double totalWidth, List<Map<String, dynamic>> estimates) {
    // 체크박스를 제외한 사용 가능한 너비 계산
    final availableWidth = totalWidth - CHECKBOX_WIDTH;

    return Container(
      width: totalWidth,
      height: 48,
      color: const Color(0xffF7F7FB),
      child: Row(
        children: [
          SizedBox(
            width: CHECKBOX_WIDTH,
            child: Checkbox(
              value: _allEstimatesCheck,
              onChanged: (checked) =>
                  _toggleAllEstimatesCheck(checked, estimates),
            ),
          ),
          buildHeaderCell('상태', availableWidth * ESTIMATE_STATUS_RATIO),
          buildHeaderCell('종류', availableWidth * ESTIMATE_TYPE_RATIO),
          buildHeaderCell('상품명', availableWidth * ESTIMATE_PRODUCT_RATIO),
          buildHeaderCell('주문일자', availableWidth * ESTIMATE_DATE_RATIO),
          buildHeaderCell('금액', availableWidth * ESTIMATE_AMOUNT_RATIO),
          buildHeaderCell('수령지', availableWidth * ESTIMATE_ADDRESS_RATIO),
          buildHeaderCell('견적서', availableWidth * ESTIMATE_DOC_RATIO),
          buildHeaderCell('발주서', availableWidth * ESTIMATE_DOC_RATIO),
          buildHeaderCell('출고증', availableWidth * ESTIMATE_DOC_RATIO),
          buildHeaderCell('담당자명', availableWidth * ESTIMATE_MANAGER_RATIO),
          buildHeaderCell('기타', availableWidth * ESTIMATE_NOTE_RATIO),
        ],
      ),
    );
  }

  bool _allCheck = false;
  static const List<String> statusOptions = [
    '견적진행중',
    '견적완료',
    '계약완료',
    '발주시작',
    '입고',
    '검수',
    '납품',
    '후기',
    '완료'
  ];
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

  String getCustomerStatus(String? status) {
    return status ?? statusOptions[0];
  }

  void _toggleAllCheck(bool? checked, List<Customer> customers) {
    setState(() {
      _allCheck = checked ?? false;
      if (_allCheck) {
        _selectedCustomers.addAll(customers.map((c) => c.id));
      } else {
        _selectedCustomers.clear();
      }
    });
  }

  void _toggleCustomerCheck(bool? checked, String customerId) {
    setState(() {
      if (checked ?? false) {
        _selectedCustomers.add(customerId);
      } else {
        _selectedCustomers.remove(customerId);
      }
    });
  }

  Future<void> _deleteSelectedCustomers() async {
    try {
      if (_selectedCustomers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제할 고객을 선택해주세요')),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('고객 삭제'),
          content: Text('선택한 ${_selectedCustomers.length}명의 고객을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await Future.wait(
        _selectedCustomers.map((customerId) async {
          try {
            final customer = await ref
                .read(customerDataProvider.notifier)
                .getCustomer(customerId);

            if (customer != null) {
              if (customer.businessLicenseUrl.isNotEmpty) {
                try {
                  final storageRef = FirebaseStorage.instance
                      .refFromURL(customer.businessLicenseUrl);
                  await storageRef.delete();
                } catch (e) {
                  print('Failed to delete business license: $e');
                }
              }

              for (final url in customer.otherDocumentUrls) {
                try {
                  final storageRef = FirebaseStorage.instance.refFromURL(url);
                  await storageRef.delete();
                } catch (e) {
                  print('Failed to delete other document: $e');
                }
              }

              await ref
                  .read(customerDataProvider.notifier)
                  .deleteCustomer(customerId);
            }
          } catch (e) {
            print('Error processing customer $customerId: $e');
          }
        }),
      );

      setState(() {
        _selectedCustomers.clear();
        _allCheck = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 고객이 삭제되었습니다')),
        );
      }
    } catch (e) {
      print('Error in _deleteSelectedCustomers: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('고객 삭제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Widget buildDataCell(String text, double width,
      {bool isClickable = false, VoidCallback? onTap}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4), // 패딩 축소
      child: isClickable
          ? InkWell(
              onTap: onTap,
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 12, // 폰트 크기 축소
                    color: AppColor.primary,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              text,
              style: const TextStyle(
                fontSize: 12, // 폰트 크기 축소
                color: AppColor.font1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

// 1. 견적 체크박스 관련 변수 추가 (클래스 내부 변수로)
  final Set<String> _selectedEstimates = {}; // 견적 선택용
  bool _allEstimatesCheck = false; // 전체 견적 선택

// 2. 견적 체크박스 토글 함수들 추가
  void _toggleAllEstimatesCheck(
      bool? checked, List<Map<String, dynamic>> estimates) {
    setState(() {
      _allEstimatesCheck = checked ?? false;
      if (_allEstimatesCheck) {
        _selectedEstimates
            .addAll(estimates.map((e) => e['estimateId'] as String));
      } else {
        _selectedEstimates.clear();
      }
    });
  }

  void _toggleEstimateCheck(bool? checked, String estimateId) {
    setState(() {
      if (checked ?? false) {
        _selectedEstimates.add(estimateId);
      } else {
        _selectedEstimates.remove(estimateId);
      }
    });
  }

// 3. 선택된 견적 삭제 함수
  Future<void> _deleteSelectedEstimates() async {
    try {
      if (_selectedEstimates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제할 견적을 선택해주세요')),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('견적 삭제'),
          content: Text('선택한 ${_selectedEstimates.length}개의 견적을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await Future.wait(
        _selectedEstimates.map((estimateId) async {
          try {
            await FirebaseFirestore.instance
                .collection('estimates')
                .doc(estimateId)
                .delete();

            // 고객 문서에서 견적 ID 제거
            await FirebaseFirestore.instance
                .collection('customers')
                .doc(widget.customerId)
                .update({
              'estimateIds': FieldValue.arrayRemove([estimateId]),
            });
          } catch (e) {
            print('Error deleting estimate $estimateId: $e');
          }
        }),
      );

      setState(() {
        _selectedEstimates.clear();
        _allEstimatesCheck = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 견적이 삭제되었습니다')),
        );
      }
    } catch (e) {
      print('Error in _deleteSelectedEstimates: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적 삭제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Future<void> _addNewEstimateToExistingCustomer() async {
    try {
      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null) throw Exception('고객 정보를 찾을 수 없습니다');

      final now = DateTime.now();
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc();

      // 직접 Firestore에 저장할 데이터 생성 (Timestamp 형식으로)
      final estimateData = {
        'customerId': widget.customerId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'managerName': '',
        'managerPhone': '',
        // 공간 기본 정보
        'siteAddress': '',
        'openingDate': FieldValue.serverTimestamp(),
        'recipient': '',
        'contactNumber': '',
        'shippingMethod': '',
        'paymentMethod': '',
        'basicNotes': '',
        // 공간 상세 정보
        'minBudget': 0,
        'maxBudget': 0,
        'spaceArea': 0,
        'targetAgeGroups': [],
        'businessType': '',
        'concept': [],
        'spaceUnit': '평',
        'detailNotes': '',
        'designFileUrls': [],
        // 가구 정보
        'furnitureList': [],
        // 메모 추가
        'memo': '',
      };

      // Firestore에 견적 저장
      await estimateRef.set(estimateData);

      // 고객 문서에 견적 ID 추가
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .update({
        'estimateIds': FieldValue.arrayUnion([estimateRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로운 견적이 추가되었습니다')),
        );

        // 새로 생성된 견적을 새로 생성 플로우로 이동
        context.go(
            '/main/addpage/spaceadd/${widget.customerId}/${estimateRef.id}',
            extra: {'name': customer.name});
      }
    } catch (e) {
      print('Error adding new estimate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적 추가 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Widget buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4), // 패딩 축소
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12, // 폰트 크기 축소
          fontWeight: FontWeight.w600,
          color: AppColor.font1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    }
    return '';
  }

  // 숫자 포맷팅 함수 (천 단위 구분자 추가)
  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // 견적 필터링 함수
  List<Map<String, dynamic>> _filterEstimates(
      List<Map<String, dynamic>> estimates) {
    // 검색어나 날짜 필터가 없으면 전체 반환
    if (_searchController.text.isEmpty &&
        _startDate == null &&
        _endDate == null) {
      return estimates;
    }

    return estimates.where((estimate) {
      // 검색어 필터링
      if (_searchController.text.isNotEmpty) {
        String searchTerm = _searchController.text.toLowerCase();

        // 견적 데이터에서 검색할 필드들 정의
        String status = estimate['status']?.toString().toLowerCase() ?? '';
        String productName =
            estimate['productName']?.toString().toLowerCase() ?? '';
        String deliveryAddress =
            estimate['deliveryAddress']?.toString().toLowerCase() ?? '';
        String managerName =
            estimate['managerName']?.toString().toLowerCase() ?? '';
        String note = estimate['note']?.toString().toLowerCase() ?? '';
        String amount = estimate['amount']?.toString().toLowerCase() ?? '';

        // 검색어가 포함된 필드가 있는지 확인
        bool matchesSearch = status.contains(searchTerm) ||
            productName.contains(searchTerm) ||
            deliveryAddress.contains(searchTerm) ||
            managerName.contains(searchTerm) ||
            note.contains(searchTerm) ||
            amount.contains(searchTerm);

        if (!matchesSearch) return false;
      }

      // 날짜 필터링
      if (_startDate != null || _endDate != null) {
        DateTime? estimateDate;

        // orderDate 필드에서 날짜 추출
        if (estimate['orderDate'] != null) {
          if (estimate['orderDate'] is Timestamp) {
            estimateDate = (estimate['orderDate'] as Timestamp).toDate();
          } else if (estimate['orderDate'] is DateTime) {
            estimateDate = estimate['orderDate'] as DateTime;
          }
        }

        if (estimateDate != null) {
          if (_startDate != null && estimateDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null &&
              estimateDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  // 견적 테이블 헤더
  Widget buildEstimateTableHeader(double totalWidth) {
    return Container(
      width: totalWidth,
      height: 48,
      color: const Color(0xffF7F7FB),
      child: Row(
        children: [
          buildHeaderCell('상태', totalWidth * 0.08),
          buildHeaderCell('종류', totalWidth * 0.08),
          buildHeaderCell('상품명', totalWidth * 0.12),
          buildHeaderCell('주문일자', totalWidth * 0.1),
          buildHeaderCell('금액', totalWidth * 0.1),
          buildHeaderCell('수령지', totalWidth * 0.15),
          buildHeaderCell('견적서', totalWidth * 0.07),
          buildHeaderCell('발주서', totalWidth * 0.07),
          buildHeaderCell('출고증', totalWidth * 0.07),
          buildHeaderCell('담당자명', totalWidth * 0.08),
          buildHeaderCell('기타', totalWidth * 0.08),
        ],
      ),
    );
  }

  Widget buildEstimateRow(Map<String, dynamic> estimate, double totalWidth) {
    // 체크박스를 제외한 사용 가능한 너비 계산
    final availableWidth = totalWidth - CHECKBOX_WIDTH;

    // 가구 종류 결정 (기존가구 vs 제작가구)
    String furnitureType = '기존가구'; // 기본값
    final furnitureList = estimate['furnitureList'] as List<dynamic>? ?? [];

    if (furnitureList.isNotEmpty) {
      // 제작가구가 하나라도 있으면 "제작가구"로 표시
      bool hasCustomFurniture =
          furnitureList.any((furniture) => furniture['isCustom'] == true);

      if (hasCustomFurniture) {
        // 기존가구와 제작가구가 혼재되어 있는지 확인
        bool hasExistingFurniture = furnitureList.any((furniture) =>
            furniture['isCustom'] == false || furniture['isCustom'] == null);

        if (hasExistingFurniture) {
          furnitureType = '혼합'; // 기존가구와 제작가구가 모두 있는 경우
        } else {
          furnitureType = '제작가구'; // 제작가구만 있는 경우
        }
      } else {
        furnitureType = '기존가구'; // 기존가구만 있는 경우
      }
    }

    return Container(
      width: totalWidth,
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.line1)),
      ),
      child: Row(
        children: [
          // 체크박스
          SizedBox(
            width: CHECKBOX_WIDTH,
            child: Checkbox(
              value: _selectedEstimates.contains(estimate['estimateId']),
              onChanged: (value) =>
                  _toggleEstimateCheck(value, estimate['estimateId']),
            ),
          ),
          // 상태 드롭다운
          SizedBox(
            width: availableWidth * ESTIMATE_STATUS_RATIO,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: estimate['status'] ??
                      CustomerStatus.ESTIMATE_IN_PROGRESS.label,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                  style: const TextStyle(fontSize: 12, color: AppColor.font1),
                  items: CustomerStatus.values.map((status) {
                    return DropdownMenuItem<String>(
                      value: status.label,
                      child: Text(
                        status.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColor.font1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newStatus) async {
                    if (newStatus != null) {
                      final status = CustomerStatus.values.firstWhere(
                        (s) => s.label == newStatus,
                        orElse: () => CustomerStatus.ESTIMATE_IN_PROGRESS,
                      );
                      try {
                        await FirebaseFirestore.instance
                            .collection('estimates')
                            .doc(estimate['estimateId'])
                            .update({'status': status.name});
                        setState(() {
                          estimate['status'] = newStatus;
                        });

                        // Update customer status in Firestore
                        final customerId = widget.customerId;
                        await FirebaseFirestore.instance
                            .collection('customers')
                            .doc(customerId)
                            .update({'status': status.name});

                        // Refresh customer data provider
                        ref.refresh(customerDataProvider);
                      } catch (e) {
                        print('Error updating status: $e');
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          // 종류
          buildDataCell(furnitureType, availableWidth * ESTIMATE_TYPE_RATIO),
          // 상품명
          buildDataCell(estimate['productName'] ?? '',
              availableWidth * ESTIMATE_PRODUCT_RATIO),
          // 주문일자
          buildDataCell(_formatDate(estimate['orderDate']),
              availableWidth * ESTIMATE_DATE_RATIO),
          // 금액
          buildDataCell(
              '₩${NumberFormat('#,###').format(estimate['amount'] ?? 0)}',
              availableWidth * ESTIMATE_AMOUNT_RATIO),
          // 수령지
          buildDataCell(estimate['deliveryAddress'] ?? '',
              availableWidth * ESTIMATE_ADDRESS_RATIO),
          // 견적서 버튼
          Container(
            width: availableWidth * ESTIMATE_DOC_RATIO,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextButton(
              onPressed: () {
                context.go(
                    '/main/customer/${widget.customerId}/estimate/${estimate['estimateId']}');
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('상세보기',
                  style: TextStyle(fontSize: 11, color: AppColor.primary)),
            ),
          ),
          // 발주서 버튼
          Container(
            width: availableWidth * ESTIMATE_DOC_RATIO,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextButton(
              onPressed: () => context.go(
                  '/main/customer/${widget.customerId}/estimate/${estimate['estimateId']}/order'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('상세보기',
                  style: TextStyle(fontSize: 11, color: AppColor.primary)),
            ),
          ),
          // 출고증 버튼
          Container(
            width: availableWidth * ESTIMATE_DOC_RATIO,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextButton(
              onPressed: () => context.go(
                  '/main/customer/${widget.customerId}/estimate/${estimate['estimateId']}/release'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('상세보기',
                  style: TextStyle(fontSize: 11, color: AppColor.primary)),
            ),
          ),
          // 담당자명
          buildDataCell(estimate['managerName'] ?? '',
              availableWidth * ESTIMATE_MANAGER_RATIO),
          // 기타
          buildDataCell(
              estimate['note'] ?? '', availableWidth * ESTIMATE_NOTE_RATIO),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchEstimates(String customerId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('estimates')
          .where('customerId', isEqualTo: customerId)
          .get();

      List<Map<String, dynamic>> consolidatedEstimates = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // 임시저장된 견적은 제외 (isDraft가 true인 경우)
        if (data['isDraft'] == true) {
          continue;
        }

        final furnitureList = data['furnitureList'] as List<dynamic>? ?? [];

        // 가구 목록이 비어있어도 견적은 표시 (빈 견적도 보여줌)
        double totalAmount = 0;
        String productName = '';

        if (furnitureList.isNotEmpty) {
          // 총 금액 계산
          for (var furniture in furnitureList) {
            totalAmount +=
                (furniture['price'] ?? 0) * (furniture['quantity'] ?? 0);
          }

          // 상품명 표시 로직
          productName = furnitureList.length > 1
              ? '${furnitureList[0]['name']} 외 ${furnitureList.length - 1}건'
              : furnitureList[0]['name'];
        } else {
          productName = '견적 작성중';
        }

        Map<String, dynamic> estimate = {
          'estimateId': doc.id,
          'status': CustomerStatus.values
              .firstWhere(
                (e) => e.name == (data['status'] ?? ''),
                orElse: () => CustomerStatus.ESTIMATE_IN_PROGRESS,
              )
              .label,
          'type': data['type'] ?? '견적',
          'productName': productName,
          'orderDate': data['createdAt'] ?? Timestamp.now(),
          'amount': totalAmount,
          'deliveryAddress': data['siteAddress'] ?? '',
          'managerName': data['managerName'] ?? '',
          'note': data['detailNotes'] ?? '',
          'estimateDocId': doc.id,
          'orderId': '',
          'deliveryId': '',
          'furnitureList': furnitureList, // 가구 리스트 정보 추가
        };

        consolidatedEstimates.add(estimate);
      }
      return consolidatedEstimates;
    } catch (e) {
      print('Error fetching estimates: $e');
      return [];
    }
  }

  String _getProductNames(List<dynamic> furnitureList) {
    if (furnitureList.isEmpty) return '';
    return furnitureList.map((f) => '${f['name']}').join(', ');
  }

  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showStartDatePicker = false;
  bool _showEndDatePicker = false;
  List<Customer> _filterCustomers(List<Customer> customers) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // 먼저 담당 고객만 필터링 (managerId 대신 assignedTo 사용)
    final myCustomers = customers
        .where((customer) => customer.assignedTo == currentUserId)
        .where((customer) => customer.isDraft != true) // isDraft==false만 남김
        .toList();

    // 검색어나 날짜 필터가 없으면 담당 고객 전체 반환
    if (_searchController.text.isEmpty &&
        _startDate == null &&
        _endDate == null) {
      return myCustomers;
    }

    // 추가 필터 적용
    return myCustomers.where((customer) {
      // 검색어 필터링
      if (_searchController.text.isNotEmpty) {
        String searchTerm = _searchController.text.toLowerCase();
        bool matchesSearch = customer.name.toLowerCase().contains(searchTerm) ||
            customer.address.toLowerCase().contains(searchTerm) ||
            customer.note
                .toLowerCase()
                .contains(searchTerm); // spaceDetailInfo 대신 note 사용

        if (!matchesSearch) return false;
      }

      // 날짜 필터링
      if (_startDate != null || _endDate != null) {
        DateTime customerDate = customer.createdAt;
        if (_startDate != null && customerDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null &&
            customerDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // 날짜 선택 위젯
  Widget _buildDatePicker(bool isStartDate) {
    return Positioned(
      top: 48,
      left: isStartDate ? 0 : 204,
      child: Material(
        // Material 위젯 추가
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Container(
          width: 300,
          height: 400,
          padding: const EdgeInsets.all(12),
          child: Theme(
            // Theme 위젯 추가
            data: ThemeData.light(), // 라이트 테마 적용
            child: CalendarDatePicker(
              initialDate: isStartDate
                  ? (_startDate ?? DateTime.now())
                  : (_endDate ?? DateTime.now()),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (DateTime date) {
                setState(() {
                  if (isStartDate) {
                    _startDate = date;
                    _showStartDatePicker = false;
                  } else {
                    _endDate = date;
                    _showEndDatePicker = false;
                  }
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCustomerRow(Customer customer, double totalWidth) {
    return Container(
      width: totalWidth,
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.line1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: CHECKBOX_WIDTH,
            child: Checkbox(
              value: _selectedCustomers.contains(customer.id),
              onChanged: (value) => _toggleCustomerCheck(value, customer.id),
            ),
          ),
          buildDataCell(
            customer.name,
            totalWidth * CUSTOMER_NAME_RATIO,
            isClickable: true,
            onTap: () {
              context.go(
                  '/main/customer/${customer.id}'); // Using go_router for navigation
            },
          ),
          buildDataCell('진행중', totalWidth * STATUS_RATIO),
          buildDataCell(customer.phone, totalWidth * PHONE_RATIO),
          buildDataCell(customer.email, totalWidth * EMAIL_RATIO),
          buildDataCell(customer.address, totalWidth * ADDRESS_RATIO),
          SizedBox(
            width: totalWidth * LICENSE_RATIO,
            child: customer.businessLicenseUrl.isEmpty
                ? const Center(
                    child: Text('미첨부', style: TextStyle(color: Colors.red)))
                : Center(
                    child: TextButton(
                      onPressed: () async {
                        try {
                          if (customer.businessLicenseUrl
                              .contains('firebasestorage.googleapis.com')) {
                            final ref = FirebaseStorage.instance
                                .refFromURL(customer.businessLicenseUrl);
                            final downloadUrl = await ref.getDownloadURL();
                            html.window.open(downloadUrl, '_blank');
                          } else {
                            html.window
                                .open(customer.businessLicenseUrl, '_blank');
                          }
                        } catch (e) {
                          print('Download error: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('파일 다운로드 중 오류가 발생했습니다: $e')),
                          );
                        }
                      },
                      child: const Icon(Icons.download, color: AppColor.font1),
                    ),
                  ),
          ),
          buildDataCell('₩${customer.note ?? '0'}', totalWidth * BUDGET_RATIO),
          buildDataCell(customer.note, totalWidth * NOTE_RATIO),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    final customer =
        ref.read(customerDataProvider.notifier).getCustomer(widget.customerId);
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
                  const SizedBox(height: 16),
                  // 정보수정 버튼
                  Container(
                    width: 152,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.line1),
                    ),
                    child: const Center(
                      child: Text(
                        '정보수정',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColor.font1,
                          fontSize: 16,
                        ),
                      ),
                    ),
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
                                child: Image.asset('assets/images/user.png')),
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
            Expanded(child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              return FutureBuilder<Customer?>(
                  future: customer,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final customer = snapshot.data;
                    if (customer == null) {
                      return const Center(child: Text('고객 정보를 찾을 수 없습니다.'));
                    }
                    final double availableHeight = constraints.maxHeight - 48;
                    // constraints를 여기서 받음
                    final double availableWidth = constraints.maxWidth - 48;
                    final double tableWidth = max(1200, availableWidth);
                    return SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: SingleChildScrollView(
                            child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 상단 영역 (날짜 및 아이콘)
                                      SizedBox(
                                        width: availableWidth,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                context.pop();
                                              },
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.arrow_back_ios),
                                                  SizedBox(
                                                    width: 4,
                                                  ),
                                                  Text(
                                                    '이전',
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  )
                                                ],
                                              ),
                                            ),
                                            const Row(
                                              children: [
                                                Icon(Icons.person_outline_sharp,
                                                    color: AppColor.font2),
                                                SizedBox(width: 16),
                                                Icon(
                                                    Icons
                                                        .notifications_none_outlined,
                                                    color: AppColor.font2),
                                                SizedBox(width: 16),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 56),
                                      const Text(
                                        '고객 상세정보',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: AppColor.font1,
                                        ),
                                      ),
                                      const SizedBox(height: 48),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '고객 정보',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                                color: Colors.black),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              context.go(
                                                  '/main/customer/${customer.id}/edit');
                                            },
                                            child: const Text(
                                              '수정하기',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Color(0xff757575)),
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 12,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 48),
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height: 2,
                                        color: Colors.black,
                                      ),
                                      Container(
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final cellWidth =
                                                (constraints.maxWidth - 48) /
                                                    2; // 2열로 나누기

                                            return Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: cellWidth,
                                                      child: _buildInfoCell(
                                                          '회사명', customer.name),
                                                    ),
                                                    SizedBox(
                                                      width: cellWidth,
                                                      child: _buildInfoCell(
                                                          '연락처',
                                                          customer.phone),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: cellWidth,
                                                      child: _buildInfoCell(
                                                          '이메일주소',
                                                          customer.email),
                                                    ),
                                                    SizedBox(
                                                      width: cellWidth,
                                                      child: _buildInfoCell(
                                                          '배송지주소',
                                                          customer.address),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: cellWidth,
                                                      child: _buildFileCell(
                                                          '사업자등록증',
                                                          customer
                                                              .businessLicenseUrl),
                                                    ),
                                                    SizedBox(
                                                      width: cellWidth,
                                                      child: _buildFileCell(
                                                          '기타서류',
                                                          customer
                                                              .otherDocumentUrls
                                                              .join(', ')),
                                                    ),
                                                  ],
                                                ),
                                                _buildFullWidthCell(
                                                    '기타입력사항', customer.note),
                                              ],
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 36,
                                      ),
                                      const Text(
                                        '계약 내역',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18,
                                            color: Colors.black),
                                      ),
                                      const SizedBox(
                                        height: 12,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 48),
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height: 2,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(
                                        height: 24,
                                      ),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            Stack(
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Text(
                                                              '검색',
                                                              style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Container(
                                                              width: 280,
                                                              height: 44,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: AppColor
                                                                        .line1,
                                                                    width: 1),
                                                              ),
                                                              child: TextField(
                                                                style:
                                                                    const TextStyle(
                                                                        height:
                                                                            1.2),
                                                                controller:
                                                                    _searchController,
                                                                decoration:
                                                                    const InputDecoration(
                                                                  isDense: true,
                                                                  contentPadding:
                                                                      EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              16,
                                                                          vertical:
                                                                              14),
                                                                  hintText:
                                                                      '상태, 상품명, 수령지, 담당자명, 금액 검색',
                                                                  hintStyle:
                                                                      TextStyle(
                                                                          fontSize:
                                                                              14),
                                                                  border:
                                                                      InputBorder
                                                                          .none,
                                                                ),
                                                                onChanged:
                                                                    (value) {
                                                                  _debounceTimer
                                                                      ?.cancel();

                                                                  // 300ms 후에 setState 실행
                                                                  _debounceTimer = Timer(
                                                                      const Duration(
                                                                          milliseconds:
                                                                              400),
                                                                      () {
                                                                    if (mounted) {
                                                                      setState(
                                                                          () {
                                                                        // 여기서 화면이 갱신됩니다
                                                                      });
                                                                    }
                                                                  });
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 24),
                                                            const Text(
                                                              '날짜',
                                                              style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12),
                                                              width: 200,
                                                              height: 44,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: AppColor
                                                                        .line1,
                                                                    width: 1),
                                                              ),
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _showStartDatePicker =
                                                                        !_showStartDatePicker;
                                                                    _showEndDatePicker =
                                                                        false;
                                                                  });
                                                                },
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(_startDate ==
                                                                            null
                                                                        ? '년,월,일'
                                                                        : '${_startDate!.year}.${_startDate!.month}.${_startDate!.day}'),
                                                                    SizedBox(
                                                                        width:
                                                                            16.25,
                                                                        height:
                                                                            16.25,
                                                                        child: Image.asset(
                                                                            'assets/images/calendar.png'))
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12),
                                                              width: 200,
                                                              height: 44,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: AppColor
                                                                        .line1,
                                                                    width: 1),
                                                              ),
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _showEndDatePicker =
                                                                        !_showEndDatePicker;
                                                                    _showStartDatePicker =
                                                                        false;
                                                                  });
                                                                },
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(_endDate ==
                                                                            null
                                                                        ? '년,월,일'
                                                                        : '${_endDate!.year}.${_endDate!.month}.${_endDate!.day}'),
                                                                    SizedBox(
                                                                        width:
                                                                            16.25,
                                                                        height:
                                                                            16.25,
                                                                        child: Image.asset(
                                                                            'assets/images/calendar.png'))
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          width: 370,
                                                        ),
                                                        Container(
                                                          child: Row(
                                                            children: [
                                                              InkWell(
                                                                onTap:
                                                                    _deleteSelectedEstimates, // 함수 변경
                                                                child:
                                                                    Container(
                                                                  width:
                                                                      80, // 너비 조정
                                                                  height: 44,
                                                                  decoration: BoxDecoration(
                                                                      border: Border.all(
                                                                          color: AppColor
                                                                              .line1,
                                                                          width:
                                                                              1)),
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  child:
                                                                      const Text(
                                                                    '견적 삭제', // 텍스트 변경
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Colors
                                                                          .black,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                            ],
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap:
                                                              _addNewEstimateToExistingCustomer, // 함수 호출 변경
                                                          child: Container(
                                                            color:
                                                                AppColor.main,
                                                            width: 141,
                                                            height: 44,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        10,
                                                                    horizontal:
                                                                        16),
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  '견적 내역 추가',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                                Icon(
                                                                  Icons.add,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 16,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 24),
                                                    // 테이블 영역
                                                    SizedBox(
                                                      width: availableWidth,
                                                      height: availableHeight,
                                                      child: ClipRRect(
                                                        child:
                                                            SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          child: ConstrainedBox(
                                                            constraints:
                                                                BoxConstraints(
                                                              minWidth:
                                                                  tableWidth,
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                FutureBuilder<
                                                                    List<
                                                                        Map<String,
                                                                            dynamic>>>(
                                                                  future: _fetchEstimates(
                                                                      customer
                                                                          .id),
                                                                  builder: (context,
                                                                      estimatesSnapshot) {
                                                                    if (estimatesSnapshot
                                                                            .connectionState ==
                                                                        ConnectionState
                                                                            .waiting) {
                                                                      return const Center(
                                                                          child:
                                                                              CircularProgressIndicator());
                                                                    }

                                                                    if (estimatesSnapshot
                                                                        .hasError) {
                                                                      return Center(
                                                                          child:
                                                                              Text('Error: ${estimatesSnapshot.error}'));
                                                                    }

                                                                    final estimates =
                                                                        estimatesSnapshot.data ??
                                                                            [];
                                                                    final filteredEstimates =
                                                                        _filterEstimates(
                                                                            estimates);

                                                                    return Column(
                                                                      children: [
                                                                        // 기존의 buildEstimateTableHeader(tableWidth) 대신 사용
                                                                        buildEstimateTableHeaderWithData(
                                                                            tableWidth,
                                                                            estimates),
                                                                        ...filteredEstimates
                                                                            .map((estimate) =>
                                                                                buildEstimateRow(estimate, tableWidth))
                                                                            .toList(),
                                                                      ],
                                                                    );
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_showStartDatePicker)
                                                  Positioned(
                                                    top: 48,
                                                    left: 368,
                                                    child: Material(
                                                      elevation: 24,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Container(
                                                        width: 300,
                                                        height: 400,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Theme(
                                                          data:
                                                              ThemeData.light()
                                                                  .copyWith(
                                                            colorScheme:
                                                                const ColorScheme
                                                                    .light(
                                                              primary:
                                                                  AppColor.main,
                                                            ),
                                                          ),
                                                          child:
                                                              CalendarDatePicker(
                                                            initialDate:
                                                                _startDate ??
                                                                    DateTime
                                                                        .now(),
                                                            firstDate:
                                                                DateTime(2000),
                                                            lastDate:
                                                                DateTime(2100),
                                                            onDateChanged:
                                                                (DateTime
                                                                    date) {
                                                              setState(() {
                                                                _startDate =
                                                                    date;
                                                                _showStartDatePicker =
                                                                    false;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (_showEndDatePicker)
                                                  Positioned(
                                                    top: 48,
                                                    left: 572,
                                                    child: Material(
                                                      elevation: 24,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Container(
                                                        width: 300,
                                                        height: 400,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Theme(
                                                          data:
                                                              ThemeData.light()
                                                                  .copyWith(
                                                            colorScheme:
                                                                const ColorScheme
                                                                    .light(
                                                              primary:
                                                                  AppColor.main,
                                                            ),
                                                          ),
                                                          child:
                                                              CalendarDatePicker(
                                                            initialDate:
                                                                _endDate ??
                                                                    DateTime
                                                                        .now(),
                                                            firstDate:
                                                                DateTime(2000),
                                                            lastDate:
                                                                DateTime(2100),
                                                            onDateChanged:
                                                                (DateTime
                                                                    date) {
                                                              setState(() {
                                                                _endDate = date;
                                                                _showEndDatePicker =
                                                                    false;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ]))));
                  });
            }))
          ],
        ),
      ),
    );
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

  Future<void> downloadFile(String url, BuildContext context) async {
    try {
      if (url.contains('firebasestorage.googleapis.com')) {
        // Firebase Storage Reference 생성
        final ref = FirebaseStorage.instance.refFromURL(url);

        // 인증된 다운로드 URL 생성 (토큰 포함)
        final downloadUrl = await ref.getDownloadURL();

        // 새 탭에서 열기
        html.window.open(downloadUrl, '_blank');
      } else {
        // 일반 URL인 경우 바로 열기
        html.window.open(url, '_blank');
      }
    } catch (e) {
      print('Download error: $e');
      // 에러 발생 시 사용자에게 알림
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 다운로드 중 오류가 발생했습니다: $e')),
        );
      }
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
                : Builder(
                    builder: (context) => InkWell(
                      onTap: () => downloadFile(value, context),
                      child: Text(
                        getFileName(value),
                        style: const TextStyle(
                          color: AppColor.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
          ),
        )
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
