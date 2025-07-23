import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/pages/estimate/editpage.dart';
import 'package:haveaseat/pages/estimate/mainest.dart';
import 'package:haveaseat/pages/estimate/order.dart';
import 'package:haveaseat/pages/estimate/released.dart';
import 'package:haveaseat/pages/info/%20furniture.dart';
import 'package:haveaseat/pages/info/addcustomer.dart';
import 'package:haveaseat/pages/allcustomer.dart';
import 'package:haveaseat/pages/customer.dart';
import 'package:haveaseat/pages/info/estimate.dart';
import 'package:haveaseat/pages/login/findlogin.dart';
import 'package:haveaseat/pages/login/findpassword.dart';
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
      final isFindIdRoute = state.fullPath == '/find-id'; // 추가
      final isFindPasswordRoute = state.fullPath == '/find-password'; // 추가

      if (!isLoggedIn) {
        if (isLoginRoute ||
            isSignUpRoute ||
            isFindIdRoute ||
            isFindPasswordRoute) {
          return null;
        }
        return '/login';
      }

      if (isLoggedIn &&
          (isLoginRoute ||
              isSignUpRoute ||
              isFindIdRoute ||
              isFindPasswordRoute)) {
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
        path: '/find-id', // 추가
        builder: (context, state) => const FindIdPage(),
      ),
      GoRoute(
        path: '/find-password', // 추가
        builder: (context, state) => const FindPasswordPage(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainPage(),
        routes: [
          GoRoute(
            path: 'addpage',
            builder: (context, state) => const addCustomerPage(),
            routes: [
              // 임시저장 이어쓰기: addcustomer부터 시작
              GoRoute(
                path: 'addcustomer/:customerId/:estimateId',
                builder: (context, state) {
                  final customerId = state.pathParameters['customerId']!;
                  final estimateId = state.pathParameters['estimateId']!;
                  final name = state.extra != null &&
                          state.extra is Map &&
                          (state.extra as Map).containsKey('name')
                      ? (state.extra as Map)['name'] as String
                      : null;
                  return addCustomerPage(
                    customerId: customerId,
                    estimateId: estimateId,
                    name: name,
                  );
                },
              ),
              // 기존: /main/addpage/spaceadd/:customerId
              GoRoute(
                path: 'spaceadd/:customerId',
                name: 'mainSpaceAdd',
                builder: (context, state) {
                  final customerId = state.pathParameters['customerId']!;
                  return SpaceAddPage(customerId: customerId);
                },
                routes: [
                  GoRoute(
                    path: 'space-detail',
                    name: 'mainSpaceDetail',
                    builder: (context, state) {
                      final customerId = state.pathParameters['customerId']!;
                      return SpaceDetailPage(customerId: customerId);
                    },
                    routes: [
                      GoRoute(
                        path: 'furniture',
                        name: 'furniture',
                        builder: (context, state) {
                          final customerId =
                              state.pathParameters['customerId']!;
                          return furniturePage(customerId: customerId);
                        },
                        routes: [
                          GoRoute(
                            path: 'estimate',
                            name: 'estimate',
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
              // 추가: /main/addpage/spaceadd/:customerId/:estimateId 이하 경로 (임시저장 이어쓰기)
              GoRoute(
                path: 'spaceadd/:customerId/:estimateId',
                builder: (context, state) {
                  final customerId = state.pathParameters['customerId']!;
                  final estimateId = state.pathParameters['estimateId']!;
                  final name = state.extra != null &&
                          state.extra is Map &&
                          (state.extra as Map).containsKey('name')
                      ? (state.extra as Map)['name'] as String
                      : null;
                  return SpaceAddPage(
                      customerId: customerId,
                      estimateId: estimateId,
                      name: name);
                },
                routes: [
                  GoRoute(
                    path: 'space-detail',
                    builder: (context, state) {
                      final customerId = state.pathParameters['customerId']!;
                      final estimateId = state.pathParameters['estimateId']!;
                      final name = state.extra != null &&
                              state.extra is Map &&
                              (state.extra as Map).containsKey('name')
                          ? (state.extra as Map)['name'] as String
                          : null;
                      return SpaceDetailPage(
                          customerId: customerId,
                          estimateId: estimateId,
                          name: name);
                    },
                    routes: [
                      GoRoute(
                        path: 'furniture',
                        builder: (context, state) {
                          final customerId =
                              state.pathParameters['customerId']!;
                          final estimateId =
                              state.pathParameters['estimateId']!;
                          final name = state.extra != null &&
                                  state.extra is Map &&
                                  (state.extra as Map).containsKey('name')
                              ? (state.extra as Map)['name'] as String
                              : null;
                          return furniturePage(
                              customerId: customerId,
                              estimateId: estimateId,
                              name: name);
                        },
                        routes: [
                          GoRoute(
                            path: 'estimate',
                            builder: (context, state) {
                              final customerId =
                                  state.pathParameters['customerId']!;
                              final estimateId =
                                  state.pathParameters['estimateId']!;
                              final name = state.extra != null &&
                                      state.extra is Map &&
                                      (state.extra as Map).containsKey('name')
                                  ? (state.extra as Map)['name'] as String
                                  : null;
                              return EstimatePage(
                                  customerId: customerId,
                                  estimateId: estimateId,
                                  name: name);
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
            routes: [
              // 고객 정보 수정 라우트 추가
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final customerId = state.pathParameters['id']!;
                  return addCustomerPage(
                    customerId: customerId,
                    isEditMode: true,
                  );
                },
              ),
              GoRoute(
                path: 'estimate/:estimateId',
                builder: (context, state) => CustomerEstimatePage(
                  customerId: state.pathParameters['id']!,
                  estimateId: state.pathParameters['estimateId']!,
                ),
              ),
              GoRoute(
                path: 'estimate/:estimateId/order',
                builder: (context, state) => OrderEstimatePage(
                  customerId: state.pathParameters['id']!,
                  estimateId: state.pathParameters['estimateId']!,
                ),
              ),
              GoRoute(
                path: 'estimate/:estimateId/release',
                builder: (context, state) => ReleaseEstimatePage(
                  customerId: state.pathParameters['id']!,
                  estimateId: state.pathParameters['estimateId']!,
                ),
              ),
              // ✅ 기존 견적 편집을 위한 플로우 (estimateId 포함)
              GoRoute(
                path: 'estimate/:estimateId/edit',
                builder: (context, state) {
                  final customerId = state.pathParameters['id']!;
                  final estimateId = state.pathParameters['estimateId']!;
                  return SpaceAddPage(
                      customerId: customerId, estimateId: estimateId);
                },
                routes: [
                  // 공간 기본 정보 수정
                  GoRoute(
                    path: 'space-basic',
                    builder: (context, state) {
                      final customerId = state.pathParameters['id']!;
                      final estimateId = state.pathParameters['estimateId']!;
                      return SpaceAddPage(
                          customerId: customerId, estimateId: estimateId);
                    },
                    routes: [
                      // 공간 상세 정보 수정으로 연결
                      GoRoute(
                        path: 'space-detail',
                        builder: (context, state) {
                          final customerId = state.pathParameters['id']!;
                          final estimateId =
                              state.pathParameters['estimateId']!;
                          return SpaceDetailPage(
                              customerId: customerId, estimateId: estimateId);
                        },
                      ),
                    ],
                  ),
                  // 공간 상세 정보 수정 (직접 접근용)
                  GoRoute(
                    path: 'space-detail',
                    builder: (context, state) {
                      final customerId = state.pathParameters['id']!;
                      final estimateId = state.pathParameters['estimateId']!;
                      return SpaceDetailPage(
                          customerId: customerId, estimateId: estimateId);
                    },
                    routes: [
                      GoRoute(
                        path: 'furniture',
                        builder: (context, state) {
                          final customerId = state.pathParameters['id']!;
                          final estimateId =
                              state.pathParameters['estimateId']!;
                          return furniturePage(
                              customerId: customerId, estimateId: estimateId);
                        },
                        routes: [
                          GoRoute(
                            path: 'estimate',
                            builder: (context, state) {
                              final customerId = state.pathParameters['id']!;
                              final estimateId =
                                  state.pathParameters['estimateId']!;
                              return EstimatePage(
                                  customerId: customerId,
                                  estimateId: estimateId);
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
                name: 'allCustomersSpaceAdd',
                builder: (context, state) {
                  final customerId = state.pathParameters['customerId']!;
                  return SpaceAddPage(customerId: customerId);
                },
                routes: [
                  GoRoute(
                    path: 'space-detail',
                    name: 'allCustomersSpaceDetail',
                    builder: (context, state) {
                      final customerId = state.pathParameters['customerId']!;
                      return SpaceDetailPage(customerId: customerId);
                    },
                    routes: [
                      GoRoute(
                        path: 'furniture',
                        name: 'allCustomerfurniture',
                        builder: (context, state) {
                          final customerId =
                              state.pathParameters['customerId']!;
                          return furniturePage(customerId: customerId);
                        },
                        routes: [
                          GoRoute(
                            path: 'estimate',
                            name: 'allCustomerestimate',
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
