import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/pages/info/%20furniture.dart';
import 'package:haveaseat/pages/info/addcustomer.dart';
import 'package:haveaseat/pages/allcustomer.dart';
import 'package:haveaseat/pages/customer.dart';
import 'package:haveaseat/pages/info/estimate.dart';
import 'package:haveaseat/pages/login/login.dart';

import 'package:haveaseat/pages/mainpage.dart';
import 'package:haveaseat/pages/login/signup.dart';
import 'package:haveaseat/pages/info/spaceadd.dart';
import 'package:haveaseat/pages/info/spacedetail.dart';
import 'package:haveaseat/pages/tempsave.dart';
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
        routes: [
          GoRoute(
            path: 'addpage',
            builder: (context, state) => const addCustomerPage(),
            routes: [
              GoRoute(
                path: 'spaceadd/:customerId',
                name: 'mainSpaceAdd', // 이름 변경
                builder: (context, state) {
                  final customerId = state.pathParameters['customerId']!;
                  return SpaceAddPage(customerId: customerId);
                },
                routes: [
                  GoRoute(
                    path: 'space-detail',
                    name: 'mainSpaceDetail', // 이름 변경
                    builder: (context, state) {
                      final customerId = state.pathParameters['customerId']!;
                      return SpaceDetailPage(customerId: customerId);
                    },
                    routes: [
                      GoRoute(
                        path: 'furniture',
                        name: 'furniture', // 이름 변경
                        builder: (context, state) {
                          final customerId =
                              state.pathParameters['customerId']!;
                          return furniturePage(customerId: customerId);
                        },
                        routes: [
                          GoRoute(
                            path: 'estimate',
                            name: 'estimate', // 이름 변경
                            builder: (context, state) {
                              final customerId =
                                  state.pathParameters['customerId']!;
                              return EstimatePage(customerId: customerId);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'customer/:id',
            builder: (context, state) => CustomerDetailPage(
              customerId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/all-customers',
        builder: (context, state) => const AllCustomerPage(),
        routes: [
          GoRoute(
            path: 'addpage',
            builder: (context, state) => const addCustomerPage(),
            routes: [
              GoRoute(
                path: 'spaceadd/:customerId',
                name: 'allCustomersSpaceAdd', // 이름 변경
                builder: (context, state) {
                  final customerId = state.pathParameters['customerId']!;
                  return SpaceAddPage(customerId: customerId);
                },
                routes: [
                  GoRoute(
                    path: 'space-detail',
                    name: 'allCustomersSpaceDetail', // 이름 변경
                    builder: (context, state) {
                      final customerId = state.pathParameters['customerId']!;
                      return SpaceDetailPage(customerId: customerId);
                    },
                    routes: [
                      GoRoute(
                        path: 'furniture',
                        name: 'allCustomerfurniture', // 이름 변경
                        builder: (context, state) {
                          final customerId =
                              state.pathParameters['customerId']!;
                          return furniturePage(customerId: customerId);
                        },
                        routes: [
                          GoRoute(
                            path: 'estimate',
                            name: 'allCustomerestimate', // 이름 변경
                            builder: (context, state) {
                              final customerId =
                                  state.pathParameters['customerId']!;
                              return EstimatePage(customerId: customerId);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'customer/:id',
            builder: (context, state) => CustomerDetailPage(
              customerId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/temp',
        builder: (context, state) => const TempSavePage(),
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
