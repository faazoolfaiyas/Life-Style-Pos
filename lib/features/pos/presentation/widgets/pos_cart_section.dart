import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../data/providers/pos_provider.dart';
import '../../data/models/bill_model.dart';
import '../../../connections/data/models/connection_model.dart';
import '../../../connections/services/connection_service.dart';
import '../../../../features/products/data/models/attribute_models.dart';
import '../../../../features/products/data/models/attribute_models.dart';
import '../../../../features/products/data/providers/attribute_provider.dart';

import '../../../settings/data/providers/settings_provider.dart'; // Added settings provider
import 'bill_history_dialog.dart'; // Added import

class PosCartSection extends ConsumerStatefulWidget {
  final VoidCallback onDiscount;
  final VoidCallback onHold;
  final VoidCallback onSave;
  final VoidCallback onCheckout;
  
  const PosCartSection({
    super.key,
    required this.onDiscount,
    required this.onHold,
    required this.onSave,
    required this.onCheckout, // NOTE: Now triggers payment logic internally for Card, then calls this callback on success
  });

  @override
  ConsumerState<PosCartSection> createState() => _PosCartSectionState();
}

class _PosCartSectionState extends ConsumerState<PosCartSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(int selectedIndex) {
    if (selectedIndex < 0 || !_scrollController.hasClients) return;
    
    const double itemHeight = 60.0; 
    final double targetOffset = selectedIndex * itemHeight;
    
    if (targetOffset < _scrollController.offset || 
        targetOffset > _scrollController.offset + _scrollController.position.viewportDimension - itemHeight) {
       _scrollController.animateTo(
         targetOffset - 100,
         duration: const Duration(milliseconds: 200),
         curve: Curves.easeOut,
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalCartState = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final activeBill = globalCartState.activeBill;
    final items = activeBill.items;
    final selectedIndex = ref.watch(cartSelectionProvider);

    // Clamp selection if items changed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartSelectionProvider.notifier).clamp(items.length);
    });

    // Listen for cart selection changes to auto-scroll
    ref.listen<int>(cartSelectionProvider, (prev, next) {
      _scrollToSelected(next);
    });

    // Listen for edit price requests from keyboard shortcut
    ref.listen<int>(editPriceRequestProvider, (prev, next) {
      final sel = ref.read(cartSelectionProvider);
      if (sel >= 0 && sel < items.length) {
        _showEditPriceDialog(context, ref, sel, items[sel]);
      }
    });

