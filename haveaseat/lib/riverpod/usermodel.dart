import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider {
  // 현재 로그인한 사용자의 Stream Provider
  static final currentUserProvider = StreamProvider<User?>((ref) {
    return FirebaseAuth.instance.authStateChanges().map((user) {
      print('Current User: ${user?.uid}'); // 로그 추가
      return user;
    });
  });

  // 사용자 데이터 Stream Provider
  static final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
    final user = ref.watch(currentUserProvider).value;
    print('UserDataProvider - User: ${user?.uid}'); // 로그 추가

    if (user != null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
        print('Firestore Data: ${snapshot.data()}'); // 로그 추가
        return snapshot.data();
      });
    }

    print('No user logged in'); // 로그 추가
    return Stream.value(null);
  });

  // 사용자 이름 가져오기
  static String getUserName(Map<String, dynamic>? userData) {
    print('GetUserName Data: $userData'); // 로그 추가
    return userData?['name'] ?? '이름 없음';
  }

  // 사용자 부서 가져오기
  static String getDepartment(Map<String, dynamic>? userData) {
    print('GetDepartment Data: $userData'); // 로그 추가
    return userData?['department'] ?? '부서 없음';
  }

  // 사용자 데이터 직접 가져오기 메서드 추가
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      print('Direct Fetch Data: ${doc.data()}'); // 로그 추가
      return doc.data();
    } catch (e) {
      print('Error fetching user data: $e'); // 로그 추가
      return null;
    }
  }
}

// Provider 사용 시 에러 캐치를 위한 래퍼 추가
final userDataErrorHandlingProvider = Provider<Map<String, dynamic>?>((ref) {
  final userDataAsync = ref.watch(UserProvider.userDataProvider);

  return userDataAsync.when(
    data: (data) {
      print('Data from Provider: $data'); // 로그 추가
      return data;
    },
    loading: () {
      print('Loading user data...'); // 로그 추가
      return null;
    },
    error: (error, stack) {
      print('Error in Provider: $error'); // 로그 추가
      return null;
    },
  );
});
