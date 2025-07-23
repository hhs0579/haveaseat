import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'dart:html' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math' show max;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AllCustomerPage extends ConsumerStatefulWidget {
  const AllCustomerPage({super.key});

  @override
  ConsumerState<AllCustomerPage> createState() => _AllCustomerPageState();
}

class _AllCustomerPageState extends ConsumerState<AllCustomerPage> {
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

// status별 고객 수를 계산하는 메서드
  Map<CustomerStatus, int> _getStatusCounts(List<Customer> customers) {
    // Remove the assignedTo filter and count all customers
    final filtered = customers
        .where((c) => c.isDraft != true)
        .where((c) => c.estimateIds.isNotEmpty)
        .toList();
    return Map.fromEntries(
      CustomerStatus.values.map((status) => MapEntry(
            status,
            filtered.where((customer) => customer.status == status).length,
          )),
    );
  }

// 필터링 메서드 수정
  List<Customer> _filterCustomers(List<Customer> customers) {
    // 전체 고객에서 isDraft == false인 고객만 남김, 견적 1개 이상만
    var filteredCustomers = customers
        .where((customer) => customer.isDraft == false)
        .where((customer) => customer.estimateIds.isNotEmpty)
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
                                  'assets/images/group.png',
                                  color: Colors.white,
                                )),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '전체 고객정보',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
                                  const Row(
                                    children: [
                                      Icon(Icons.person_outline_sharp,
                                          color: AppColor.font2),
                                      SizedBox(width: 16),
                                      Icon(Icons.notifications_none_outlined,
                                          color: AppColor.font2),
                                      SizedBox(width: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 56),
                            const Text(
                              '전체 고객정보',
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
                                                        loading: () => SizedBox(
                                                          width: tableWidth,
                                                          height: 200,
                                                          child: const Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          ),
                                                        ),
                                                        error: (error, stack) =>
                                                            SizedBox(
                                                          width: tableWidth,
                                                          height: 200,
                                                          child: Center(
                                                            child: Text(
                                                                'Error: $error'),
                                                          ),
                                                        ),
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
