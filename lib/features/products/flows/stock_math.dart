class StockLot {
  final String id;
  final int available;
  final DateTime received;
  final DateTime? expires;
  const StockLot({
    required this.id,
    required this.available,
    required this.received,
    this.expires,
  });
}

class StockAllocation {
  final String lotId;
  final int quantity;
  const StockAllocation(this.lotId, this.quantity);
}

class StockMath {
  const StockMath._();

  static double marginPercent(double cost, double selling) =>
      selling <= 0 ? 0 : (selling - cost) / selling * 100;

  /// Returns no allocations if stock is insufficient; never creates negative lots.
  /// This is pure math, not a concurrency substitute for a backend transaction.
  static List<StockAllocation> allocate(List<StockLot> lots, int quantity) {
    if (quantity <= 0) throw ArgumentError.value(quantity, 'quantity', 'Must be positive');
    if (lots.any((lot) => lot.available < 0)) {
      throw StateError('Negative stock needs correction before a sale.');
    }
    final sorted = [...lots]..sort((a, b) {
      final hasExpiry = a.expires != null || b.expires != null;
      if (hasExpiry) {
        final aExpiry = a.expires ?? DateTime(9999);
        final bExpiry = b.expires ?? DateTime(9999);
        final comparison = aExpiry.compareTo(bExpiry);
        if (comparison != 0) return comparison;
      }
      final received = a.received.compareTo(b.received);
      return received != 0 ? received : a.id.compareTo(b.id);
    });
    var left = quantity;
    final result = <StockAllocation>[];
    for (final lot in sorted) {
      if (left == 0) break;
      final assigned = left < lot.available ? left : lot.available;
      if (assigned > 0) result.add(StockAllocation(lot.id, assigned));
      left -= assigned;
    }
    if (left > 0) throw StateError('Not enough stock for this sale.');
    return result;
  }
}
