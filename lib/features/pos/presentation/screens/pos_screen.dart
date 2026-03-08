import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Added for animations
import '../../data/providers/pos_provider.dart';
import '../../data/models/bill_model.dart';
import '../widgets/pos_cart_section.dart';
import '../widgets/pos_product_grid.dart';
import '../widgets/bill_history_dialog.dart';
import '../widgets/pos_product_filter_panel.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        // POS OPERATIONS
        const SingleActivator(LogicalKeyboardKey.f5): () => _showDiscountDialog(context, ref),
        const SingleActivator(LogicalKeyboardKey.f6): () => _handleHold(context, ref),
        const SingleActivator(LogicalKeyboardKey.f7): () => _handleSaveWithoutPrint(context, ref),
        const SingleActivator(LogicalKeyboardKey.f8): () => _handleCheckoutWithDialog(context, ref),
        
        // PAYMENT METHODS
        SingleActivator(LogicalKeyboardKey.f9): () => ref.read(cartProvider.notifier).setPaymentMethod('Cash'),
        SingleActivator(LogicalKeyboardKey.f10): () => ref.read(cartProvider.notifier).setPaymentMethod('Card'),
        SingleActivator(LogicalKeyboardKey.f11): () => ref.read(cartProvider.notifier).setPaymentMethod('Transfer'),
        SingleActivator(LogicalKeyboardKey.f12): () => ref.read(cartProvider.notifier).setPaymentMethod('Credit'),
      },
      child: Scaffold(
        endDrawer: PosProductFilterPanel(
          sortBy: 'name',
          sortAsc: true,
          onApply: ({category, size, color, minPrice, maxPrice, stockStatus, sortBy = 'name', sortAsc = true}) {
            // TODO: Apply filters to product grid
            // For now, just close the drawer
          },
          onReset: () {
            // TODO: Reset filters in product grid  
          },
        ),
        body: Row(
          children: [
            // LEFT PANEL: Product Catalog
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildTopBar(context, ref),
                  const Expanded(child: PosProductGrid()),
                ],
              ),
            ),
            
            // VERTICAL DIVIDER
            Container(width: 1, color: Theme.of(context).dividerColor),

            // RIGHT PANEL: Cart
            Expanded(
              flex: 2,
              child: PosCartSection(
                onDiscount: () => _showDiscountDialog(context, ref),
                onHold: () => _handleHold(context, ref),
                onSave: () => _handleSaveWithoutPrint(context, ref),
                onCheckout: () => _handleCheckoutWithDialog(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Register', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.flash_on),
                label: const Text('Quick Sale'),
                style: TextButton.styleFrom(foregroundColor: Colors.purple),
                onPressed: () => _showQuickSaleDialog(context, ref),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter Products',
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('History'),
                onPressed: () => _showHistoryDialog(context, ref),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Pending Bills'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                onPressed: () => _showPendingBillsDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const BillHistoryDialog(),
    );
  }

  void _showPendingBillsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending Bills', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final pendingAsync = ref.watch(pendingBillsProvider);
                    return pendingAsync.when(
                      data: (bills) {
                        if (bills.isEmpty) return const Center(child: Text('No pending bills.'));
                        return ListView.separated(
                          itemCount: bills.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final bill = bills[index];
                            return ListTile(
                              title: Text(bill.customerName?.isNotEmpty == true ? bill.customerName! : 'Guest'),
                              subtitle: Text('${bill.items.length} Items • ${DateFormat('h:mm a').format(bill.createdAt)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('LKR ${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    child: const Text('Resume'),
                                    onPressed: () {
                                      ref.read(cartProvider.notifier).resumeBill(bill);
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- POS LOGIC METHODS ---

  void _showQuickSaleDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quick Sale', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Selling Price',
                prefixText: 'LKR ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              
              if (name.isNotEmpty && price >= 0) {
                ref.read(cartProvider.notifier).addQuickSaleItem(name, price);
                Navigator.pop(context);
              }
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveWithoutPrint(BuildContext context, WidgetRef ref) async {
     final state = ref.read(cartProvider).activeBill;
     _handlePaymentDialog(context, ref, state, shouldPrint: false);
  }

  Future<void> _handleCheckoutWithDialog(BuildContext context, WidgetRef ref) async {
     final state = ref.read(cartProvider).activeBill;
     _handlePaymentDialog(context, ref, state, shouldPrint: true);
  }

  Future<void> _handlePaymentDialog(BuildContext context, WidgetRef ref, SingleBillState state, {required bool shouldPrint}) async {
    final double totalAmount = state.totalAmount;
    final bool isCard = state.paymentMethod == 'Card';
    
    // Auto-fill amount for non-cash methods to speed up processing
    String initialText = '';
    if (!isCard && state.paymentMethod != 'Cash') {
      initialText = totalAmount.toStringAsFixed(2);
    }

    final TextEditingController receivedCtrl = TextEditingController(text: initialText);
    final TextEditingController splitCashCtrl = TextEditingController(); // For Card Split
    final FocusNode focusNode = FocusNode();
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental close
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final double totalAmount = state.totalAmount;
          double receivedAmount = double.tryParse(receivedCtrl.text) ?? 0.0;
          
          // Split Payment Logic (Card Only)
          double splitCashAmount = double.tryParse(splitCashCtrl.text) ?? 0.0;
          double cardBalanceToCharge = isCard ? (totalAmount - splitCashAmount) : 0.0;
          if (cardBalanceToCharge < 0) cardBalanceToCharge = 0;

          // For Cash: Balance is Change. For Card: Balance is Card Charge (if not split).
          // Actually logic is:
          // Cash: Received - Total = Change
          // Card: splitCash is optional. 
          
          double balance = receivedAmount - totalAmount;

          final bool isCredit = state.paymentMethod == 'Credit';
          final bool isSufficient = isCard 
              ? true // Card is always sufficient as we charge the rest
              : receivedAmount >= totalAmount - 0.01; 
          
          final bool canComplete = isCredit || isSufficient;
          
          return AlertDialog(
            title: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text('Payment (${state.paymentMethod})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                 IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
               ]
            ),
            content: CallbackShortcuts(
              bindings: {
                SingleActivator(LogicalKeyboardKey.period): () {
                   if (!isCard) {
                     receivedCtrl.text = totalAmount.toStringAsFixed(2);
                     setState(() {});
                   }
                },
                SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
                   if (!isCard) {
                      receivedCtrl.text = totalAmount.toStringAsFixed(2);
                      setState(() {});
                   }
                },
                SingleActivator(LogicalKeyboardKey.enter): () {
                   if (canComplete) {
                     _handlePaymentCompletion(context, ref, isCard ? cardBalanceToCharge : receivedAmount, splitCashAmount, shouldPrint, isCard);
                   }
                },
                 SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                   if (canComplete) {
                     _handlePaymentCompletion(context, ref, isCard ? cardBalanceToCharge : receivedAmount, splitCashAmount, shouldPrint, isCard);
                   }
                },
              },
              child: SizedBox(
                 width: 450,
                 child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Total Bill Amount', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12)),
                        Text(
                          'LKR ${totalAmount.toStringAsFixed(2)}', 
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (isCard) ...[
                     // CARD SPLIT PAYMENT UI
                     Text('Split Payment (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                     const SizedBox(height: 8),
                     Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: splitCashCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Cash Paid',
                              prefixText: 'LKR ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.blue.shade50,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Charge to Card', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                Text(
                                  'LKR ${cardBalanceToCharge.toStringAsFixed(2)}', 
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                     ),
                     const SizedBox(height: 24),
                  ] else ...[
                      // CASH / OTHER UI
                      TextFormField(
                        controller: receivedCtrl,
                        focusNode: focusNode,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Received Amount',
                          prefixText: 'LKR ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => setState(() {}),
                        onFieldSubmitted: (_) {
                          if (canComplete) {
                            _handlePaymentCompletion(context, ref, receivedAmount, 0, shouldPrint, isCard);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Quick Cash Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                           ...[500, 1000, 1500, 2000, 2500, 3000, 3500, 4500, 5000, 10000].map((amt) {
                              return ActionChip(
                                label: Text(amt.toString(), style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                   receivedCtrl.text = amt.toString();
                                   setState(() {});
                                },
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              );
                           }).toList()
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Balance Display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance / Change:', style: TextStyle(fontSize: 16)),
                          Text(
                            'LKR ${balance.toStringAsFixed(2)}', 
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: balance < 0 ? Colors.red : Colors.green
                            )
                          ),
                        ],
                      ),
                      if (!isCredit && !isSufficient)
                         Padding(
                           padding: const EdgeInsets.only(top: 8),
                           child: Text('Insufficient amount!', style: TextStyle(color: Colors.red[700], fontSize: 12, fontStyle: FontStyle.italic)),
                         ),
                  ],
                ],
               ),
            ),
          ),
            actions: [
              if (!isCard)
                TextButton(
                  onPressed: () {
                     // Ignore / Auto-Fill
                     receivedCtrl.text = totalAmount.toStringAsFixed(2);
                     setState(() {});
                  }, 
                  child: const Text('Exact Amount')
                ),
              FilledButton(
                onPressed: canComplete ? () {
                  _handlePaymentCompletion(context, ref, isCard ? cardBalanceToCharge : receivedAmount, splitCashAmount, shouldPrint, isCard);
                } : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: shouldPrint ? Colors.green : Colors.blue,
                ),
                child: Text(shouldPrint ? 'Print & Done' : 'Save & Done'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _handlePaymentCompletion(BuildContext context, WidgetRef ref, double finalAmount, double cashSplit, bool shouldPrint, bool isCard) {
      if (context.mounted) Navigator.pop(context); // Close Popup

      if (isCard) {
         _showCardConfirmationDialog(context, ref, finalAmount, cashSplit, shouldPrint);
      } else {
         _processCheckout(context, ref, finalAmount, shouldPrint);
      }
  }

  // --- NEW CARD CONFIRMATION DIALOG ---
  Future<void> _showCardConfirmationDialog(BuildContext context, WidgetRef ref, double cardAmount, double cashSplit, bool shouldPrint) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String status = 'idle'; // idle, success, failure
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'idle') ...[
                      // WAITING ANIMATION AS HEADER
                      const _WaitingAnimation(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade600, Colors.blue.shade800],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Column(
                          children: [
                            const Text('TOTAL TO CHARGE', style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('LKR ${cardAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      if (cashSplit > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text('+ LKR ${cashSplit.toStringAsFixed(2)} Cash Received', style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                        ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => status = 'failure');
                                Future.delayed(const Duration(milliseconds: 1500), () {
                                  if (context.mounted) Navigator.pop(context);
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red, 
                                side: BorderSide(color: Colors.red.shade200),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() => status = 'success');
                                
                                // WAIT FOR SUCCESS ANIMATION
                                await Future.delayed(const Duration(milliseconds: 2000));
                                
                                if (context.mounted) {
                                  Navigator.pop(context); // Close dialog
                                  // FINAL CHECKOUT & PRINTING
                                  _processCheckout(context, ref, cardAmount + cashSplit, shouldPrint, cashSplitAmount: cashSplit > 0 ? cashSplit : null);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Confirm Received'),
                            ),
                          ),
                        ],
                      ),
                    ] else if (status == 'success') ...[
                      const _SuccessAnimation(),
                    ] else if (status == 'failure') ...[
                      const _FailureAnimation(),
                    ]
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _processCheckout(BuildContext context, WidgetRef ref, double receivedAmount, bool shouldPrint, {double? cashSplitAmount}) async {
    try {
      await ref.read(cartProvider.notifier).checkout(receivedAmount: receivedAmount, splitCashAmount: cashSplitAmount, shouldPrint: shouldPrint);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(shouldPrint ? 'Bill Printed Successfully!' : 'Bill Saved Successfully!'),
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleHold(BuildContext context, WidgetRef ref) async {
     try {
      await ref.read(cartProvider.notifier).holdBill();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill held successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(cartProvider).activeBill;
    final discountCtrl = TextEditingController(text: state.globalDiscount > 0 ? state.globalDiscount.toStringAsFixed(2) : '');
    final promoCtrl = TextEditingController(text: state.promoCode ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Discount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Global Discount (LKR)',
                prefixText: 'LKR ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promoCtrl,
              decoration: InputDecoration(
                labelText: 'Promo Code (Optional)',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final discount = double.tryParse(discountCtrl.text) ?? 0.0;
              final promo = promoCtrl.text.trim();
              
              ref.read(cartProvider.notifier).setGlobalDiscount(discount);
              ref.read(cartProvider.notifier).setPromoCode(promo.isEmpty ? null : promo);
              
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// --- ANIMATION WIDGETS ---

class _WaitingAnimation extends StatelessWidget {
  const _WaitingAnimation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade200),
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 3.seconds),
            const Icon(Icons.hourglass_empty_rounded, size: 40, color: Colors.blue)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 1.seconds, curve: Curves.easeInOut)
                .rotate(begin: -0.1, end: 0.1),
          ],
        ),
        const SizedBox(height: 32),
        Text('Waiting for payment...', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
        const SizedBox(height: 8),
        Text('Processing on card terminal', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SuccessAnimation extends StatelessWidget {
  const _SuccessAnimation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.shade200, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: Colors.green, size: 60),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut).shimmer(delay: 600.ms, duration: 1.seconds),
        const SizedBox(height: 24),
        Text('Payment Successful!', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
        const SizedBox(height: 8),
        Text('Completing your order...', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FailureAnimation extends StatelessWidget {
  const _FailureAnimation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red.shade200, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.close_rounded, color: Colors.red, size: 60),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).shake(delay: 400.ms),
        const SizedBox(height: 24),
        Text('Payment Cancelled', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
        const SizedBox(height: 8),
        Text('Charge was declined by operator', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 20),
      ],
    );
  }
}
