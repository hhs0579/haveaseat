import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';

import 'dart:html' as html;

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    final customer =
        ref.read(customerDataProvider.notifier).getCustomer(widget.customerId);

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
                  InkWell(
                    onTap: () {},
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
                                child: Image.asset('assets/images/corp.png')),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '업체 정보',
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
                    onTap: () {},
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
                                child: Image.asset('assets/images/as.png')),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '교환',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1,
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
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 17.87,
                            ),
                            SizedBox(
                                width: 16.25,
                                height: 16.25,
                                child: Image.asset('assets/images/as.png')),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '반품',
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
                    onTap: () {},
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
                                      const Text(
                                        '고객 정보',
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
                                                          '고객명', customer.name),
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
