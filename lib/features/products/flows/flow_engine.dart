import 'dart:collection';

/// Pure Dart representation of a versioned flow; independent of Flutter/UI.
class FlowNode {
  final String id;
  final String kind;
  final String? fieldKey;
  final Map<String, String> label;
  final bool required;
  final bool locked;
  final Map<String, dynamic> config;
  final String? next;
  final Map<String, String> branches;

  const FlowNode({
    required this.id,
    required this.kind,
    this.fieldKey,
    this.label = const {},
    this.required = false,
    this.locked = false,
    this.config = const {},
    this.next,
    this.branches = const {},
  });

  factory FlowNode.fromJson(Map<String, dynamic> data) => FlowNode(
        id: data['id'] as String,
        kind: data['kind'] as String,
        fieldKey: data['fieldKey'] as String?,
        label: (data['label'] as Map? ?? {})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
        required: data['required'] == true,
        locked: data['locked'] == true,
        config: Map<String, dynamic>.from(data['config'] as Map? ?? {}),
        next: data['next'] as String?,
        branches: (data['branches'] as Map? ?? {})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (fieldKey != null) 'fieldKey': fieldKey,
        'label': label,
        'required': required,
        'locked': locked,
        'config': config,
        if (next != null) 'next': next,
        if (branches.isNotEmpty) 'branches': branches,
      };

  String text(String locale) => label[locale] ?? label['en'] ?? fieldKey ?? id;
}

class FlowTemplate {
  final String id;
  final String type;
  final String businessType;
  final int version;
  final String status;
  final List<FlowNode> nodes;

  const FlowTemplate({
    required this.id,
    required this.type,
    required this.businessType,
    required this.version,
    required this.status,
    required this.nodes,
  });

  factory FlowTemplate.fromJson(Map<String, dynamic> data) => FlowTemplate(
        id: data['id'] as String,
        type: data['type'] as String,
        businessType: data['businessType'] as String? ?? 'other',
        version: (data['version'] as num?)?.toInt() ?? 1,
        status: data['status'] as String? ?? 'published',
        nodes: (data['nodes'] as List<dynamic>)
            .map((item) => FlowNode.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'businessType': businessType,
        'version': version,
        'status': status,
        'nodes': nodes.map((node) => node.toJson()).toList(),
      };
}

/// Validates stored templates before either wizard can render them.
class FlowEngine {
  final FlowTemplate template;

  const FlowEngine(this.template);

  List<String> validate() {
    final errors = <String>[];
    if (!{'product', 'stock', 'product_id'}.contains(template.type)) {
      errors.add('Choose a product, stock, or product ID flow.');
    }
    final byId = <String, FlowNode>{};
    for (final node in template.nodes) {
      if (node.id.trim().isEmpty || byId.containsKey(node.id)) {
        errors.add('Every step must have a different name.');
      }
      byId[node.id] = node;
      if (!{'start', 'end', 'question', 'if', 'action'}.contains(node.kind)) {
        errors.add('Step "${node.id}" uses an unknown step type.');
      }
    }
    final starts = template.nodes.where((n) => n.kind == 'start').toList();
    final ends = template.nodes.where((n) => n.kind == 'end').toList();
    if (starts.length != 1 || ends.length != 1) {
      errors.add('A flow needs one Start and one End.');
    }
    final requiredFields = template.type == 'product'
        ? <String>{'name', 'category'}
        : template.type == 'stock'
            ? <String>{'quantity', 'sellingPrice'}
            : <String>{};
    for (final key in requiredFields) {
      if (!template.nodes.any((n) =>
          n.fieldKey == key && n.kind == 'question' && n.locked && n.required)) {
        errors.add('Keep the required "$key" step locked.');
      }
    }
    for (final node in template.nodes) {
      final destinations = _destinations(node);
      if (node.kind != 'end' && destinations.isEmpty) {
        errors.add('Connect "${node.id}" to another step.');
      }
      if (node.kind == 'if' &&
          (!node.branches.containsKey('yes') ||
              !node.branches.containsKey('no') ||
              !node.branches.containsKey('merge'))) {
        errors.add('Give "${node.id}" Yes, No and Merge connections.');
      }
      for (final destination in destinations) {
        if (!byId.containsKey(destination)) {
          errors.add('Connect "${node.id}" to an existing step.');
        }
      }
      final merge = node.branches['merge'];
      if (merge != null && !byId.containsKey(merge)) {
        errors.add('Choose a valid merge point for "${node.id}".');
      }
    }
    if (starts.length == 1) {
      final colors = <String, int>{};
      final reachable = <String>{};
      bool visit(String id) {
        if (colors[id] == 1) return true;
        if (colors[id] == 2 || !byId.containsKey(id)) return false;
        colors[id] = 1;
        reachable.add(id);
        var cyclic = false;
        for (final destination in _destinations(byId[id]!)) {
          cyclic = visit(destination) || cyclic;
        }
        colors[id] = 2;
        return cyclic;
      }

      if (visit(starts.first.id)) errors.add('Remove loops from this flow.');
      if (ends.isNotEmpty && !reachable.contains(ends.first.id)) {
        errors.add('Connect the flow to End.');
      }
      for (final node in template.nodes) {
        if (!reachable.contains(node.id)) {
          errors.add('Step "${node.id}" cannot be reached.');
        }
      }
    }
    return errors.toSet().toList(growable: false);
  }

  List<String> _destinations(FlowNode node) {
    if (node.kind == 'if') {
      return [
        if (node.branches['yes'] != null) node.branches['yes']!,
        if (node.branches['no'] != null) node.branches['no']!,
      ];
    }
    return [if (node.next != null) node.next!];
  }

  /// Interprets a template against answers without modifying its definition.
  /// The engine executes automatic defaults, but never overwrites user answers.
  List<FlowNode> visibleQuestions(Map<String, dynamic> answers) {
    final errors = validate();
    if (errors.isNotEmpty) throw StateError(errors.join(' '));
    final byId = {for (final node in template.nodes) node.id: node};
    final start = template.nodes.firstWhere((node) => node.kind == 'start');
    final result = <FlowNode>[];
    String? id = start.id;
    final visited = <String>{};
    while (id != null && visited.add(id)) {
      final node = byId[id]!;
      if (node.kind == 'end') break;
      if (node.kind == 'question') result.add(node);
      if (node.kind == 'action') {
        final field = node.config['fieldKey'] as String?;
        if (field != null && !answers.containsKey(field)) {
          answers[field] = node.config['default'];
        }
      }
      if (node.kind == 'if') {
        final pass = testCondition(node.config, answers);
        id = node.branches[pass ? 'yes' : 'no'];
      } else {
        id = node.next;
      }
    }
    return UnmodifiableListView(result);
  }

  static bool testCondition(
      Map<String, dynamic> condition, Map<String, dynamic> answers) {
    final key = condition['fieldKey'] as String?;
    final actual = answers[key];
    final expected = condition['value'];
    switch (condition['operator']) {
      case 'notEquals':
        return actual != expected;
      case 'exists':
        return actual != null && actual.toString().isNotEmpty;
      case 'greaterThan':
        return actual is num && expected is num && actual > expected;
      case 'equals':
      default:
        return actual == expected;
    }
  }
}
