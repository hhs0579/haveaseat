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

class TempSavePage extends ConsumerStatefulWidget {
  const TempSavePage({super.key});

  @override
  ConsumerState<TempSavePage> createState() => _TempSavePageState();
}

class _TempSavePageState extends ConsumerState<TempSavePage> {
  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    final customers = ref.watch(customerDataProvider);
    return Scaffold(
        body: ResponsiveLayout(
            mobile: const SingleChildScrollView(),
            desktop:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                  child:
                                      Image.asset('assets/images/group.png')),
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
                                  child:
                                      Image.asset('assets/images/draft.png')),
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
              Expanded(child: LayoutBuilder(
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
                                  const SizedBox(
                                    height: 56,
                                  ),
                                  const Text(
                                    '임시저장',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 24,
                                        color: Colors.black),
                                  ),
                                  const SizedBox(
                                    height: 56,
                                  ),
                                  const Row(
                                    children: [
                                      Text(
                                        '고객정보입력',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black),
                                      ),
                                      SizedBox(
                                        width: 12,
                                      ),
                                      Text(
                                        '고객정보입력',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black),
                                      )
                                    ],
                                  )
                                ]))));
              }))
            ])));
  }
}
