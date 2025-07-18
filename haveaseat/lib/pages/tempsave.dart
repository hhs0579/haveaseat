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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TempSavePage extends ConsumerStatefulWidget {
  const TempSavePage({super.key});

  @override
  ConsumerState<TempSavePage> createState() => _TempSavePageState();
}

class _TempSavePageState extends ConsumerState<TempSavePage> {
  final Set<String> _selectedItems = {};
  bool _allCheck = false;

  // 검색 관련 변수
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showStartDatePicker = false;
  bool _showEndDatePicker = false;
  Timer? _debounceTimer;

  // 테이블 너비 상수
  static const double CHECKBOX_WIDTH = 56;
  static const double COMPANY_NAME_RATIO = 0.15;
  static const double TYPE_RATIO = 0.1;
  static const double CREATED_DATE_RATIO = 0.15;
  static const double MODIFIED_DATE_RATIO = 0.15;
  static const double MANAGER_RATIO = 0.15;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      context.go('/login');
    } catch (e) {
      print('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')),
        );
      }
    }
  }

  void _toggleAllCheck(bool? checked, List<Map<String, dynamic>> items) {
    setState(() {
      _allCheck = checked ?? false;
      if (_allCheck) {
        _selectedItems.addAll(items.map((item) => item['id'] as String));
      } else {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemCheck(bool? checked, String itemId) {
    setState(() {
      if (checked ?? false) {
        _selectedItems.add(itemId);
      } else {
        _selectedItems.remove(itemId);
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    try {
      if (_selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제할 항목을 선택해주세요')),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('임시저장 삭제'),
          content: Text('선택한 ${_selectedItems.length}개의 항목을 삭제하시겠습니까?'),
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

      // TODO: 실제 삭제 로직 구현 (임시저장 데이터 삭제)
      await Future.wait(
        _selectedItems.map((itemId) async {
          try {
            // 예시: customers 컬렉션에서 isDraft가 true인 항목들 삭제
            await FirebaseFirestore.instance
                .collection('customers')
                .doc(itemId)
                .delete();
          } catch (e) {
            print('Error deleting item $itemId: $e');
          }
        }),
      );

      setState(() {
        _selectedItems.clear();
        _allCheck = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 항목이 삭제되었습니다')),
        );
      }
    } catch (e) {
      print('Error in _deleteSelectedItems: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  // 임시저장 데이터 가져오기
  Future<List<Map<String, dynamic>>> _fetchTempSaveData() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return [];

      // estimates 컬렉션에서 isDraft: true인 임시저장 데이터만 가져오기
      final estimateSnapshot = await FirebaseFirestore.instance
          .collection('estimates')
          .where('isDraft', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> tempSaveItems = [];

      for (var doc in estimateSnapshot.docs) {
        final data = doc.data();
        tempSaveItems.add({
          'id': doc.id,
          'customerId': data['customerId'] ?? doc.id,
          'estimateId': data['estimateId'] ?? doc.id,
          'name': data['name'] ?? '무제',
          'type': data['type'] ?? '임시저장',
          'createdDate':
              data['createdAt'] ?? data['lastUpdated'] ?? Timestamp.now(),
          'modifiedDate':
              data['updatedAt'] ?? data['lastUpdated'] ?? Timestamp.now(),
          'manager': data['managerName'] ?? '담당자 미정',
          'isDraft': true,
        });
      }

      return tempSaveItems;
    } catch (e) {
      print('Error fetching temp save data: $e');
      return [];
    }
  }

  // 검색 필터링
  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    if (_searchController.text.isEmpty &&
        _startDate == null &&
        _endDate == null) {
      // isDraft == true이면서 이름이 비어있지 않고 '무제', '이름없음'이 아닌 데이터만 반환
      return items
          .where((item) =>
              item['isDraft'] == true &&
              item['name'] != null &&
              item['name'].toString().trim().isNotEmpty &&
              item['name'] != '무제' &&
              item['name'] != '이름없음')
          .toList();
    }

    return items.where((item) {
      if (item['isDraft'] != true) return false;
      if (item['name'] == null || item['name'].toString().trim().isEmpty) {
        return false;
      }
      if (item['name'] == '무제' || item['name'] == '이름없음') {
        return false;
      }

      // 검색어 필터링
      if (_searchController.text.isNotEmpty) {
        String searchTerm = _searchController.text.toLowerCase();
        bool matchesSearch =
            item['name'].toString().toLowerCase().contains(searchTerm) ||
                item['type'].toString().toLowerCase().contains(searchTerm) ||
                item['manager'].toString().toLowerCase().contains(searchTerm);

        if (!matchesSearch) return false;
      }

      // 날짜 필터링
      if (_startDate != null || _endDate != null) {
        DateTime itemDate = (item['createdDate'] as Timestamp).toDate();
        if (_startDate != null && itemDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null &&
            itemDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
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
                    color: AppColor.primary,
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

  Widget buildTableHeader(double totalWidth, List<Map<String, dynamic>> items) {
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
              onChanged: (value) => _toggleAllCheck(value, items),
            ),
          ),
          buildHeaderCell('회사명', totalWidth * COMPANY_NAME_RATIO),
          buildHeaderCell('종류', totalWidth * TYPE_RATIO),
          buildHeaderCell('작성날짜', totalWidth * CREATED_DATE_RATIO),
          buildHeaderCell('수정날짜', totalWidth * MODIFIED_DATE_RATIO),
          buildHeaderCell('담당자', totalWidth * MANAGER_RATIO),
        ],
      ),
    );
  }

  Widget buildItemRow(Map<String, dynamic> item, double totalWidth) {
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
              value: _selectedItems.contains(item['id']),
              onChanged: (value) => _toggleItemCheck(value, item['id']),
            ),
          ),
          buildDataCell(
            item['name'],
            totalWidth * COMPANY_NAME_RATIO,
            isClickable: true,
            onTap: () {
              final customerId = item['customerId'] ?? item['id'];
              final estimateId = item['estimateId'] ?? item['id'];
              final type = item['type'] ?? '';
              final name = item['name'] ?? '';
              if (type == '고객정보') {
                context.go('/main/addpage/spaceadd/$customerId/$estimateId',
                    extra: {'name': name});
              } else if (type == '공간기본') {
                context.go(
                    '/main/addpage/spaceadd/$customerId/$estimateId/space-detail',
                    extra: {'name': name});
              } else if (type == '공간상세') {
                context.go(
                    '/main/addpage/spaceadd/$customerId/$estimateId/space-detail',
                    extra: {'name': name});
              } else if (type == '가구') {
                context.go(
                    '/main/addpage/spaceadd/$customerId/$estimateId/space-detail/furniture',
                    extra: {'name': name});
              } else if (type == '견적정보' || type == '견적') {
                context.go(
                    '/main/addpage/spaceadd/$customerId/$estimateId/space-detail/furniture/estimate',
                    extra: {'name': name});
              } else {
                context.go('/main/addpage/spaceadd/$customerId/$estimateId',
                    extra: {'name': name});
              }
            },
          ),
          buildDataCell(item['type'], totalWidth * TYPE_RATIO),
          buildDataCell(_formatDate(item['createdDate']),
              totalWidth * CREATED_DATE_RATIO),
          buildDataCell(_formatDate(item['modifiedDate']),
              totalWidth * MODIFIED_DATE_RATIO),
          buildDataCell(item['manager'], totalWidth * MANAGER_RATIO),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);

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
                          const SizedBox(width: 17.87),
                          SizedBox(
                            width: 16.25,
                            height: 16.25,
                            child: Image.asset('assets/images/user.png'),
                          ),
                          const SizedBox(width: 3.85),
                          const Text(
                            '담당 고객정보',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go('/all-customers'),
                    child: Container(
                      width: 200,
                      height: 48,
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          const SizedBox(width: 17.87),
                          SizedBox(
                            width: 16.25,
                            height: 16.25,
                            child: Image.asset('assets/images/group.png'),
                          ),
                          const SizedBox(width: 3.85),
                          const Text(
                            '전체 고객정보',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  InkWell(
                    onTap: () => context.go('/temp'),
                    child: Container(
                      width: 200,
                      height: 48,
                      color: const Color(0xffB18E72),
                      child: Row(
                        children: [
                          const SizedBox(width: 17.87),
                          SizedBox(
                            width: 16.25,
                            height: 16.25,
                            child: Image.asset(
                              'assets/images/draft.png',
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 3.85),
                          const Text(
                            '임시저장',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
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
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double availableHeight = constraints.maxHeight - 48;
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
                            // 상단 영역
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
                              '임시저장',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1,
                              ),
                            ),
                            const SizedBox(height: 48),

                            // 검색 영역
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
                                                      key: const ValueKey(
                                                          'search_field'),
                                                      style: const TextStyle(
                                                          height: 1.2),
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
                                                            '회사명, 종류, 담당자 검색',
                                                        hintStyle: TextStyle(
                                                            fontSize: 14),
                                                        border:
                                                            InputBorder.none,
                                                      ),
                                                      onChanged: (value) {
                                                        _debounceTimer
                                                            ?.cancel();
                                                        _debounceTimer = Timer(
                                                            const Duration(
                                                                milliseconds:
                                                                    300), () {
                                                          if (mounted) {
                                                            setState(() {});
                                                          }
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
                                              const SizedBox(width: 370),
                                              // 삭제 버튼
                                              InkWell(
                                                onTap: _deleteSelectedItems,
                                                child: Container(
                                                  width: 60,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: AppColor.line1,
                                                          width: 1)),
                                                  alignment: Alignment.center,
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
                                            ],
                                          ),
                                          const SizedBox(height: 24),

                                          // 테이블 영역
                                          SizedBox(
                                            width: availableWidth,
                                            height: availableHeight,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  minWidth: tableWidth,
                                                ),
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  child: FutureBuilder<
                                                      List<
                                                          Map<String,
                                                              dynamic>>>(
                                                    future:
                                                        _fetchTempSaveData(),
                                                    builder:
                                                        (context, snapshot) {
                                                      if (snapshot
                                                              .connectionState ==
                                                          ConnectionState
                                                              .waiting) {
                                                        return const Center(
                                                            child:
                                                                CircularProgressIndicator());
                                                      }

                                                      if (snapshot.hasError) {
                                                        return Center(
                                                            child: Text(
                                                                'Error: ${snapshot.error}'));
                                                      }

                                                      final items =
                                                          snapshot.data ?? [];
                                                      final filteredItems =
                                                          _filterItems(items);

                                                      return Column(
                                                        children: [
                                                          buildTableHeader(
                                                              tableWidth,
                                                              items),
                                                          ...filteredItems
                                                              .map((item) =>
                                                                  buildItemRow(
                                                                      item,
                                                                      tableWidth))
                                                              .toList(),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 날짜 선택기
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
                                              child: CalendarDatePicker(
                                                initialDate: _startDate ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                                onDateChanged: (DateTime date) {
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
                                              child: CalendarDatePicker(
                                                initialDate:
                                                    _endDate ?? DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                                onDateChanged: (DateTime date) {
                                                  setState(() {
                                                    _endDate = date;
                                                    _showEndDatePicker = false;
                                                  });
                                                },
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
