import 'package:get_it/get_it.dart';
import 'core/database/database_helper.dart';
import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/services/i_speech_service.dart';
import 'core/services/speech_service_impl.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/i_auth_repository.dart';
import 'features/auth/domain/usecases/login_as_guest_usecase.dart';
import 'features/auth/domain/usecases/check_user_status_usecase.dart';
import 'features/auth/presentation/state/auth_cubit.dart';
import 'features/chat/data/datasources/chat_remote_datasource.dart';
import 'features/chat/data/datasources/chat_local_datasource.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/chat/domain/repositories/i_chat_repository.dart';
import 'features/chat/domain/usecases/create_new_chat_usecase.dart';
import 'features/chat/domain/usecases/delete_chat_usecase.dart';
import 'features/chat/domain/usecases/get_amplitude_stream_usecase.dart';
import 'features/chat/domain/usecases/get_chat_messages_usecase.dart';
import 'features/chat/domain/usecases/get_history_chats_usecase.dart';
import 'features/chat/domain/usecases/process_audio_recording_usecase.dart';
import 'features/chat/domain/usecases/send_message_usecase.dart';
import 'features/chat/domain/usecases/start_recording_usecase.dart';
import 'features/chat/presentation/state/chat_cubit.dart';
import 'features/memory/data/repositories/user_facts_repository_impl.dart';
import 'features/memory/domain/repositories/i_user_facts_repository.dart';
import 'features/memory/domain/usecases/fetch_user_facts_usecase.dart';
import 'features/memory/domain/usecases/save_user_fact_usecase.dart';
import 'features/splash/presentation/states/splash_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core Services
  sl.registerLazySingleton<ISpeechService>(() => SpeechServiceImpl());
  sl.registerLazySingleton(() => DatabaseHelper());
  sl.registerLazySingleton<INetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton(() => ApiClient());

  // Features - Auth
  sl.registerFactory(() => AuthCubit(loginAsGuestUseCase: sl()));
  sl.registerLazySingleton(() => LoginAsGuestUseCase(sl()));
  sl.registerLazySingleton(() => CheckUserStatusUseCase(sl()));
  sl.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<IAuthRemoteDataSource>(
    () => MockAuthRemoteDataSource(),
  );

  // Features - Chat
  sl.registerFactory(
    () => ChatCubit(
      sendMessageUseCase: sl(),
      getHistoryChatsUseCase: sl(),
      getChatMessagesUseCase: sl(),
      createNewChatUseCase: sl(),
      deleteChatUseCase: sl(),
      startRecordingUseCase: sl(),
      processAudioRecordingUseCase: sl(),
      getAmplitudeStreamUseCase: sl(),
      saveUserFactUseCase: sl(),
      fetchUserFactsUseCase: sl(),
    ),
  );

  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => GetHistoryChatsUseCase(sl()));
  sl.registerLazySingleton(() => GetChatMessagesUseCase(sl()));
  sl.registerLazySingleton(() => CreateNewChatUseCase(sl()));
  sl.registerLazySingleton(() => DeleteChatUseCase(sl()));
  sl.registerLazySingleton(() => StartRecordingUseCase(sl()));
  sl.registerLazySingleton(() => ProcessAudioRecordingUseCase(sl()));
  sl.registerLazySingleton(() => GetAmplitudeStreamUseCase(sl()));

  sl.registerLazySingleton<IChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<IChatRemoteDataSource>(
    () => GeminiRemoteDataSource(),
  );
  sl.registerLazySingleton<IChatLocalDataSource>(
    () => ChatLocalDataSourceImpl(databaseHelper: sl()),
  );

  // Features - Memory
  sl.registerLazySingleton<IUserFactsRepository>(
    () => UserFactsRepositoryImpl(databaseHelper: sl()),
  );
  sl.registerLazySingleton(() => SaveUserFactUseCase(sl()));
  sl.registerLazySingleton(() => FetchUserFactsUseCase(sl()));

  // Features - Splash
  sl.registerFactory(() => SplashCubit(checkUserStatusUseCase: sl()));
}
