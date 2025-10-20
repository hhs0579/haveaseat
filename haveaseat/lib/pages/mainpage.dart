import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:haveaseat/riverpod/product.dart';
import 'dart:html' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math' show max;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel_pkg;

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  final Set<String> _selectedCustomers = {};
  bool _allCheck = false;

  // 동적 너비 계산을 위한 상수
  static const double CHECKBOX_WIDTH = 56;
  static const double CUSTOMER_NAME_RATIO = 0.08;
  static const double STATUS_RATIO = 0.08;
  static const double PHONE_RATIO = 0.1;
  static const double EMAIL_RATIO = 0.15;
  static const double ADDRESS_RATIO = 0.2;
  static const double LICENSE_RATIO = 0.09;
  static const double BUDGET_RATIO = 0.1;
  static const double NOTE_RATIO = 0.1;

  // 상태 관련 상수 및 변수
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

  String getCustomerStatus(String? status) {
    return status ?? statusOptions[0];
  }

  @override
  void initState() {
    super.initState();
    // 페이지 로드 시 고객 데이터 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(customerDataProvider);
    });
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
          backgroundColor: Colors.white,
          title: const Text('고객 삭제'),
          content: Text('선택한 ${_selectedCustomers.length}명의 고객을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소', style: TextStyle(color: Colors.black)),
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
              // 고객의 파일 삭제
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

              // 고객의 모든 견적 찾기 및 파일 삭제
              try {
                final estimatesSnapshot = await FirebaseFirestore.instance
                    .collection('estimates')
                    .where('customerId', isEqualTo: customerId)
                    .get();

                for (final estimateDoc in estimatesSnapshot.docs) {
                  final estimateData = estimateDoc.data();

                  // designFileUrls 삭제
                  final designFileUrls =
                      estimateData['designFileUrls'] as List<dynamic>?;
                  if (designFileUrls != null && designFileUrls.isNotEmpty) {
                    for (final url in designFileUrls) {
                      try {
                        if (url != null && url.toString().isNotEmpty) {
                          final storageRef = FirebaseStorage.instance
                              .refFromURL(url.toString());
                          await storageRef.delete();
                        }
                      } catch (e) {
                        print('Failed to delete design file: $e');
                      }
                    }
                  }

                  // 견적 문서 삭제
                  await estimateDoc.reference.delete();
                }
              } catch (e) {
                print(
                    'Failed to delete estimates for customer $customerId: $e');
              }

              // 고객 문서 삭제
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: isClickable
          ? InkWell(
              onTap: onTap,
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColor.primary, // Making clickable text blue
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColor.font1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  Widget buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColor.font1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget buildTableHeader(double totalWidth) {
    return Container(
      width: totalWidth,
      height: 48,
      color: const Color(0xffF7F7FB),
      child: Row(
        children: [
          SizedBox(
            width: CHECKBOX_WIDTH,
            child: Checkbox(
              value: _allCheck,
              onChanged: (value) => _toggleAllCheck(
                  value, ref.read(customerDataProvider).value ?? []),
            ),
          ),
          buildHeaderCell('회사명', totalWidth * CUSTOMER_NAME_RATIO),
          buildHeaderCell('상태', totalWidth * STATUS_RATIO),
          buildHeaderCell('연락처', totalWidth * PHONE_RATIO),
          buildHeaderCell('주소', totalWidth * ADDRESS_RATIO),
          buildHeaderCell('사업자등록증', totalWidth * LICENSE_RATIO),
          buildHeaderCell('금액', totalWidth * BUDGET_RATIO),
          buildHeaderCell('기타입력사항', totalWidth * NOTE_RATIO),
        ],
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showStartDatePicker = false;
  bool _showEndDatePicker = false;

  // 검색 필터 함수

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
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColor.main,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColor.font1,
              ),
            ),
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

  Widget buildCustomerRow(
      Customer customer, double totalWidth, double totalAmount) {
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
              context.go('/main/customer/${customer.id}');
            },
          ),
          // 상태 드롭다운
          SizedBox(
            width: totalWidth * STATUS_RATIO,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CustomerStatus>(
                  value: customer.status,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: CustomerStatus.values.map((CustomerStatus status) {
                    return DropdownMenuItem<CustomerStatus>(
                      value: status,
                      child: Text(
                        status.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColor.font1,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (CustomerStatus? newStatus) {
                    if (newStatus != null) {
                      ref
                          .read(customerDataProvider.notifier)
                          .updateCustomerStatus(customer.id, newStatus);
                    }
                  },
                ),
              ),
            ),
          ),
          buildDataCell(customer.phone, totalWidth * PHONE_RATIO),
          buildDataCell(customer.address, totalWidth * ADDRESS_RATIO),
          SizedBox(
            width: totalWidth * LICENSE_RATIO,
            child: customer.businessLicenseUrl.isEmpty
                ? const Center(
                    child: Text('미첨부', style: TextStyle(color: Colors.red)))
                : Center(
                    child: TextButton(
                      onPressed: () {
                        html.window.open(customer.businessLicenseUrl, '_blank');
                      },
                      child: const Icon(Icons.download, color: AppColor.font1),
                    ),
                  ),
          ),
          buildDataCell('₩${NumberFormat('#,###').format(totalAmount)}',
              totalWidth * BUDGET_RATIO),
          buildDataCell(customer.note, totalWidth * NOTE_RATIO),
        ],
      ),
    );
  }
  // _MainPageState 클래스에 추가할 변수와 메서드

  CustomerStatus? _selectedStatus; // 선택된 status 저장

  // Excel 데이터 업로드 함수

  Future<void> uploadProductsFromExcel() async {
    try {
      print('🚀 Excel → Firestore 업로드 (문서ID=상품명)');

      // ===== 0) 엑셀 로드 =====
      final bytes = await rootBundle.load('assets/20241223_상품목록_전달용.xlsx');
      final book = excel_pkg.Excel.decodeBytes(bytes.buffer.asUint8List());
      if (book.tables.isEmpty) {
        print('❌ 시트 없음');
        return;
      }

      // 가장 데이터 많은 시트 선택
      final sheets = book.tables.values.toList()
        ..sort(
            (a, b) => (b.maxRows * b.maxCols).compareTo(a.maxRows * a.maxCols));
      final sheet = sheets.first;
      if (sheet.maxRows < 2) {
        print('❌ 데이터 없음');
        return;
      }

      dynamic cell(int c, int r) => sheet
          .cell(
              excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value;

      // ===== 1) 유틸 =====
      String? str(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      int? parseInt(dynamic v) {
        if (v == null) return null;
        final s = v.toString().replaceAll(',', '').trim();
        if (s.isEmpty) return null;
        final d = double.tryParse(s);
        if (d != null) return d.round();
        return int.tryParse(s);
      }

      String sanitizeId(String input) => input
          .replaceAll('/', '_')
          .replaceAll('.', '_')
          .replaceAll('#', '_')
          .replaceAll(r'$', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .trim();
      String truncateUtf8(String s, int maxBytes) {
        final bytes = utf8.encode(s);
        if (bytes.length <= maxBytes) return s;
        int end = maxBytes;
        while (end > 0) {
          try {
            return utf8.decode(bytes.sublist(0, end));
          } catch (_) {
            end--;
          }
        }
        return '';
      }

      String buildSafeIdFromName(String name, {int maxBytes = 200}) {
        final cleaned = sanitizeId(name);
        if (cleaned.isEmpty) return cleaned;
        final len = utf8.encode(cleaned).length;
        if (len <= maxBytes) return cleaned;
        final hash =
            sha1.convert(utf8.encode(cleaned)).toString().substring(0, 8);
        final room = maxBytes - utf8.encode('-$hash').length;
        final base = truncateUtf8(cleaned, room);
        return '$base-$hash';
      }

      String norm(String s) => s
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^0-9a-zA-Z가-힣]'), '')
          .toLowerCase();

      print('📊 선택 시트: ${sheet.maxRows}행 x ${sheet.maxCols}열');

      // ===== 2) 헤더 탐지 =====
      // “제품명 = 상품명”을 최우선으로 잡되, 보조로 ‘제품명’ 등도 허용
      final alias = <String, Set<String>>{
        '상품코드': {'상품코드', '제품코드', 'sku', 'code', 'productcode', '상품id', '상품아이디'}
            .map(norm)
            .toSet(),
        '상품명': {
          '상품명',
          '제품명',
          '품명',
          'name',
          'productname',
          '상품명국문',
          '국문상품명',
          '상품명한글',
          '한글상품명'
        }.map(norm).toSet(),
        '제품 스펙': {
          '제품스펙',
          '제품 스펙',
          '스펙',
          '사양',
          '규격',
          'spec',
          '상품간략설명',
          '상품 간략설명',
          '간략설명',
          '상품설명',
          '설명'
        }.map(norm).toSet(),
        '판매가액': {'판매가액', '판매가', '가격', 'price', 'saleprice', '정가', '소비자가'}
            .map(norm)
            .toSet(),
      };

      // 헤더 행: 상위 5행 중 매칭 최다
      int headerRow = 0, bestHits = -1;
      for (int r = 0; r < sheet.maxRows && r < 5; r++) {
        int hits = 0;
        for (int c = 0; c < sheet.maxCols; c++) {
          final h = str(cell(c, r));
          if (h == null) continue;
          final n = norm(h);
          if (alias.values.any((set) => set.contains(n))) hits++;
        }
        if (hits > bestHits) {
          bestHits = hits;
          headerRow = r;
        }
      }

      // 컬럼 인덱스 매핑
      int? colCode, colName, colSpec, colSale;
      final headers = <int, String>{};
      for (int c = 0; c < sheet.maxCols; c++) {
        final h = str(cell(c, headerRow));
        if (h == null) continue;
        headers[c] = h.trim();
        final n = norm(h);
        if (alias['상품코드']!.contains(n)) colCode = c;
        // ✅ 제품명 = "상품명" 우선, 보조로 "제품명" 등도 허용
        if (alias['상품명']!.contains(n)) colName = c;
        if (alias['제품 스펙']!.contains(n)) colSpec = c;
        if (alias['판매가액']!.contains(n)) colSale = c;
      }
      print('🧭 헤더행=$headerRow, 헤더=$headers');
      print('🔎 인덱스: 코드=$colCode, 이름(상품명)=$colName, 스펙=$colSpec, 판매가=$colSale');

      // 데이터 시작 행 자동 감지 (헤더 아래 공백행 스킵)
      int dataStart = headerRow + 1;
      while (dataStart < sheet.maxRows) {
        final hasAny = [
          if (colName != null) str(cell(colName, dataStart)),
          if (colCode != null) str(cell(colCode, dataStart)),
          if (colSale != null) str(cell(colSale, dataStart)),
          if (colSpec != null) str(cell(colSpec, dataStart)),
        ].any((e) => e != null && e.toString().isNotEmpty);
        if (hasAny) break;
        dataStart++;
      }
      print('➡️ 데이터 시작 행: $dataStart');

      // ===== 3) 행 수집 =====
      final rows = <Map<String, dynamic>>[];
      int skipNoName = 0, skipEmptyId = 0;
      for (int r = dataStart; r < sheet.maxRows; r++) {
        final name = colName != null ? str(cell(colName, r)) : null; // ← 상품명
        if (name == null || name.isEmpty) {
          skipNoName++;
          continue;
        }

        final code = colCode != null ? str(cell(colCode, r)) : null;
        final spec =
            colSpec != null ? str(cell(colSpec, r)) : null; // 상품 간략설명 → 제품 스펙
        final sale =
            colSale != null ? parseInt(cell(colSale, r)) : null; // 판매가액/판매가

        final id = buildSafeIdFromName(name);
        if (id.isEmpty) {
          skipEmptyId++;
          continue;
        }

        rows.add({
          'id': id,
          '상품코드': code,
          '제품명': name, // 🔥 Firestore "제품명"
          '제품 스펙': spec, // 🔥 Firestore "제품 스펙"
          '공급사': null, // 없으면 null
          '공급가액': null, // 없으면 null
          '판매가액': sale, // 🔥 Firestore "판매가액"
          // 호환 필드
          'name': name,
          'price': sale,
        });
      }
      print(
          '📥 수집=${rows.length}, 스킵(상품명 없음)=$skipNoName, 스킵(빈 ID)=$skipEmptyId');

      if (rows.isEmpty) {
        print('❌ 업로드할 데이터가 없습니다. (상품명 인식 실패 가능)');
        return;
      }

      // ===== 4) 400개 청크 배치 커밋 =====
      final col = FirebaseFirestore.instance.collection('products');
      const chunkSize = 400;
      int success = 0;
      for (int start = 0; start < rows.length; start += chunkSize) {
        final end =
            (start + chunkSize < rows.length) ? start + chunkSize : rows.length;
        final chunk = rows.sublist(start, end);
        final batch = FirebaseFirestore.instance.batch();
        for (final row in chunk) {
          batch.set(
              col.doc(row['id'] as String),
              {
                '상품코드': row['상품코드'],
                '제품명': row['제품명'],
                '제품 스펙': row['제품 스펙'],
                '공급사': row['공급사'],
                '공급가액': row['공급가액'],
                '판매가액': row['판매가액'],
                'name': row['name'],
                'price': row['price'],
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
        await batch.commit();
        success += chunk.length;
        print('✅ 커밋: $start ~ ${end - 1} (누적 $success)');
      }

      print('🎉 전체 업로드 완료: $success 건 (문서ID=상품명)');
    } catch (e) {
      print('❌ 전체 실패: $e');
    }
  }

// status별 고객 수를 계산하는 메서드
  Map<CustomerStatus, int> _getStatusCounts(List<Customer> customers) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final myCustomers = customers
        .where((c) => c.assignedTo == currentUserId)
        .where((c) => c.isDraft != true)
        .where((c) => c.estimateIds.isNotEmpty)
        .toList();
    // 견적이 1개 이상이고, 그 견적이 모두 isDraft==false인 경우만 카운트
    // (여기서는 고객의 isDraft만 체크, 견적의 isDraft는 상세 쿼리에서 추가로 체크 필요)
    return Map.fromEntries(
      CustomerStatus.values.map((status) => MapEntry(
            status,
            myCustomers.where((customer) => customer.status == status).length,
          )),
    );
  }

// 필터링 메서드 수정
  List<Customer> _filterCustomers(List<Customer> customers) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // 담당 고객만 필터링 후, 임시저장 제외
    var filteredCustomers = customers
        .where((customer) => customer.assignedTo == currentUserId)
        .where((customer) => customer.isDraft != true)
        .toList();

    // Status filter
    if (_selectedStatus != null) {
      filteredCustomers = filteredCustomers
          .where((customer) => customer.status == _selectedStatus)
          .toList();
    }

    // 검색어나 날짜 필터가 없으면 현재 필터된 고객 반환
    if (_searchController.text.isEmpty &&
        _startDate == null &&
        _endDate == null) {
      return filteredCustomers;
    }

    // 기존 검색어 및 날짜 필터 적용
    return filteredCustomers.where((customer) {
      // 검색어 필터링
      if (_searchController.text.isNotEmpty) {
        String searchTerm = _searchController.text.toLowerCase();
        bool matchesSearch = customer.name.toLowerCase().contains(searchTerm) ||
            customer.address.toLowerCase().contains(searchTerm) ||
            customer.note.toLowerCase().contains(searchTerm);

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

// Status 카운트를 보여주는 위젯
  Widget _buildStatusCounter(CustomerStatus status, int count) {
    final bool isSelected = _selectedStatus == status;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = isSelected ? null : status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        width: 161,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(
              color: isSelected ? const Color(0xffB18E72) : AppColor.line1,
              width: 2),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isSelected ? const Color(0xffB18E72) : Colors.black,
              ),
            ),
            Row(
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                      color:
                          isSelected ? const Color(0xffB18E72) : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 20),
                ),
                Text(
                  ' 건',
                  style: TextStyle(
                      color:
                          isSelected ? const Color(0xffB18E72) : Colors.black,
                      fontSize: 16),
                ),
              ],
            )
          ],
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
                        color: const Color(0xffB18E72),
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
                                  color: Colors.white,
                                )),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '담당 고객정보',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
                  const SizedBox(),
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
                  const SizedBox(height: 16),
                  // Excel 데이터 업로드 버튼

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
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상단 영역 (날짜 및 아이콘)
                            SizedBox(
                              width: availableWidth,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColor.font1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 56),
                            const Text(
                              '담당 고객정보',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1,
                              ),
                            ),
                            const SizedBox(height: 48),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  customers.when(
                                    data: (customerList) {
                                      final statusCounts =
                                          _getStatusCounts(customerList);
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildStatusCounter(
                                              CustomerStatus
                                                  .ESTIMATE_IN_PROGRESS,
                                              statusCounts[CustomerStatus
                                                      .ESTIMATE_IN_PROGRESS] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.ESTIMATE_COMPLETE,
                                              statusCounts[CustomerStatus
                                                      .ESTIMATE_COMPLETE] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.CONTRACT_COMPLETE,
                                              statusCounts[CustomerStatus
                                                      .CONTRACT_COMPLETE] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.ORDER_START,
                                              statusCounts[CustomerStatus
                                                      .ORDER_START] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.RECEIVING,
                                              statusCounts[CustomerStatus
                                                      .RECEIVING] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.INSPECTION,
                                              statusCounts[CustomerStatus
                                                      .INSPECTION] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.DELIVERY,
                                              statusCounts[CustomerStatus
                                                      .DELIVERY] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.REVIEW,
                                              statusCounts[
                                                      CustomerStatus.REVIEW] ??
                                                  0),
                                          const SizedBox(width: 20),
                                          _buildStatusCounter(
                                              CustomerStatus.COMPLETE,
                                              statusCounts[CustomerStatus
                                                      .COMPLETE] ??
                                                  0),
                                        ],
                                      );
                                    },
                                    loading: () => const Center(
                                        child: CircularProgressIndicator()),
                                    error: (error, stack) =>
                                        Text('Error: $error'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 36,
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    '검색',
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    width: 280,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: AppColor.line1,
                                                          width: 1),
                                                    ),
                                                    child: TextField(
                                                      style: const TextStyle(
                                                        height:
                                                            1.2, // 라인 높이를 조정하여 수직 정렬 맞춤
                                                      ),
                                                      controller:
                                                          _searchController,
                                                      decoration:
                                                          const InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical:
                                                                        14),
                                                        hintText:
                                                            '고객명,주소,업체명,공간컨셉 키워드',
                                                        hintStyle: TextStyle(
                                                            fontSize: 14),
                                                        border:
                                                            InputBorder.none,
                                                        enabledBorder:
                                                            InputBorder.none,
                                                        focusedBorder:
                                                            InputBorder.none,
                                                        hoverColor:
                                                            Colors.transparent,
                                                      ),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          // 검색어가 변경될 때마다 화면 갱신
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 24),
                                                  const Text(
                                                    '날짜',
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                    width: 200,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: AppColor.line1,
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
                                                              width: 16.25,
                                                              height: 16.25,
                                                              child: Image.asset(
                                                                  'assets/images/calendar.png'))
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                    width: 200,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: AppColor.line1,
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
                                                          Text(_endDate == null
                                                              ? '년,월,일'
                                                              : '${_endDate!.year}.${_endDate!.month}.${_endDate!.day}'),
                                                          SizedBox(
                                                              width: 16.25,
                                                              height: 16.25,
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
                                                          _deleteSelectedCustomers,
                                                      child: Container(
                                                        width: 60,
                                                        height: 44,
                                                        decoration: BoxDecoration(
                                                            border: Border.all(
                                                                color: AppColor
                                                                    .line1,
                                                                width: 1)),
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Text(
                                                          '삭제',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: () => context
                                                          .go('/main/addpage'),
                                                      child: Container(
                                                        color: AppColor.main,
                                                        width: 141,
                                                        height: 44,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 10,
                                                                horizontal: 16),
                                                        child: const Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center, // 추가
                                                          children: [
                                                            Text(
                                                              '고객정보입력',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons.add,
                                                              color:
                                                                  Colors.white,
                                                              size: 16, // 크기 명시
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          // 테이블 영역
                                          SizedBox(
                                            width: availableWidth,
                                            height: availableHeight,
                                            child: ClipRRect(
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    minWidth: tableWidth,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      buildTableHeader(
                                                          tableWidth),
                                                      // customers.when 부분을 다음과 같이 수정

                                                      customers.when(
                                                        data: (customerList) {
                                                          final filteredCustomers =
                                                              _filterCustomers(
                                                                  customerList);
                                                          return FutureBuilder<
                                                              Map<String,
                                                                  double>>(
                                                            future: ref
                                                                .read(customerDataProvider
                                                                    .notifier)
                                                                .getCustomersTotalAmounts(
                                                                    filteredCustomers
                                                                        .map((c) =>
                                                                            c.id)
                                                                        .toList()),
                                                            builder: (context,
                                                                snapshot) {
                                                              if (snapshot
                                                                      .connectionState ==
                                                                  ConnectionState
                                                                      .waiting) {
                                                                return const Center(
                                                                    child:
                                                                        CircularProgressIndicator());
                                                              }

                                                              if (snapshot
                                                                  .hasError) {
                                                                return Text(
                                                                    'Error: ${snapshot.error}');
                                                              }

                                                              final totalAmounts =
                                                                  snapshot.data ??
                                                                      {};
                                                              return Column(
                                                                children:
                                                                    filteredCustomers
                                                                        .map((customer) =>
                                                                            buildCustomerRow(
                                                                              customer,
                                                                              tableWidth,
                                                                              totalAmounts[customer.id] ?? 0,
                                                                            ))
                                                                        .toList(),
                                                              );
                                                            },
                                                          );
                                                        },
                                                        loading: () => const Center(
                                                            child:
                                                                CircularProgressIndicator()),
                                                        error: (error, stack) =>
                                                            Text(
                                                                'Error: $error'),
                                                      )
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
                                                BorderRadius.circular(8),
                                            child: Container(
                                              width: 300,
                                              height: 400,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Theme(
                                                data:
                                                    ThemeData.light().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                    primary: AppColor.main,
                                                    onPrimary: Colors.white,
                                                    surface: Colors.white,
                                                    onSurface: AppColor.font1,
                                                  ),
                                                ),
                                                child: CalendarDatePicker(
                                                  initialDate: _startDate ??
                                                      DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                  onDateChanged:
                                                      (DateTime date) {
                                                    setState(() {
                                                      _startDate = date;
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
                                                BorderRadius.circular(8),
                                            child: Container(
                                              width: 300,
                                              height: 400,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Theme(
                                                data:
                                                    ThemeData.light().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                    primary: AppColor.main,
                                                    onPrimary: Colors.white,
                                                    surface: Colors.white,
                                                    onSurface: AppColor.font1,
                                                  ),
                                                ),
                                                child: CalendarDatePicker(
                                                  initialDate: _endDate ??
                                                      DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                  onDateChanged:
                                                      (DateTime date) {
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
