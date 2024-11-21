// lib/provider/auth_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }
  return Stream.value(null);
});
// 회원가입 상태 및 로직을 관리하는 provider
// signupmodel.dart

class SignUpNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  SignUpNotifier(this.ref) : super(const AsyncValue.data(null));
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    // required String department,
    // required String position,
  }) async {
    state = const AsyncValue.loading();
    try {
      // 1. Firebase Auth로 사용자 계정 생성
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Firestore에 추가 사용자 정보 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        // 'department': department,
        // 'position': position,
        'role': 'user', // 기본 역할 설정
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true, // 계정 활성화 상태
      });
      await FirebaseAuth.instance.signOut();

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}

final signUpNotifierProvider =
    StateNotifierProvider<SignUpNotifier, AsyncValue<void>>((ref) {
  return SignUpNotifier(ref);
});
// lib/provider/email_provider.dart

final emailCheckProvider = StateNotifierProvider<EmailCheckNotifier, bool>(
  (ref) => EmailCheckNotifier(),
);

class EmailCheckNotifier extends StateNotifier<bool> {
  EmailCheckNotifier() : super(false);

  Future<bool> checkEmailExists(String email) async {
    try {
      final methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      state = methods.isEmpty; // 사용 가능한 이메일이면 true
      return methods.isNotEmpty; // 이미 존재하는 이메일이면 true 반환
    } catch (e) {
      state = false;
      throw Exception('이메일 확인 중 오류가 발생했습니다');
    }
  }

  void reset() {
    state = false;
  }
}
