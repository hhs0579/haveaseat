import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';

class login extends StatelessWidget {
  const login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 249,
                  height: 31,
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(height: 25),
                const Text(
                  '관리자 로그인',
                  style: TextStyle(
                    color: AppColor.font1,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 40),
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
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: '아이디를 입력하세요',
                          hintStyle: const TextStyle(
                            color: AppColor.font2,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: AppColor.line1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppColor.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '비밀번호',
                        style: TextStyle(
                          color: AppColor.font1,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '비밀번호를 입력하세요',
                          hintStyle: const TextStyle(
                            color: AppColor.font2,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: AppColor.line1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppColor.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 로그인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            // 로그인 처리
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
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
                      const SizedBox(height: 20),
                      // 회원가입, 아이디/비밀번호 찾기
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              // 회원가입 처리
                            },
                            child: const Text(
                              '회원가입',
                              style: TextStyle(
                                color: AppColor.font2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 12,
                            color: AppColor.back1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          TextButton(
                            onPressed: () {
                              // 아이디 찾기
                            },
                            child: const Text(
                              '아이디 찾기',
                              style: TextStyle(
                                color: AppColor.font2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 12,
                            color: AppColor.line1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          TextButton(
                            onPressed: () {
                              // 비밀번호 찾기
                            },
                            child: const Text(
                              '비밀번호 찾기',
                              style: TextStyle(
                                color: AppColor.font2,
                                fontSize: 12,
                              ),
                            ),
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
    );
  }
}
