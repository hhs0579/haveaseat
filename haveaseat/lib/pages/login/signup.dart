import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haveaseat/riverpod/signupmodel.dart';
import 'package:go_router/go_router.dart';
import 'package:haveaseat/widget/department.dart';
import 'package:haveaseat/widget/position.dart';
import 'package:firebase_auth/firebase_auth.dart';

class signUp extends ConsumerWidget {
  signUp({super.key});

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  // final _selectedRole = StateProvider<String?>((ref) => null);
  final _emailValidationMessage = StateProvider<String?>((ref) => null);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // StateProvider 추가 (클래스 최상단에)
    final emailValidationMessage = ref.watch(_emailValidationMessage);
// build 메서드 내에서 상태 읽기 추가

    // 회원가입 상태 감시
    final signUpState = ref.watch(signUpNotifierProvider);
    // final selectedRole = ref.watch(_selectedRole);

    // final selectedDepartment = ref.watch(departmentProvider); // 부서 선택 상태
    // final selectedPosition = ref.watch(positionProvider); // 직급 선택 상태
    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 100),
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
                      '관리자 회원가입',
                      style: TextStyle(
                        color: AppColor.font1,
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 이름 입력
                          const Text('이름',
                              style: TextStyle(
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              )),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return '이름을 입력해주세요';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              hintText: '이름을 입력해 주세요',
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
                              errorStyle: TextStyle(height: 0), // 에러 메시지 공간 제거
                              // 또는
                              // errorStyle: const TextStyle(
                              //   height: 0.5,
                              //   fontSize: 12,
                              // ),
                            ),
                          ),

                          // 역할 선택
                          // const SizedBox(height: 20),
                          // const Text('사원정보',
                          //     style: TextStyle(
                          //       color: AppColor.font1,
                          //       fontWeight: FontWeight.w600,
                          //       fontSize: 14,
                          //     )),
                          // const SizedBox(
                          //   height: 12,
                          // ),
                          // Container(
                          //   decoration: BoxDecoration(
                          //     border: Border.all(color: AppColor.line1),
                          //     borderRadius: BorderRadius.circular(4),
                          //   ),
                          //   child: const Column(
                          //     children: [
                          //       DepartmentSelector(),
                          //     ],
                          //   ),
                          // ),
                          // const SizedBox(
                          //   height: 12,
                          // ),
                          // Container(
                          //   decoration: BoxDecoration(
                          //     border: Border.all(color: AppColor.line1),
                          //     borderRadius: BorderRadius.circular(4),
                          //   ),
                          //   child: const Column(
                          //     children: [
                          //       PositionSelector(),
                          //     ],
                          //   ),
                          // ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text('이메일',
                              style: TextStyle(
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              )),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _emailController,
                                        validator: (value) {
                                          if (value?.isEmpty ?? true) {
                                            return '이메일을 입력해주세요';
                                          }
                                          if (!value!.contains('@')) {
                                            return '올바른 이메일 형식이 아닙니다';
                                          }
                                          if (!ref.read(emailCheckProvider)) {
                                            return '이메일 중복 확인이 필요합니다';
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
                                          errorStyle: const TextStyle(
                                              height: 0), // 에러 메시지 공간 제거
                                          // 또는
                                          // errorStyle: const TextStyle(
                                          //   height: 0.5,
                                          //   fontSize: 12,
                                          // ),
                                        ),
                                        onChanged: (value) {
                                          ref
                                              .read(emailCheckProvider.notifier)
                                              .state = false;
                                          ref
                                              .read(_emailValidationMessage
                                                  .notifier)
                                              .state = null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12), // 간격 조정
                                    InkWell(
                                      onTap: () async {
                                        if (_emailController.text.isEmpty) {
                                          ref
                                              .read(_emailValidationMessage
                                                  .notifier)
                                              .state = '이메일을 입력해주세요';
                                          return;
                                        }
                                        if (!_emailController.text
                                            .contains('@')) {
                                          ref
                                              .read(_emailValidationMessage
                                                  .notifier)
                                              .state = '올바른 이메일 형식이 아닙니다';
                                          return;
                                        }

                                        try {
                                          final exists = await ref
                                              .read(emailCheckProvider.notifier)
                                              .checkEmailExists(
                                                  _emailController.text);

                                          if (exists) {
                                            ref
                                                .read(_emailValidationMessage
                                                    .notifier)
                                                .state = '이미 등록된 이메일입니다';
                                          } else {
                                            ref
                                                .read(_emailValidationMessage
                                                    .notifier)
                                                .state = '사용 가능한 이메일입니다';
                                            ref
                                                .read(
                                                    emailCheckProvider.notifier)
                                                .state = true;
                                          }
                                        } catch (e) {
                                          ref
                                              .read(_emailValidationMessage
                                                  .notifier)
                                              .state = '이메일 확인 중 오류가 발생했습니다';
                                        }
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        padding: EdgeInsets.zero,
                                        width: 87, // 버튼 너비 고정
                                        height: 48, // TextFormField와 동일한 높이
                                        decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            border: Border.all(
                                                color: AppColor.font1,
                                                width: 1),
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(4))),

                                        child: const Text(
                                          '중복확인',
                                          style: TextStyle(
                                            color: AppColor.font1,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (emailValidationMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    emailValidationMessage,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: emailValidationMessage ==
                                              '사용 가능한 이메일입니다'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // ... 비밀번호 입력 필드 ...
                          const SizedBox(height: 20),
                          const Text('비밀번호',
                              style: TextStyle(
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              )),
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
                              errorStyle: TextStyle(height: 0), // 에러 메시지 공간 제거
                              // 또는
                              // errorStyle: const TextStyle(
                              //   height: 0.5,
                              //   fontSize: 12,
                              // ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('휴대폰 번호',
                              style: TextStyle(
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              )),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return '휴대폰 번호를 입력해주세요';
                              }
                              // Simple Korean phone number validation
                              final phoneRegExp =
                                  RegExp(r'^010-?([0-9]{4})-?([0-9]{4})$');
                              if (!phoneRegExp.hasMatch(value!)) {
                                return '올바른 휴대폰 번호 형식이 아닙니다';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              hintText: '휴대폰 번호를 입력해 주세요',
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
                              errorStyle: TextStyle(height: 0),
                            ),
                          ),
                          const SizedBox(height: 36),
                          // 회원가입 버튼
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: signUpState.isLoading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        try {
                                          await ref
                                              .read(signUpNotifierProvider
                                                  .notifier)
                                              .signUp(
                                                email: _emailController.text,
                                                password:
                                                    _passwordController.text,
                                                name: _nameController.text,
                                                phoneNumber:
                                                    _phoneController.text,
                                              );

                                          if (context.mounted) {
                                            context.go('/login');
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text('회원가입 실패: $e')),
                                            );
                                          }
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColor.primary,
                                shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4)),
                                ),
                              ),
                              child: signUpState.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('회원가입 완료',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      )),
                            ),
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
    );
  }
}
