import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Codes include an installation segment and a random suffix to avoid
/// count()+1 collisions when devices create records while disconnected.
class ProductIdRule {
  final String prefix;
  final int runningLength;
  final List<String> tokens;

  const ProductIdRule({
    this.prefix = 'PRD',
    this.runningLength = 4,
    this.tokens = const ['prefix', 'category', 'running', 'device', 'unique'],
  });

  String preview({
    required String category,
    required int running,
    required String device,
    required String unique,
    String size = '',
    String color = '',
    String branch = '',
    DateTime? date,
  }) {
    final day = date ?? DateTime.now();
    final dateCode =
        '${day.year.toString().substring(2)}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final values = {
      'prefix': prefix,
      'category': category.toUpperCase(),
      'running': running.toString().padLeft(runningLength, '0'),
      'device': device.toUpperCase(),
      'unique': unique.toUpperCase(),
      'size': size.toUpperCase(),
      'color': color.toUpperCase(),
      'branch': branch.toUpperCase(),
      'date': dateCode,
    };
    final parts = tokens.map((key) => values[key] ?? '').where((p) => p.isNotEmpty).toList();
    // Required safety suffix survives user customization of the visible tokens.
    if (!tokens.contains('device')) parts.add(device.toUpperCase());
    if (!tokens.contains('unique')) parts.add(unique.toUpperCase());
    return parts.join('-');
  }
}

class OfflineProductCodeService {
  static const _deviceKey = 'flow_device_segment_v1';
  static const _counterKey = 'flow_product_counter_v1';

  Future<String> next({required String category, ProductIdRule rule = const ProductIdRule()}) async {
    final prefs = await SharedPreferences.getInstance();
    var device = prefs.getString(_deviceKey);
    if (device == null) {
      device = const Uuid().v4().replaceAll('-', '').substring(0, 8);
      await prefs.setString(_deviceKey, device);
    }
    final counter = (prefs.getInt(_counterKey) ?? 0) + 1;
    await prefs.setInt(_counterKey, counter);
    return rule.preview(
      category: category,
      running: counter,
      device: device,
      unique: const Uuid().v4().replaceAll('-', '').substring(0, 8),
    );
  }
}
