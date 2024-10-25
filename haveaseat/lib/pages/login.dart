import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가

class login extends StatelessWidget {
  const login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100, top: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 249,
                    height: 31,
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(height: 56),
                  const Text(
                    '관리자 로그인',
                    style: TextStyle(
                      color: AppColor.font1,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 로그인 폼
                  SizedBox(
                    width: 360,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '아이디',
                          style: TextStyle(
                            color: AppColor.font1,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            hintText: '아이디를 입력해 주세요',
                            hintStyle: TextStyle(
                              color: AppColor.font2,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColor.line1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColor.line1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColor.line1),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '비밀번호',
                          style: TextStyle(
                            color: AppColor.font1,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: '비밀번호를 입력해 주세요',
                            hintStyle: TextStyle(
                              color: AppColor.font2,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColor.line1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColor.primary),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColor.line1),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        // 로그인 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              // 로그인 처리
                              context.push('/main');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.primary,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: const Text(
                              '로그인',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 회원가입, 아이디/비밀번호 찾기
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                // 회원가입 처리
                                context.push('/signup');
                              },
                              child: const Text(
                                '회원가입',
                                style: TextStyle(
                                  color: AppColor.font1,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    // 아이디 찾기
                                  },
                                  child: const Text(
                                    '아이디 찾기',
                                    style: TextStyle(
                                      color: AppColor.font1,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  width: 1,
                                  height: 8,
                                  color: AppColor.line1,
                                ),
                                InkWell(
                                  onTap: () {
                                    // 비밀번호 찾기
                                  },
                                  child: const Text(
                                    '비밀번호 찾기',
                                    style: TextStyle(
                                      color: AppColor.font1,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
