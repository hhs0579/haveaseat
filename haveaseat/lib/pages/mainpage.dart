// lib/pages/main_page.dart

import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'dart:html' as html; // 파일 다운로드를 위한 import
import 'package:firebase_storage/firebase_storage.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  final Set<String> _selectedCustomers = {}; // 선택된 고객 ID를 저장할 Set
  bool _allCheck = false;

  // 모든 체크박스 상태 변경
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

  // 개별 체크박스 상태 변경
  void _toggleCustomerCheck(bool? checked, String customerId) {
    setState(() {
      if (checked ?? false) {
        _selectedCustomers.add(customerId);
      } else {
        _selectedCustomers.remove(customerId);
      }
    });
  }

  // 선택된 고객 삭제
  Future<void> _deleteSelectedCustomers() async {
    try {
      if (_selectedCustomers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제할 고객을 선택해주세요')),
        );
        return;
      }

      // 확인 다이얼로그 표시
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

      // 각 고객에 대해 파일 삭제 및 문서 삭제 진행
      await Future.wait(
        _selectedCustomers.map((customerId) async {
          try {
            final customer = await ref
                .read(customerDataProvider.notifier)
                .getCustomer(customerId);

            if (customer != null) {
              // 사업자등록증 삭제 시도
              if (customer.businessLicenseUrl.isNotEmpty) {
                try {
                  final storageRef = FirebaseStorage.instance
                      .refFromURL(customer.businessLicenseUrl);
                  await storageRef.delete();
                } catch (e) {
                  print('Failed to delete business license: $e');
                  // 파일 삭제 실패해도 계속 진행
                }
              }

              // 기타 문서 삭제 시도
              for (final url in customer.otherDocumentUrls) {
                try {
                  final storageRef = FirebaseStorage.instance.refFromURL(url);
                  await storageRef.delete();
                } catch (e) {
                  print('Failed to delete other document: $e');
                  // 파일 삭제 실패해도 계속 진행
                }
              }

              // Firestore 문서 삭제
              await ref
                  .read(customerDataProvider.notifier)
                  .deleteCustomer(customerId);
            }
          } catch (e) {
            print('Error processing customer $customerId: $e');
            // 개별 고객 처리 실패해도 다른 고객 처리 계속 진행
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

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    final customers = ref.watch(customerDataProvider);
    bool allCheck = false;
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

    Widget buildTableHeader() {
      return Container(
        width: MediaQuery.of(context).size.width - 336,
        height: 48,
        color: const Color(0xffF7F7FB),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // 체크박스
            SizedBox(
              width: 40,
              child: Checkbox(
                value: _allCheck,
                onChanged: (value) =>
                    _toggleAllCheck(value, customers.value ?? []),
              ),
            ),
            // 각 컬럼 헤더
            buildHeaderCell('고객명', 80),
            buildHeaderCell('상태', 100),
            buildHeaderCell('연락처', 120),
            buildHeaderCell('이메일 주소', 180),
            buildHeaderCell('주소', 360),
            buildHeaderCell('사업자등록증', 100),
            buildHeaderCell('금액', 120),
            buildHeaderCell('기타입력사항', 120),
          ],
        ),
      );
    }

    // 고객 데이터 행을 생성하는 함수
    Widget buildCustomerRow(Customer customer) {
      return Container(
        width: MediaQuery.of(context).size.width - 336,
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColor.line1)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // 체크박스
            SizedBox(
              width: 40,
              child: Checkbox(
                value: _selectedCustomers.contains(customer.id),
                onChanged: (value) => _toggleCustomerCheck(value, customer.id),
              ),
            ),
            // 각 데이터 셀
            buildDataCell(customer.name, 80),
            buildDataCell('진행중', 100), // 상태값은 필요에 따라 수정
            buildDataCell(customer.phone, 120),
            buildDataCell(customer.email, 180),
            buildDataCell(customer.address, 360),
            // 사업자등록증 셀
            SizedBox(
              width: 120,
              child: customer.businessLicenseUrl.isEmpty
                  ? const Text('미첨부', style: TextStyle(color: Colors.red))
                  : TextButton(
                      onPressed: () {
                        // 다운로드 로직
                        html.window.open(customer.businessLicenseUrl, '_blank');
                      },
                      child: const Icon(Icons.download, color: AppColor.font1),
                    ),
            ),
            buildDataCell('₩${customer.spaceDetailInfo?.budget ?? 0}', 100),
            buildDataCell(customer.note, 120),
          ],
        ),
      );
    }

    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                child: SizedBox(
                  width: 240,
                  child: Container(
                    height: MediaQuery.of(context).size.height,
                    constraints: const BoxConstraints(maxWidth: 240),
                    decoration: const BoxDecoration(
                        border:
                            Border(right: BorderSide(color: AppColor.line1))),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.center, // center로 변경
                      mainAxisAlignment: MainAxisAlignment.start,
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
                                  // crossAxisAlignment 제거
                                  Text(
                                    UserProvider.getUserName(data),
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: AppColor.font1),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    UserProvider.getDepartment(data),
                                    style: const TextStyle(
                                        fontSize: 14, color: AppColor.font4),
                                  ),
                                ],
                              );
                            }
                            return const Text('사용자 정보를 불러올 수 없습니다.');
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (error, stack) => Text('오류: $error'),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        InkWell(
                          onTap: () {},
                          child: Container(
                            width: 152,
                            height: 48,
                            decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(
                                  color: AppColor.line1,
                                )),
                            child: const Center(
                                child: Text(
                              '정보수정',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1,
                                  fontSize: 16),
                            )),
                          ),
                        ),
                        const SizedBox(
                          height: 40,
                        ),
                        InkWell(
                          onTap: () {},
                          child: Container(
                              width: 200,
                              height: 48,
                              color: AppColor.primary,
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 17.87,
                                  ),
                                  Icon(
                                    Icons.person_outline_sharp,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(
                                    width: 3.85,
                                  ),
                                  Text(
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
                          onTap: () {},
                          child: Container(
                              width: 200,
                              height: 48,
                              color: Colors.transparent,
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 17.87,
                                  ),
                                  Icon(
                                    Icons.person_outline_sharp,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  SizedBox(
                                    width: 3.85,
                                  ),
                                  Text(
                                    '고객 정보',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColor.font1,
                                        fontSize: 16),
                                  ),
                                ],
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 48,
              ),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SizedBox(
                      height: 40,
                    ),
                    SizedBox(
                      // Container 추가하여 너비 제한
                      width: MediaQuery.of(context).size.width -
                          288, // 전체 너비 - (왼쪽 사이드바 240 + 간격 48)
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1),
                          ),
                          const Row(
                            children: [
                              Icon(
                                Icons.person_outline_sharp,
                                color: AppColor.font2,
                              ),
                              SizedBox(width: 16),
                              Icon(
                                Icons.notifications_none_outlined,
                                color: AppColor.font2,
                              ),
                              SizedBox(width: 43), // 오른쪽 여백 추가
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 56),
                    const Text(
                      '담당 고객정보',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColor.font1),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            context.go('/main/addpage');
                          },
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
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _deleteSelectedCustomers,
                          child: Container(
                            color: Colors.transparent,
                            width: 95,
                            height: 36,
                            child: const Center(
                              child: Text(
                                '삭제하기',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildTableHeader(),

                          // 고객 리스트
                          customers.when(
                            data: (customerList) => Column(
                              children: customerList
                                  .map((customer) => buildCustomerRow(customer))
                                  .toList(),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stack) => Center(
                              child: Text('Error: $error'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ])),
            ],
          ),
        ),
      ),
    );
  }
}
