import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/router.dart';
import 'package:haveaseat/firebase_options.dart';

import 'package:haveaseat/components/behavior.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'), // 한국어
          Locale('en', 'US'), // 영어
        ],
        routerConfig: router,
        title: 'Have A Seat',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Pretendard',

          // 1) 전체 컬러 스킴: 씨드에 AppColor.main 사용 + 표면/배경 흰색으로 고정
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColor.main,
            brightness: Brightness.light,
          ).copyWith(
            background: Colors.white,
            surface: Colors.white,
            // 최신 플러터에선 colorScheme.surfaceTint가 적용됩니다.
            // 전역 틴트를 완전히 끄고 싶으면 각 위젯 테마에서 surfaceTintColor를 투명으로 지정(아래)하십시오.
          ),

          // 2) 다이얼로그/카드/바텀시트 등 M3 틴트 제거
          dialogTheme: const DialogTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: const CardTheme(
            surfaceTintColor: Colors.transparent,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),

          // 3) AppBar 색 통일
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColor.main,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),

          // 4) 입력/선택 관련(“타자 칠 때 대기 색깔” → 커서/선택/포커스)
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColor.main,
            selectionColor: AppColor.main.withOpacity(0.25),
            selectionHandleColor: AppColor.main,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColor.main),
            ),
          ),

          // 5) 로딩 인디케이터 색
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: AppColor.main,
          ),

          // 6) 리플/하이라이트(불필요한 색감 제거)
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,

          // 7) 페이지 전환은 기존 유지
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              for (final p in TargetPlatform.values) p: NoTransitionsBuilder(),
            },
          ),
        ),
        scrollBehavior: MyCustomScrollBehavior());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final lastRoute = prefs.getString('last_route');

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
