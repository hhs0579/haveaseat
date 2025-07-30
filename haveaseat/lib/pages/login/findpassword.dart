import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FindPasswordPage extends ConsumerStatefulWidget {
  const FindPasswordPage({super.key});

  @override
  ConsumerState<FindPasswordPage> createState() => _FindPasswordPageState();
}

class _FindPasswordPageState extends ConsumerState<FindPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _foundEmail;

  Future<void> _findPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _emailSent = false;
        _foundEmail = null;
      });

      try {
        // Firestore에서 email, name, phoneNumber로 사용자 검색
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _emailController.text.trim())
            .where('name', isEqualTo: _nameController.text.trim())
            .where('phoneNumber', isEqualTo: _phoneController.text.trim())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // 사용자를 찾았을 경우
          final userData = querySnapshot.docs.first.data();
          final email = userData['email'] as String;

          // 비밀번호 재설정 이메일 전송
          await FirebaseAuth.instance.sendPasswordResetEmail(
            email: email,
          );

          setState(() {
            _emailSent = true;
            _foundEmail = email;
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('비밀번호 재설정 이메일이 전송되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // 사용자를 찾지 못했을 경우
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('입력하신 정보와 일치하는 계정을 찾을 수 없습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = '';

        switch (e.code) {
          case 'user-not-found':
            errorMessage = '등록되지 않은 이메일입니다.';
            break;
          case 'invalid-email':
            errorMessage = '유효하지 않은 이메일 형식입니다.';
            break;
          case 'too-many-requests':
            errorMessage = '너무 많은 요청을 보냈습니다. 잠시 후 다시 시도해주세요.';
            break;
          default:
            errorMessage = '오류가 발생했습니다: ${e.message}';
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
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
    _nameController.dispose();
    _phoneController.dispose();
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
                    padding: const EdgeInsets.only(bottom: 100, top: 50),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/'),
                            child: SizedBox(
                              width: 249,
                              height: 31,
                              child: Image.asset('assets/images/logo.png'),
                            ),
                          ),
                          const SizedBox(height: 56),
                          const Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              color: AppColor.font1,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _emailSent ? '이메일을 확인해주세요' : '등록된 정보를 입력해주세요',
                            style: const TextStyle(
                              color: AppColor.font2,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (_emailSent) ...[
                            Center(
                              child: Container(
                                width: 360,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.email,
                                      color: Colors.blue,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      '이메일을 전송했습니다!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _foundEmail!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColor.font1,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '이메일을 확인하고 비밀번호를 재설정해주세요.\n스팸함도 확인해보세요.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColor.font2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: SizedBox(
                                width: 360,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed: () => context.go('/login'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColor.primary,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(4)),
                                            ),
                                          ),
                                          child: const Text(
                                            '로그인하기',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _emailSent = false;
                                              _emailController.clear();
                                              _nameController.clear();
                                              _phoneController.clear();
                                            });
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: AppColor.primary),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(4)),
                                            ),
                                          ),
                                          child: const Text(
                                            '다시 시도',
                                            style: TextStyle(
                                              color: AppColor.primary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Center(
                              child: SizedBox(
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
                                      keyboardType: TextInputType.emailAddress,
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
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        errorStyle: const TextStyle(height: 0),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      '이름',
                                      style: TextStyle(
                                        color: AppColor.font1,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _nameController,
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) {
                                          return '이름을 입력해주세요';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: '이름을 입력해 주세요',
                                        hintStyle: const TextStyle(
                                          color: AppColor.font2,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        errorStyle: const TextStyle(height: 0),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      '전화번호',
                                      style: TextStyle(
                                        color: AppColor.font1,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) {
                                          return '전화번호를 입력해주세요';
                                        }
                                        // 숫자만 입력 검증 (10-11자리)
                                        if (!RegExp(r'^\d{10,11}$')
                                            .hasMatch(value!)) {
                                          return '올바른 전화번호를 입력해주세요 (10-11자리 숫자)';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: '휴대폰 번호를 입력해주세요(-제외)',
                                        hintStyle: const TextStyle(
                                          color: AppColor.font2,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColor.line1),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        errorStyle: const TextStyle(height: 0),
                                      ),
                                    ),
                                    const SizedBox(height: 36),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _findPassword,
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
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                '비밀번호 찾기',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Center(
                                      child: InkWell(
                                        onTap: () => context.go('/find-id'),
                                        child: const Text(
                                          '아이디를 모르시나요?',
                                          style: TextStyle(
                                            color: AppColor.primary,
                                            fontSize: 14,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
