import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flow_engine.dart';

/// Local-first seed store. Uses the app's existing SharedPreferences dependency.
/// No existing Firestore product or stock documents are rewritten.
class FlowTemplateStore {
  static const _seedKey = 'flow_seed_templates_v1';
  static const _selectedKey = 'flow_selected_business_v1';

  Future<List<FlowTemplate>> load() async {
    final prefs = await SharedPreferences.getInstance();
    var encoded = prefs.getString(_seedKey);
    if (encoded == null) {
      encoded = await rootBundle.loadString('assets/flows/business_templates_v1.json');
      await prefs.setString(_seedKey, encoded);
    }
    final raw = jsonDecode(encoded) as Map<String, dynamic>;
    return (raw['templates'] as List)
        .map((item) => FlowTemplate.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<String> selectedBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey) ?? 'other';
  }

  Future<void> chooseBusiness(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, type);
  }

  Future<FlowTemplate> active(String type) async {
    final templates = await load();
    final business = await selectedBusiness();
    return templates.firstWhere(
      (template) => template.type == type && template.businessType == business,
      orElse: () => templates.firstWhere(
        (template) => template.type == type && template.businessType == 'other',
      ),
    );
  }

  /// Store a draft locally. Publishing is intentionally explicit.
  Future<void> saveDraft(FlowTemplate draft) async {
    if (FlowEngine(draft).validate().isNotEmpty) {
      throw StateError(FlowEngine(draft).validate().join(' '));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flow_draft_${draft.id}', jsonEncode(draft.toJson()));
  }
}
