import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/pages/login.dart';
import 'package:haveaseat/pages/mainpage.dart';
import 'package:haveaseat/pages/signup.dart';
import 'package:shared_preferences/shared_preferences.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routerNeglect: false,
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isLoginRoute = state.fullPath == '/login';
      final isSignUpRoute = state.fullPath == '/signup';

      if (!isLoggedIn) {
        if (isLoginRoute || isSignUpRoute) {
          return null;
        }
        return '/login';
      }

      if (isLoggedIn && (isLoginRoute || isSignUpRoute)) {
        return '/main';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const login(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => signUp(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainPage(),
      ),
    ],
    errorBuilder: (context, state) => const login(),
  );
});

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final router = ref.watch(routerProvider);
      return MaterialApp.router(
        routerConfig: router,
        title: 'Have a Seat',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
      );
    });
  }
}
