import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FindIdPage extends ConsumerStatefulWidget {
  const FindIdPage({super.key});

  @override
  ConsumerState<FindIdPage> createState() => _FindIdPageState();
}

class _FindIdPageState extends ConsumerState<FindIdPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _foundEmail;

  // Firestore에서 이름과 전화번호로 사용자 검색
  Future<void> _findId() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _foundEmail = null;
      });

      try {
        // Firestore에서 name과 phoneNumber로 사용자 검색
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users') // 컬렉션 이름을 실제 사용하는 이름으로 변경하세요
            .where('name', isEqualTo: _nameController.text.trim())
            .where('phoneNumber', isEqualTo: _phoneController.text.trim())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // 사용자를 찾았을 경우
          final userData = querySnapshot.docs.first.data();
          final email = userData['email'] as String;

          // 이메일 마스킹 처리
          final maskedEmail = _maskEmail(email);

          setState(() {
            _foundEmail = maskedEmail;
          });
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

  // 이메일 마스킹 함수
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final localPart = parts[0];
    final domain = parts[1];

    String maskedLocal;
    if (localPart.length <= 2) {
      maskedLocal = localPart;
    } else if (localPart.length <= 4) {
      maskedLocal =
          '${localPart.substring(0, 1)}${'*' * (localPart.length - 1)}';
    } else {
      maskedLocal =
          '${localPart.substring(0, 2)}${'*' * (localPart.length - 4)}${localPart.substring(localPart.length - 2)}';
    }

    return '$maskedLocal@$domain';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('아이디 찾기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100, top: 50),
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
                      '아이디 찾기',
                      style: TextStyle(
                        color: AppColor.font1,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '회원가입 시 입력한 정보를 입력해주세요',
                      style: TextStyle(
                        color: AppColor.font2,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_foundEmail != null) ...[
                      Container(
                        width: 360,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '아이디를 찾았습니다!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => context.go('/login'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColor.primary,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(4)),
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
                                onPressed: () => context.go('/find-password'),
                                style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: AppColor.primary),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(4)),
                                  ),
                                ),
                                child: const Text(
                                  '비밀번호 찾기',
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
                    ] else ...[
                      SizedBox(
                        width: 360,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColor.line1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColor.line1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColor.line1),
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
                                if (!RegExp(r'^\d{10,11}$').hasMatch(value!)) {
                                  return '올바른 전화번호를 입력해주세요 (10-11자리 숫자)';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: '01012345678',
                                hintStyle: const TextStyle(
                                  color: AppColor.font2,
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColor.line1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColor.line1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColor.line1),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
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
                                onPressed: _isLoading ? null : _findId,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColor.primary,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(4)),
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
                                        '아이디 찾기',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
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
    );
  }
}
