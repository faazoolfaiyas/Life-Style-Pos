Future<void> logErrorToFile(Object error, StackTrace stack) async {
  // No-op on web
  print('Web Crash Log: $error');
}
