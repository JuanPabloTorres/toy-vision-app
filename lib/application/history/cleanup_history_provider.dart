import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/progress_repository.dart';
import '../progress/complete_cleanup_session_use_case.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  throw StateError(
    'ProgressRepository must be installed at application startup',
  );
});

final completeCleanupSessionUseCaseProvider =
    Provider<CompleteCleanupSessionUseCase>(
  (ref) => CompleteCleanupSessionUseCase(
    ref.watch(progressRepositoryProvider),
  ),
);
