import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../injection_container.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/state/auth_cubit.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/state/chat_cubit.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<AuthCubit>(),
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<ChatCubit>(),
          child: const ChatScreen(),
        ),
      ),
    ],
  );
}
