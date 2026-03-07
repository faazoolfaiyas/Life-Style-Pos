import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> logErrorToFile(Object error, StackTrace stack) async {
  try {
     final dir = await getApplicationDocumentsDirectory();
     final file = File('${dir.path}/crash_log.txt');
     final entry = '--- ${DateTime.now()} ---\nError: $error\nStack: $stack\n----------------\n';
     await file.writeAsString(entry, mode: FileMode.append);
  } catch (e) {
    print('Failed to write log: $e');
  }
}