    return Container(
      color: theme.cardColor,
      child: Column(
        children: [
          // 1. Bill Tabs
          _buildBillTabs(context, ref, globalCartState),
          
          // 2. Customer Info & Bill Header
          _buildHeader(context, ref, activeBill),
          
          // 3. Cart Items List (Table Logic)
          Expanded(
            child: activeBill.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.cartShopping, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Cart is Empty', style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () {},
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.highlightColor.withValues(alpha: 0.1),
                                border: Border(bottom: BorderSide(color: theme.dividerColor)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.hintColor))),
                                  Expanded(child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.hintColor))),
                                  SizedBox(width: 80, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.hintColor))),
                                  SizedBox(width: 100, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.hintColor))),
                                  const SizedBox(width: 40), // Action space
                                ],
                              ),
                            ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController, // Attach controller
                                  padding: EdgeInsets.zero,
                                itemCount: activeBill.items.length,
                                itemBuilder: (context, index) {
                                  final item = activeBill.items[index];
                                  // Defensive access for categoryName
                                  final currentCategory = item.categoryName ?? 'Uncategorized';
                                  final prevCategory = index > 0 ? (activeBill.items[index - 1].categoryName ?? 'Uncategorized') : null;
                                  
                                  final showHeader = index == 0 || prevCategory != currentCategory;
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (showHeader)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          color: theme.scaffoldBackgroundColor,
                                          child: Text(
                                            currentCategory.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11, 
                                              fontWeight: FontWeight.bold, 
                                              color: theme.primaryColor, 
                                              letterSpacing: 1.0
                                            ),
                                          ),
                                        ),
                                      _buildCartItemTable(context, ref, item, index),
                                      if (index < activeBill.items.length - 1)
                                        const Divider(height: 1),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              
              // 4. Totals & Actions
              _buildFooter(context, ref, activeBill),
            ],
          ),
    );
  }

  Widget _buildBillTabs(BuildContext context, WidgetRef ref, GlobalCartState globalState) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Slightly darker than card
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: globalState.bills.length,
              itemBuilder: (context, index) {
                final bill = globalState.bills[index];
                final isActive = index == globalState.activeIndex;
                return InkWell(
                  onTap: () => ref.read(cartProvider.notifier).switchBill(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? theme.cardColor : Colors.transparent,
                      border: isActive ? Border(top: BorderSide(color: theme.primaryColor, width: 2)) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bill #${bill.id}',
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? theme.primaryColor : theme.disabledColor,
                          ),
                        ),
                        if (globalState.bills.length > 1) ...[
                           const SizedBox(width: 8),
                           InkWell(
                             onTap: () => ref.read(cartProvider.notifier).closeBill(index),
                             child: Icon(Icons.close, size: 14, color: isActive ? theme.primaryColor : theme.disabledColor),
                           ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: () => ref.read(cartProvider.notifier).createNewBill(),
            icon: const Icon(Icons.add),
            tooltip: 'New Bill',
            color: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, SingleBillState state) {
    final customersAsync = ref.watch(streamConnectionProvider('Customer'));
    final affiliatesAsync = ref.watch(streamConnectionProvider('Affiliate'));

    final customers = (customersAsync.value ?? []).whereType<Customer>().toList();
    final affiliates = (affiliatesAsync.value ?? []).whereType<Affiliate>().toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BILL ID & DATE DISPLAY
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   if (state.billIdDisplay != null)
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text('Bill: ${state.billIdDisplay}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(width: 8),
                         // Discount Toggle
                         Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               const Text('Desc.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                               Transform.scale(
                                 scale: 0.5,
                                 child: SizedBox(
                                   width: 30, height: 20,
                                   child: Switch(
                                     value: state.showProductDiscountOverride ?? ref.read(settingsProvider).value?.showProductDiscount ?? false,
                                     onChanged: (val) {
                                        ref.read(cartProvider.notifier).toggleShowProductDiscountOverride(val);
                                     },
                                     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                   ),
                                 ),
                               ),
                            ],
                          ),
                         ),
                       ],
                     ),
                   if (state.originalBillId != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                            child: const Text('EDITING MODE', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Cancel Edit',
                            child: InkWell(
                               onTap: () => ref.read(cartProvider.notifier).cancelEdit(),
                               borderRadius: BorderRadius.circular(12),
                               child: const Padding(
                                 padding: EdgeInsets.all(4.0),
                                 child: Icon(Icons.close, size: 16, color: Colors.red),
                               ),
                            ),
                          ),
                        ],
                      ),
                 ],
               ),
               
               // Date Display
               InkWell(
                 onTap: () async {
                   final pin = await _showPinDialog(context);
                   if (pin == '1234') { // Simple PIN for now
                      final date = await showDatePicker(
                        context: context, 
                        initialDate: state.billDate ?? DateTime.now(), 
                        firstDate: DateTime(2020), 
                        lastDate: DateTime(2030)
                      );
                      if (date != null) {
                         // Ask time?
                         final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(state.billDate ?? DateTime.now()));
                         if (time != null) {
                           final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                           ref.read(cartProvider.notifier).setBillDate(combined);
                         }
                      }
                   } else if (pin != null) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
                   }
                 },
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     border: Border.all(color: Theme.of(context).dividerColor),
                     borderRadius: BorderRadius.circular(4)
                   ),
                   child: Row(
                     children: [
                       const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                       const SizedBox(width: 6),
                       Text(
                         _formatDate(state.billDate ?? DateTime.now()), 
                         style: const TextStyle(fontSize: 12)
                       ),
                     ],
                   ),
                 ),
               ),
             ],
          ),
          const SizedBox(height: 12),
          
          // Reference Bill Input (Only if Returns exist)
          if (state.items.any((i) => i.quantity < 0)) ...[
             const SizedBox(height: 8),
             TextField(
               decoration: InputDecoration(
                 labelText: 'Reference Bill # (Optional)',
                 isDense: true,
                 border: const OutlineInputBorder(),
                 suffixIcon: IconButton(
                   icon: const Icon(Icons.search),
                   onPressed: () => _pickReferenceBill(context, ref),
                 ),
               ),
               controller: TextEditingController(text: state.referenceBillId)..selection = TextSelection.collapsed(offset: (state.referenceBillId?.length ?? 0)),
               onChanged: (val) => ref.read(cartProvider.notifier).setReferenceBillId(val),
             ),
             const SizedBox(height: 12),
          ],
          
          Row( // Customer Row starts here
            children: [
              // --- CUSTOMER NAME AUTOCOMPLETE ---
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Autocomplete<Customer>(
                    displayStringForOption: (option) => option.name,
                    initialValue: TextEditingValue(text: state.customerName ?? ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<Customer>.empty();
                      return customers.where((Customer option) {
                        final query = textEditingValue.text.toLowerCase();
                        return option.name.toLowerCase().contains(query) ||
                               option.whatsappNumber.contains(query) ||
                               option.connectionId.toString().contains(query);
                      });
                    },
                    onSelected: (Customer selection) {
                      ref.read(cartProvider.notifier).setCustomerInfo(
                        selection.name, 
                        selection.whatsappNumber, 
                        connectionId: selection.connectionId
                      );
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      // Sync controller with state if state changes externally (e.g. switch tabs)
                      if (controller.text != state.customerName) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (context.mounted && controller.text != state.customerName) {
                             controller.text = state.customerName ?? '';
                           }
                        });
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        // Note: Manual typing won't set connectionId, just name & phone
                        onChanged: (val) => ref.read(cartProvider.notifier).setCustomerInfo(val, state.customerPhone ?? ''),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return _buildOptionsView<Customer>(context, constraints, options, onSelected, (c) => '${c.name} (${c.whatsappNumber})');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // --- PHONE / AFFILIATE AUTOCOMPLETE ---
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Autocomplete<Affiliate>(
                    displayStringForOption: (option) => option.whatsappNumber,
                    initialValue: TextEditingValue(text: state.affiliateName ?? ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<Affiliate>.empty();
                      return affiliates.where((Affiliate option) {
                        final query = textEditingValue.text.toLowerCase();
                        return option.whatsappNumber.contains(query) ||
                               option.name.toLowerCase().contains(query) ||
                               option.connectionId.toString().contains(query) ||
                               option.threewheelerNumber.toLowerCase().contains(query);
                      });
                    },
                    onSelected: (Affiliate selection) {
                      ref.read(cartProvider.notifier).setAffiliateInfo(
                        selection.name,
                        connectionId: selection.connectionId
                      );
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                       if (controller.text != state.affiliateName) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (context.mounted && controller.text != state.affiliateName) {
                             controller.text = state.affiliateName ?? '';
                           }
                        });
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Affiliate',
                          prefixIcon: Icon(Icons.handshake_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) => ref.read(cartProvider.notifier).setAffiliateInfo(val),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return _buildOptionsView<Affiliate>(context, constraints, options, onSelected, 
                        (a) => '${a.name} - ${a.threewheelerNumber}\nID: ${a.connectionId} | ${a.whatsappNumber}');
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payment Method Selection - Horizontal Compact
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Cash', 'Card', 'Transfer', 'Credit'].map((method) {
                final isSelected = state.paymentMethod == method;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(method),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) ref.read(cartProvider.notifier).setPaymentMethod(method);
                    },
                    showCheckmark: false,
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsView<T extends Object>(
    BuildContext context, 
    BoxConstraints constraints, 
    Iterable<T> options, 
    AutocompleteOnSelected<T> onSelected,
    String Function(T) labelBuilder,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: constraints.maxWidth,
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (BuildContext context, int index) {
              final T option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(labelBuilder(option), style: const TextStyle(fontSize: 13)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemTable(BuildContext context, WidgetRef ref, BillItem item, int index) {
    final theme = Theme.of(context);
    final colorsAsync = ref.watch(colorsProvider);
    final colors = colorsAsync.value ?? [];
    
    // Parse Variant Data
    String colorName = item.selectedColor ?? '';
    String designName = '';
    
    if (colorName.contains(' - ')) {
      final parts = colorName.split(' - ');
      colorName = parts[0]; 
      if (parts.length > 1) designName = parts[1]; 
    }
    
    final colorModel = colors.firstWhere((c) => c.name == colorName, orElse: () => ProductColor(id: '', name: '', hexCode: '#eeeeee'));
    final colorHex = colorModel.hexCode;
    
    final sizeCode = item.selectedSize ?? '';
    final variantPrefix = designName.isNotEmpty ? '$designName - $sizeCode' : sizeCode;
    
    final unitPrice = item.price;
    final effectiveUnitPrice = item.total / item.quantity;

    final isDiscounted = item.discount > 0.01;

    final isSelected = index == ref.watch(cartSelectionProvider);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryColor.withValues(alpha: 0.15) : null,
        border: isSelected ? Border.all(color: theme.primaryColor, width: 1.5) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Add margin for border
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Adjust padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // #
          SizedBox(
            width: 30, 
            child: Text('${index + 1}.', style: TextStyle(color: Colors.grey[600], fontSize: 13))
          ),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                 Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (variantPrefix.isNotEmpty)
                      Text(variantPrefix, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                     if (colorName.isNotEmpty) ...[
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _parseColorHex(colorHex), shape: BoxShape.circle),
                        ),
                        Text(colorName, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                     ]
                  ],
                )
              ],
            )
          ),

          // Price
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                 if (isDiscounted)
                    Text(
                      'LKR ${item.price.toStringAsFixed(0)}', 
                      style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey[400], fontSize: 11)
                    ),
                 InkWell(
                   onTap: () => _showEditPriceDialog(context, ref, index, item),
                   child: Text(
                     'LKR ${effectiveUnitPrice.toStringAsFixed(0)}', 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.primaryColor)
                   ),
                 ),
              ],
            ),
          ),
          
          // Qty Control
          SizedBox(
             width: 100,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 InkWell(
                   onTap: () => ref.read(cartProvider.notifier).updateQuantity(index, item.quantity - 1),
                   child: Container(
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(4)),
                     child: const Icon(Icons.remove, size: 12),
                   ),
                 ),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 8),
                   child: Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: item.quantity < 0 ? Colors.red : null)),
                 ),
                 InkWell(
                   onTap: () => ref.read(cartProvider.notifier).updateQuantity(index, item.quantity + 1),
                   child: Container(
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(4), color: theme.primaryColor.withOpacity(0.1)),
                     child: Icon(Icons.add, size: 12, color: theme.primaryColor),
                   ),
                 ),
               ],
             ),
          ),
          
          // Delete Action
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: Colors.grey[400],
              onPressed: () => ref.read(cartProvider.notifier).removeFromCart(index),
            ),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _showPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Admin PIN'),
        content: TextField(
          controller: controller, 
          obscureText: true, 
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Start')),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context, WidgetRef ref, DateTime initialDate) async {
    final pin = await _showPinDialog(context);
    if (pin != '1234') { // Replace with actual admin PIN check
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red)
        );
      }
      return;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (context.mounted) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );

        if (pickedTime != null) {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          ref.read(cartProvider.notifier).setBillDate(newDateTime);
        }
      }
    }
  }

  Future<void> _pickReferenceBill(BuildContext context, WidgetRef ref) async {
    final selectedBill = await showDialog<Bill>(
      context: context,
      builder: (context) => const BillHistoryDialog(isSelectionMode: true), 
    );

    if (selectedBill != null) {
      ref.read(cartProvider.notifier).setReferenceBillId(selectedBill.id);
    }
  }

  Color? _parseColorHex(String? colorStr) {
    if (colorStr == null) return null;
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      return null;
    } catch (e) { return null; }
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, SingleBillState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('LKR ${state.subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discount', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Row(
                children: [
                   IconButton(
                     onPressed: widget.onDiscount,
                     icon: const Icon(Icons.edit, size: 14, color: Colors.blue),
                     padding: EdgeInsets.zero,
                     constraints: const BoxConstraints(),
                     visualDensity: VisualDensity.compact,
                   ),
                   const SizedBox(width: 4),
                   Text(
                    'LKR ${state.discount.toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('LKR ${state.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Hold Button
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: state.isProcessing ? null : widget.onHold,
                  icon: const Icon(Icons.pause, size: 18),
                  label: const Text('Hold'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Save (No Print) Button
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: (state.items.isEmpty || state.isProcessing) ? null : widget.onSave,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.blue),
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Checkout (Print) Button
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: state.isProcessing 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print, size: 18),
                  label: Text(state.isProcessing ? 'Processing' : 'Print & Complete'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                  ),
                  // New Logic: Check payment method
                  onPressed: (state.items.isEmpty || state.isProcessing) ? null : widget.onCheckout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }







  void _showEditPriceDialog(BuildContext context, WidgetRef ref, int index, BillItem item) {
    // Current Values
    final currentEffectiveUnitPrice = (item.total / item.quantity);
    final currentUnitDiscount = (item.discount / item.quantity);
    
    // Controllers
    final priceController = TextEditingController(text: currentEffectiveUnitPrice.toStringAsFixed(0));
    final discountController = TextEditingController(text: currentUnitDiscount.toStringAsFixed(0));
    final priceFocus = FocusNode();
    final discountFocus = FocusNode();
    
    // State to avoid circular updates
    bool isUpdating = false;

    void submit() {
      final newPrice = double.tryParse(priceController.text);
      if (newPrice != null && newPrice >= 0) {
        ref.read(cartProvider.notifier).updateItemPrice(index, newPrice);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return CallbackShortcuts(
            bindings: {
              SingleActivator(LogicalKeyboardKey.arrowDown): () {
                if (priceFocus.hasFocus) discountFocus.requestFocus();
              },
              SingleActivator(LogicalKeyboardKey.arrowUp): () {
                if (discountFocus.hasFocus) priceFocus.requestFocus();
              },
            },
            child: AlertDialog(
              title: Text('Edit Price & Discount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Original Unit Price: LKR ${item.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  
                  // 1. EDIT PRICE
                  TextField(
                    controller: priceController,
                    focusNode: priceFocus,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => discountFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'New Unit Price (LKR)',
                      border: OutlineInputBorder(),
                      prefixText: 'LKR ',
                    ),
                    onChanged: (val) {
                      if (isUpdating) return;
                      final newPrice = double.tryParse(val);
                      if (newPrice != null) {
                        isUpdating = true;
                        final newDiscount = item.price - newPrice;
                        discountController.text = newDiscount.toStringAsFixed(0);
                        isUpdating = false;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // 2. EDIT DISCOUNT
                  TextField(
                    controller: discountController,
                    focusNode: discountFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Unit Discount (LKR)',
                      border: OutlineInputBorder(),
                      prefixText: '- LKR ',
                    ),
                    onChanged: (val) {
                      if (isUpdating) return;
                      final newDiscount = double.tryParse(val);
                      if (newDiscount != null) {
                        isUpdating = true;
                        final newPrice = item.price - newDiscount;
                        priceController.text = newPrice.toStringAsFixed(0);
                        isUpdating = false;
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Update'),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

}
