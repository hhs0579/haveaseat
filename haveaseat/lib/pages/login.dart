import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

class login extends ConsumerStatefulWidget {
  // StatelessWidget에서 ConsumerStatefulWidget으로 변경
  const login({super.key});

  @override
  ConsumerState<login> createState() => _loginState();
}

class _loginState extends ConsumerState<login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (context.mounted) {
          context.go('/main'); // 로그인 성공 시 메인 페이지로 이동
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = '';

        switch (e.code) {
          case 'user-not-found':
            errorMessage = '등록되지 않은 이메일입니다.';
            break;
          case 'wrong-password':
            errorMessage = '잘못된 비밀번호입니다.';
            break;
          case 'invalid-email':
            errorMessage = '유효하지 않은 이메일 형식입니다.';
            break;
          default:
            errorMessage = '로그인에 실패했습니다: ${e.message}';
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ResponsiveLayout(
            mobile: const SingleChildScrollView(),
            desktop: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100, top: 100),
                  child: Form(
                      // Form 위젯 추가
                      key: _formKey,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ... 로고와 타이틀 부분은 동일
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
                            SizedBox(
                              width: 360,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '이메일', // '아이디' 대신 '이메일'로 변경
                                    style: TextStyle(
                                      color: AppColor.font1,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _emailController,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return '이메일을 입력해주세요';
                                      }
                                      if (!value!.contains('@')) {
                                        return '올바른 이메일 형식이 아닙니다';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      hintText: '이메일을 입력해 주세요',
                                      hintStyle: const TextStyle(
                                        color: AppColor.font2,
                                        fontSize: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: AppColor.line1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: AppColor.line1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: AppColor.line1),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      errorStyle: const TextStyle(
                                          height: 0), // 에러 메시지 공간 제거
                                      // 또는
                                      // errorStyle: const TextStyle(
                                      //   height: 0.5,
                                      //   fontSize: 12,
                                      // ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    '비밀번호',
                                    style: TextStyle(
                                      color: AppColor.font1,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true, // 패스워드 숨김 처리
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return '비밀번호를 입력해주세요';
                                      }
                                      // 필요한 경우 비밀번호 유효성 검사 추가
                                      // 예: 최소 길이, 특수문자 포함 등
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: '비밀번호를 입력해 주세요',
                                      hintStyle: TextStyle(
                                        color: AppColor.font2,
                                        fontSize: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: AppColor.line1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: AppColor.line1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: AppColor.line1),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      errorStyle:
                                          TextStyle(height: 0), // 에러 메시지 공간 제거
                                      // 또는
                                      // errorStyle: const TextStyle(
                                      //   height: 0.5,
                                      //   fontSize: 12,
                                      // ),
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _signIn,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColor.primary,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(4)),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              '로그인',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  // ... 나머지 UI 부분 동일
                                  const SizedBox(height: 16),
                                  // 회원가입, 아이디/비밀번호 찾기
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            // 회원가입 처리
                                            context.go('/signup');
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
                                              margin:
                                                  const EdgeInsets.symmetric(
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
                                      ]),
                                ],
                              ),
                            ),
                          ])),
                ),
              ),
            )));
  }
}
