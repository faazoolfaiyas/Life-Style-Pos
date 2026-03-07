import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../pos/data/models/bill_model.dart';
import '../../../pos/data/services/pos_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// --- Enums & Models ---

enum DashboardFilter { today, week, month, custom }

class DailySalesData {
  final DateTime date;
  final double totalSales;
  final int orderCount;

  DailySalesData({
    required this.date,
    required this.totalSales,
    required this.orderCount,
  });
}

class DashboardFilterState {
  final DashboardFilter filter;
  final DateTimeRange? customRange;

  const DashboardFilterState({
    this.filter = DashboardFilter.month,
    this.customRange,
  });

  DashboardFilterState copyWith({
    DashboardFilter? filter,
    DateTimeRange? customRange,
  }) {
    return DashboardFilterState(
      filter: filter ?? this.filter,
      customRange: customRange ?? this.customRange,
    );
  }
}

class DashboardStats {
  final double totalSales;
  final int totalOrders;
  final double averageOrderValue;
  final List<DailySalesData> chartData;
  final List<Bill> recentTransactions;
  final List<TopProduct> topProducts;

  const DashboardStats({
    this.totalSales = 0.0,
    this.totalOrders = 0,
    this.averageOrderValue = 0.0,
    this.chartData = const <DailySalesData>[],
    this.recentTransactions = const <Bill>[],
    this.topProducts = const <TopProduct>[],
  });
}

class TopProduct {
  final String name;
  final int quantity;
  final double sales;
  
  TopProduct({required this.name, required this.quantity, required this.sales});
}

// --- Providers ---

// 1. Filter State Provider
class DashboardFilterNotifier extends Notifier<DashboardFilterState> {
  @override
  DashboardFilterState build() {
    return const DashboardFilterState();
  }

  void setFilter(DashboardFilter filter, {DateTimeRange? range}) {
    state = state.copyWith(filter: filter, customRange: range);
  }
}

final dashboardFilterProvider = NotifierProvider<DashboardFilterNotifier, DashboardFilterState>(DashboardFilterNotifier.new);

// 2. Main Stats Provider (Depends on Filter)
final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  final posService = ref.watch(posServiceProvider);
  final filterState = ref.watch(dashboardFilterProvider);
  final authState = ref.watch(authStateProvider); // Watch Auth
  final isAdmin = authState.value?.isAdministrator ?? false;

  // Calculate Date Range
  final now = DateTime.now();
  DateTime start;
  DateTime end = now;

  switch (filterState.filter) {
    case DashboardFilter.today:
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DashboardFilter.week:
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      break;
    case DashboardFilter.month:
      start = DateTime(now.year, now.month, 1);
      break;
    case DashboardFilter.custom:
      start = filterState.customRange?.start ?? now.subtract(const Duration(days: 30));
      end = filterState.customRange?.end ?? now;
      break;
  }

  // Fetch & Transform
  return posService.getBillsInRange(start, end, isAdministrator: isAdmin)
      .handleError((error) {
         print('Dashboard Provider Error: $error');
         throw error;
      })
      .map((bills) {
    double totalSales = 0.0;
    int orders = 0;
    Map<String, TopProduct> productMap = {};
    Map<String, DailySalesData> chartMap = {};

    // Chart Setup
    final interval = filterState.filter == DashboardFilter.today ? 'HOUR' : 'DAY';
    
    if (interval == 'HOUR') {
      for (int i = 0; i < 24; i++) {
        final hour = DateTime(start.year, start.month, start.day, i);
        final key = DateFormat('HH:00').format(hour);
        chartMap[key] = DailySalesData(date: hour, totalSales: 0, orderCount: 0);
      }
    } else {
      int days = end.difference(start).inDays + 1;
      if (days > 60) days = 60;
      for (int i = 0; i < days; i++) {
         final day = start.add(Duration(days: i));
         final key = DateFormat('yyyy-MM-dd').format(day);
         chartMap[key] = DailySalesData(date: day, totalSales: 0, orderCount: 0);
      }
    }

    // Process Bills
    for (var bill in bills) {
      if (bill.status == 'Cancelled' || bill.isReturn) continue;

      totalSales += bill.totalAmount;
      orders++;

      // Chart
      String key;
      if (interval == 'HOUR') {
         key = DateFormat('HH:00').format(bill.createdAt);
      } else {
         key = DateFormat('yyyy-MM-dd').format(bill.createdAt);
      }
      
      if (chartMap.containsKey(key)) {
         final current = chartMap[key]!;
         chartMap[key] = DailySalesData(
           date: current.date, 
           totalSales: current.totalSales + bill.totalAmount, 
           orderCount: current.orderCount + 1
         );
      }

      // Top Products
      for (var item in bill.items) {
         final pKey = item.productId;
         final existing = productMap[pKey] ?? TopProduct(name: item.productName, quantity: 0, sales: 0);
         productMap[pKey] = TopProduct(
           name: existing.name,
           quantity: existing.quantity + item.quantity.abs().toInt(),
           sales: existing.sales + (item.price * item.quantity.abs())
         );
      }
    }

    // Finalize
    final chartList = chartMap.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    final topList = productMap.values.toList()..sort((a, b) => b.quantity.compareTo(a.quantity));
    final recent = List<Bill>.from(bills)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DashboardStats(
      totalSales: totalSales,
      totalOrders: orders,
      averageOrderValue: orders > 0 ? totalSales / orders : 0.0,
      chartData: chartList,
      recentTransactions: recent.take(6).toList(),
      topProducts: topList.take(5).toList(),
    );
  });
});
