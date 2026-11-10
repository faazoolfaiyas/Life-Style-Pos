import 'package:flutter_test/flutter_test.dart';
import 'package:life_style/features/products/flows/flow_engine.dart';
import 'package:life_style/features/products/flows/product_id_rule.dart';
import 'package:life_style/features/products/flows/stock_math.dart';

void main() {
  FlowTemplate basic() => FlowTemplate.fromJson({
        'id': 'test',
        'type': 'product',
        'businessType': 'other',
        'version': 1,
        'status': 'published',
        'nodes': [
          {'id': 'start', 'kind': 'start', 'next': 'name'},
          {'id': 'name', 'kind': 'question', 'fieldKey': 'name', 'required': true, 'locked': true, 'next': 'category'},
          {'id': 'category', 'kind': 'question', 'fieldKey': 'category', 'required': true, 'locked': true, 'next': 'end'},
          {'id': 'end', 'kind': 'end'},
        ],
      });

  test('required questions are valid and ordered', () {
    final engine = FlowEngine(basic());
    expect(engine.validate(), isEmpty);
    expect(engine.visibleQuestions({}).map((node) => node.fieldKey), ['name', 'category']);
  });

  test('broken connections and cycles are rejected', () {
    final input = basic().toJson();
    (input['nodes'] as List)[2]['next'] = 'name';
    final result = FlowEngine(FlowTemplate.fromJson(input)).validate();
    expect(result.any((error) => error.contains('loops')), isTrue);
  });

  test('locked mandatory product fields cannot be removed', () {
    final input = basic().toJson();
    (input['nodes'] as List).removeAt(2);
    final result = FlowEngine(FlowTemplate.fromJson(input)).validate();
    expect(result.any((error) => error.contains('category')), isTrue);
  });

  test('IF conditions choose the correct path', () {
    expect(FlowEngine.testCondition({'fieldKey': 'price', 'operator': 'greaterThan', 'value': 500}, {'price': 600}), isTrue);
    expect(FlowEngine.testCondition({'fieldKey': 'category', 'operator': 'equals', 'value': 'food'}, {'category': 'books'}), isFalse);
  });

  test('product ID includes collision resistant device and random parts', () {
    final rule = ProductIdRule(tokens: ['prefix', 'category', 'running']);
    expect(rule.preview(category: 'TSH', running: 45, device: 'DEV1', unique: 'RND1'), 'PRD-TSH-0045-DEV1-RND1');
  });

  test('FEFO when expiry exists and FIFO otherwise', () {
    final lots = [
      StockLot(id: 'later', available: 5, received: DateTime(2025, 1, 1), expires: DateTime(2026, 2, 1)),
      StockLot(id: 'early', available: 3, received: DateTime(2025, 1, 2), expires: DateTime(2026, 1, 1)),
    ];
    final allocations = StockMath.allocate(lots, 6);
    expect(allocations.map((a) => a.lotId), ['early', 'later']);
    expect(allocations.map((a) => a.quantity), [3, 3]);
    expect(() => StockMath.allocate(lots, 9), throwsStateError);
  });

  test('margin calculation never divides by zero', () {
    expect(StockMath.marginPercent(70, 100), 30);
    expect(StockMath.marginPercent(30, 0), 0);
  });
}
