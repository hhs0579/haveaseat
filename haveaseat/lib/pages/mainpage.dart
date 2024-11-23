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

  Widget buildDataCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
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
          buildHeaderCell('고객명', totalWidth * CUSTOMER_NAME_RATIO),
          buildHeaderCell('상태', totalWidth * STATUS_RATIO),
          buildHeaderCell('연락처', totalWidth * PHONE_RATIO),
          buildHeaderCell('이메일 주소', totalWidth * EMAIL_RATIO),
          buildHeaderCell('주소', totalWidth * ADDRESS_RATIO),
          buildHeaderCell('사업자등록증', totalWidth * LICENSE_RATIO),
          buildHeaderCell('금액', totalWidth * BUDGET_RATIO),
          buildHeaderCell('기타입력사항', totalWidth * NOTE_RATIO),
        ],
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
          buildDataCell(customer.name, totalWidth * CUSTOMER_NAME_RATIO),
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
                      onPressed: () {
                        html.window.open(customer.businessLicenseUrl, '_blank');
                      },
                      child: const Icon(Icons.download, color: AppColor.font1),
                    ),
                  ),
          ),
          buildDataCell('₩${customer.spaceDetailInfo?.budget ?? 0}',
              totalWidth * BUDGET_RATIO),
          buildDataCell(customer.note, totalWidth * NOTE_RATIO),
        ],
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
                  SizedBox(
                    width: 137,
                    height: 17,
                    child: Image.asset('assets/images/logo.png'),
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
                  Container(
                    width: 200,
                    height: 48,
                    color: AppColor.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Row(
                      children: [
                        Icon(Icons.person_outline_sharp,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '담당 고객정보',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 200,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Row(
                      children: [
                        Icon(Icons.person_outline_sharp,
                            color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '고객 정보',
                          style: TextStyle(
                            color: AppColor.font1,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                              '담당 고객정보',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => context.go('/main/addpage'),
                                  child: Container(
                                    color: AppColor.primary,
                                    width: 95,
                                    height: 36,
                                    child: const Center(
                                      child: Text(
                                        '고객추가 +',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _deleteSelectedCustomers,
                                  child: Container(
                                    width: 95,
                                    height: 36,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '삭제하기',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
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
                              child: ClipRRect(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: tableWidth,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        buildTableHeader(tableWidth),
                                        customers.when(
                                          data: (customerList) => Column(
                                            children: customerList
                                                .map((customer) =>
                                                    buildCustomerRow(
                                                        customer, tableWidth))
                                                .toList(),
                                          ),
                                          loading: () => SizedBox(
                                            width: tableWidth,
                                            height: 200,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                          error: (error, stack) => SizedBox(
                                            width: tableWidth,
                                            height: 200,
                                            child: Center(
                                              child: Text('Error: $error'),
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
