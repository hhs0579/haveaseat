import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ 추가

class login extends ConsumerStatefulWidget {
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      // 1) Firebase Auth 로그인
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 2) Firestore에서 role/approved 조회
      final uid = cred.user!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = doc.data();
      final role = (data?['role'] as String?) ?? 'user';
      final approved = (data?['approved'] as bool?) ?? false;

      if (!mounted) return;

      // 3) 분기
      if (role == 'admin') {
        context.go('/admin');
      } else if (approved) {
        context.go('/main');
      } else {
        // 승인 대기 안내
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('승인 대기'),
            content: const Text('관리자의 승인을 받으세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        desktop: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100, top: 100),
                    child: Form(
                      key: _formKey,
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
                            '관리자 로그인', // 필요 시 '로그인'으로 변경 가능
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
                                  '이메일',
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    errorStyle: const TextStyle(height: 0),
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
                                  obscureText: true,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return '비밀번호를 입력해주세요';
                                    }
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
                                    errorStyle: TextStyle(height: 0),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _signIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColor.main,
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
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/signup'),
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
                                          onTap: () => context.go('/find-id'),
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
                                          onTap: () =>
                                              context.go('/find-password'),
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
            ),
          ],
        ),
      ),
    );
  }
}
