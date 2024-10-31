import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/usermodel.dart';

class addCustomerPage extends ConsumerWidget {
  const addCustomerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(UserProvider.userDataProvider);

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
                              color: Colors.transparent,
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 17.87,
                                  ),
                                  Icon(
                                    Icons.search_outlined,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  SizedBox(
                                    width: 3.85,
                                  ),
                                  Text(
                                    '대시보드',
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
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
