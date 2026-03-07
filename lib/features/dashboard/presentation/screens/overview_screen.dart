import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../data/providers/dashboard_provider.dart';
import '../../../pos/data/models/bill_model.dart';
import '../widgets/stat_card.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch Filter State (for Header UI)
    final filterState = ref.watch(dashboardFilterProvider);
    
    // 2. Watch Async Stats (for Content)
    final statsAsync = ref.watch(dashboardStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER & FILTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Dashboard',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn().slideX(begin: -0.2),
                  const SizedBox(height: 4),
                  Text(
                    _getRangeText(filterState),
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
              _buildFilterBar(context, ref, filterState.filter),
            ],
          ),
          const SizedBox(height: 24),
          
          // MAIN CONTENT
          statsAsync.when(
            loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (stats) => Column(
            children: [
               // STATS GRID
               LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isSmall = width < 800;
                  final crossAxisCount = isSmall ? 2 : 4;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    childAspectRatio: isSmall ? 1.4 : 1.6,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(
                        title: 'Total Sales',
                        value: 'LKR ${stats.totalSales.toStringAsFixed(0)}',
                        percentage: _getFilterLabel(filterState.filter),
                        isIncrease: true, 
                        icon: FontAwesomeIcons.dollarSign,
                        baseColor: Colors.blue,
                      ),
                      StatCard(
                        title: 'Orders',
                        value: stats.totalOrders.toString(),
                        percentage: 'Count',
                        isIncrease: true,
                        icon: FontAwesomeIcons.bagShopping,
                        baseColor: Colors.purple,
                      ),
                      StatCard(
                        title: 'Avg. Order',
                        value: 'LKR ${stats.averageOrderValue.toStringAsFixed(0)}',
                        percentage: 'Value',
                        isIncrease: false,
                        icon: FontAwesomeIcons.chartPie,
                        baseColor: Colors.orange,
                      ),
                      // Top Product Preview in Stat Card form
                      StatCard(
                        title: 'Top Item',
                        value: stats.topProducts.isNotEmpty ? stats.topProducts.first.name : '---',
                        percentage: 'Best Seller',
                        isIncrease: true,
                        icon: FontAwesomeIcons.trophy,
                        baseColor: Colors.green,
                      ),
                    ]
                    .animate(interval: 50.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // MAIN CONTENT (Chart + Lists)
              LayoutBuilder(
                 builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    if (isWide) {
                       return Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Expanded(flex: 3, child: _buildChartSection(context, stats, filterState.filter)),
                           const SizedBox(width: 24),
                           Expanded(flex: 2, child: _buildSidePanel(context, stats)),
                         ],
                       );
                    } else {
                       return Column(
                         children: [
                           _buildChartSection(context, stats, filterState.filter),
                           const SizedBox(height: 24),
                           _buildSidePanel(context, stats),
                         ],
                       );
                    }
                 }
              ),
            ],
          ) // End Data Column
          )
        ],
      ),
    );
  }
  
  // --- SUB-WIDGETS ---

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, DashboardFilter currentArgs) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            _filterBtn(context, ref, 'Today', DashboardFilter.today, currentArgs),
            _filterBtn(context, ref, 'Week', DashboardFilter.week, currentArgs),
            _filterBtn(context, ref, 'Month', DashboardFilter.month, currentArgs),
            _filterBtn(context, ref, 'Custom', DashboardFilter.custom, currentArgs),
          ],
        ),
      );
  }

  Widget _filterBtn(BuildContext context, WidgetRef ref, String label, DashboardFilter value, DashboardFilter groupValue) {
      final isSelected = value == groupValue;
      final theme = Theme.of(context);
      
      return InkWell(
        onTap: () async {
           if (value == DashboardFilter.custom) {
               final range = await showDateRangePicker(
                 context: context, 
                 firstDate: DateTime(2020), 
                 lastDate: DateTime.now()
               );
               if (range != null) {
                  ref.read(dashboardFilterProvider.notifier).setFilter(value, range: range);
               }
           } else {
              ref.read(dashboardFilterProvider.notifier).setFilter(value);
           }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: theme.primaryColor.withValues(alpha: 0.2)) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.primaryColor : theme.hintColor,
            ),
          ),
        ),
      );
  }

  Widget _buildChartSection(BuildContext context, DashboardStats stats, DashboardFilter filter) {
    if (stats.chartData.isEmpty || stats.chartData.every((d) => d.totalSales == 0)) {
        return _emptyBox(context, 'No sales data to display.');
    }
    
    int skip = filter == DashboardFilter.today ? 4 : 5;

    return Container(
       height: 400,
       padding: const EdgeInsets.all(20),
       decoration: _cardDeco(context),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sales Trend', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                Icon(Icons.bar_chart, color: Theme.of(context).primaryColor, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false,
                    horizontalInterval: _calculateInterval(stats.totalSales),
                    getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                     leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     bottomTitles: AxisTitles(
                       sideTitles: SideTitles(
                         showTitles: true,
                         getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < stats.chartData.length) {
                               if (index % skip == 0) { 
                                  final date = stats.chartData[index].date;
                                  String label = filter == DashboardFilter.today 
                                      ? DateFormat('HH:mm').format(date)  
                                      : DateFormat('d/M').format(date);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(label, style: const TextStyle(fontSize: 10)),
                                  );
                               }
                            }
                            return const SizedBox.shrink();
                         },
                       )
                     ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: stats.chartData.asMap().entries.map((entry) {
                     return BarChartGroupData(
                       x: entry.key,
                       barRods: [
                         BarChartRodData(
                           toY: entry.value.totalSales,
                           color: Theme.of(context).primaryColor,
                           width: filter == DashboardFilter.today ? 12 : 6,
                           borderRadius: BorderRadius.circular(4),
                           backDrawRodData: BackgroundBarChartRodData(show: true, toY: _getMaxSales(stats), color: Theme.of(context).canvasColor)
                         )
                       ]
                     );
                  }).toList(),
                )
              )
            ),
         ],
       ),
    ).animate().fadeIn();
  }

  Widget _buildSidePanel(BuildContext context, DashboardStats stats) {
    return Column(
      children: [
        // Top Products
        Container(
           padding: const EdgeInsets.all(16),
           decoration: _cardDeco(context),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Top Selling Products', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               if (stats.topProducts.isEmpty)
                 const Text('No data yet.', style: TextStyle(color: Colors.grey)),
               
               ...stats.topProducts.map((p) => Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: Row(
                   children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Center(child: Text('#', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                            Text('${p.quantity} Sold', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      ),
                      Text('LKR ${p.sales.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                   ],
                 ),
               )),
             ],
           ),
        ),
        const SizedBox(height: 24),
        
        // Recent Transactions
        Container(
           padding: const EdgeInsets.all(16),
           decoration: _cardDeco(context),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Recent Activity', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               if (stats.recentTransactions.isEmpty)
                 const Text('No recent bills.', style: TextStyle(color: Colors.grey)),

               ...stats.recentTransactions.take(5).map((bill) => Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: Row(
                   children: [
                      Icon(
                        bill.isReturn ? Icons.undo : Icons.receipt_long, 
                        size: 18, 
                        color: bill.isReturn ? Colors.red : Colors.blue
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
                             Text(DateFormat('MMM d, hh:mm a').format(bill.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        )
                      ),
                      Text(
                         '${bill.isReturn ? "-" : "+"} ${bill.totalAmount.toStringAsFixed(0)}',
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           color: bill.isReturn ? Colors.red : Colors.green[700]
                         ),
                      ),
                   ],
                 ),
               )),
             ],
           ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  // --- HELPERS ---
  
  BoxDecoration _cardDeco(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
      ]
    );
  }

  Widget _emptyBox(BuildContext context, String msg) {
      return Container(
        height: 200,
        decoration: _cardDeco(context),
        child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))),
      );
  }

  String _getRangeText(DashboardFilterState state) {
     if (state.filter == DashboardFilter.custom && state.customRange != null) {
        return '${DateFormat('MMM d').format(state.customRange!.start)} - ${DateFormat('MMM d').format(state.customRange!.end)}';
     }
     if (state.filter == DashboardFilter.today) return DateFormat('EEEE, MMM d').format(DateTime.now());
     return 'Overview';
  }
  
  String _getFilterLabel(DashboardFilter filter) {
    switch (filter) {
      case DashboardFilter.today: return 'Today';
      case DashboardFilter.week: return 'This Week';
      case DashboardFilter.month: return 'This Month';
      case DashboardFilter.custom: return 'Custom Range';
    }
  }

  double _getMaxSales(DashboardStats stats) {
     if (stats.chartData.isEmpty) return 100;
     double max = 0;
     for (var d in stats.chartData) {
       if (d.totalSales > max) max = d.totalSales;
     }
     return max * 1.2; // +20% buffer
  }
  
  double _calculateInterval(double total) {
     if (total == 0) return 100;
     return (total / 5).roundToDouble();
  }
}
