// lib/providers/user_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider {
  // 현재 로그인한 사용자의 Stream Provider
  static final currentUserProvider = StreamProvider<User?>((ref) {
    return FirebaseAuth.instance.authStateChanges();
  });

  // 사용자 데이터 Stream Provider
  static final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
    // 현재 로그인한 사용자 가져오기
    final user = ref.watch(currentUserProvider).value;
    
    if (user != null) {
      // Firestore에서 사용자 데이터 스트림 생성
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) => snapshot.data());
    }
    
    return Stream.value(null);
  });

  // 사용자 이름 가져오기
  static String getUserName(Map<String, dynamic>? userData) {
    return userData?['name'] ?? '이름 없음';
  }

  // 사용자 부서 가져오기
  static String getDepartment(Map<String, dynamic>? userData) {
    return userData?['department'] ?? '부서 없음';
  }
}