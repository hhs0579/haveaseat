// lib/pages/main_page.dart

import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:haveaseat/riverpod/usermodel.dart';

class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(UserProvider.userDataProvider);

    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: SingleChildScrollView(
          child: Row(
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
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: SingleChildScrollView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
