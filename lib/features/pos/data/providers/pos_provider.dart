import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/products/data/models/product_model.dart';
import '../models/bill_model.dart';
import '../services/pos_service.dart';
import '../../services/bill_printer_service.dart';
import '../../../settings/data/providers/settings_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../features/products/data/providers/attribute_provider.dart'; // Added
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'dart:math';

// --- State Classes ---

class SingleBillState {
  final String id; // Unique ID for tab identification
  final String? billIdDisplay;
  final List<BillItem> items;
  final String? customerName;
  final String? customerPhone;
  final int? customerId;
  final String? affiliateName;
  final int? affiliateId;
  final String paymentMethod;
  final bool isProcessing;
  final double globalDiscount; // Added
  final String? promoCode;     // Added
  final String? referenceBillId;
  final String? originalBillId;
  final DateTime? billDate;
  final bool? showProductDiscountOverride; // Override for current bill

  const SingleBillState({
    required this.id,
    this.billIdDisplay,
    this.items = const [],
    this.customerName,
    this.customerPhone,
    this.customerId,
    this.affiliateName,
    this.affiliateId,
    this.paymentMethod = 'Cash',
    this.isProcessing = false,
    this.globalDiscount = 0.0,
    this.promoCode,
    this.referenceBillId,
    this.originalBillId,
    this.billDate,
    this.showProductDiscountOverride,
  });

  double get grossTotal => items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  double get itemDiscountTotal => items.fold(0.0, (sum, item) => sum + item.discount);
  
  double get subTotal => grossTotal;
  double get tax => 0.0;
  // Total Discount = Item Discounts + Global Discount
  double get discount => itemDiscountTotal + globalDiscount;
  double get totalAmount => subTotal + tax - discount;

  // Helper to copy with nullable overrides
  SingleBillState copyWith({
    String? id,
    String? billIdDisplay,
    List<BillItem>? items,
    String? customerName,
    String? customerPhone,
    int? customerId,
    String? affiliateName,
    int? affiliateId,
    String? paymentMethod,
    bool? isProcessing,
    double? globalDiscount,
    String? promoCode,
    String? referenceBillId,
    String? originalBillId,
    DateTime? billDate,
    bool? showProductDiscountOverride,
  }) {
    return SingleBillState(
      id: id ?? this.id,
      billIdDisplay: billIdDisplay ?? this.billIdDisplay,
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerId: customerId ?? this.customerId,
      affiliateName: affiliateName ?? this.affiliateName,
      affiliateId: affiliateId ?? this.affiliateId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isProcessing: isProcessing ?? this.isProcessing,
      globalDiscount: globalDiscount ?? this.globalDiscount,
      promoCode: promoCode ?? this.promoCode,
      referenceBillId: referenceBillId ?? this.referenceBillId,
      originalBillId: originalBillId ?? this.originalBillId,
      billDate: billDate ?? this.billDate,
      showProductDiscountOverride: showProductDiscountOverride ?? this.showProductDiscountOverride,
    );
  }
}

class GlobalCartState {
  final List<SingleBillState> bills;
  final int activeIndex;

  const GlobalCartState({
    required this.bills,
    this.activeIndex = 0,
  });

  SingleBillState get activeBill => bills[activeIndex];

  GlobalCartState copyWith({
    List<SingleBillState>? bills,
    int? activeIndex,
  }) {
    return GlobalCartState(
      bills: bills ?? this.bills,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

// --- Notifier ---

class CartNotifier extends Notifier<GlobalCartState> {
  late final PosService _posService;


  String _generateBillId() {
    final now = DateTime.now();
    final yy = (now.year % 100).toString();
    final m = now.month.toString();
    final d = now.day.toString();
    
    // Generate distinct random 4-digit number
    final random = Random();
    final rrrr = (random.nextInt(9999) + 1).toString().padLeft(4, '0');
    
    return '$yy$m$d$rrrr';
  }

  @override
  GlobalCartState build() {
    _posService = ref.watch(posServiceProvider);
    return GlobalCartState(
      bills: [SingleBillState(id: '1', billIdDisplay: _generateBillId())],
    );
  }

  // --- Multi-Bill Operations ---

  void createNewBill() {
    final newId = (state.bills.length + 1).toString();
    final newBill = SingleBillState(
      id: newId, 
      billIdDisplay: _generateBillId(),
    );
    state = state.copyWith(
      bills: [...state.bills, newBill],
      activeIndex: state.bills.length, // Switch to new tab
    );
  }

  void switchBill(int index) {
    if (index >= 0 && index < state.bills.length) {
      state = state.copyWith(activeIndex: index);
    }
  }

  void closeBill(int index) {
    if (state.bills.length <= 1) {
        clearCart(); // If last one, just clear it
        return;
    }
    
    final newBills = List<SingleBillState>.from(state.bills)..removeAt(index);
    // Adjust active index if needed
    int newIndex = state.activeIndex;
    if (newIndex >= newBills.length) {
      newIndex = newBills.length - 1;
    }
    
    state = state.copyWith(
      bills: newBills,
      activeIndex: newIndex,
    );
  }

  // --- Active Bill Operations ---

  void _updateActiveBill(SingleBillState newBillState) {
    final newBills = List<SingleBillState>.from(state.bills);
    newBills[state.activeIndex] = newBillState;
    state = state.copyWith(bills: newBills);
  }

  void setCustomerInfo(String name, String phone, {int? connectionId}) {
    _updateActiveBill(state.activeBill.copyWith(
      customerName: name, 
      customerPhone: phone,
      customerId: connectionId
    ));
  }

  void setAffiliateInfo(String name, {int? connectionId}) {
    _updateActiveBill(state.activeBill.copyWith(
      affiliateName: name,
      affiliateId: connectionId
    ));
  }

  void setPaymentMethod(String method) {
    _updateActiveBill(state.activeBill.copyWith(paymentMethod: method));
  }

  void setGlobalDiscount(double discount) {
    final activeBill = state.activeBill;
    // Basic validation
    if (discount > activeBill.subTotal) return; 
    
    _updateActiveBill(activeBill.copyWith(globalDiscount: discount));
  }

  void setPromoCode(String? code) {
    _updateActiveBill(state.activeBill.copyWith(promoCode: code));
  }

  void setReferenceBillId(String? refId) {
    _updateActiveBill(state.activeBill.copyWith(referenceBillId: refId));
  }
  
  void setBillDate(DateTime date) {
    _updateActiveBill(state.activeBill.copyWith(billDate: date));
  }

  void toggleShowProductDiscountOverride(bool? overrideValue) {
    _updateActiveBill(state.activeBill.copyWith(showProductDiscountOverride: overrideValue));
  }

  void loadBillForEditing(Bill bill) {
    // Determine if we need new tab
    if (state.activeBill.items.isNotEmpty || state.activeBill.customerName != null) {
      createNewBill();
    }
    
    _updateActiveBill(SingleBillState(
      id: state.activeBill.id,
      billIdDisplay: bill.billNumber,
      items: bill.items,
      customerName: bill.customerName,
      customerPhone: bill.customerPhone,
      customerId: bill.customerId,
      affiliateName: bill.affiliateName,
      affiliateId: bill.affiliateId,
      paymentMethod: bill.paymentMethod,
      globalDiscount: bill.discount - bill.items.fold(0.0, (sum, i) => sum + i.discount), // Approximation if not stored separately
      originalBillId: bill.id, // MARK AS EDIT
      billDate: bill.createdAt,
    ));
  }

  void addToCart(Product product, {String? size, String? color, String? stockId, double? price}) {
    final currentBill = state.activeBill;
    
    // Logic Change: Check stockId first if available
    final existingIndex = currentBill.items.indexWhere((item) {
      if (stockId != null) {
        // If new item has stockId, ONLY match if existing item has SAME stockId.
        return item.stockId == stockId;
      }
      // If new item has NO stockId, match if existing item has NO stockId AND attributes match.
      return item.stockId == null &&
             item.productId == product.id && 
             item.selectedColor == color && 
             item.selectedSize == size;
    });

    List<BillItem> updatedItems;

    if (existingIndex != -1) {
      // Update quantity of existing item
      final oldItems = List<BillItem>.from(currentBill.items);
      final item = oldItems[existingIndex];
      // We use updateQuantity internally logic but here we do it manually to avoid double state update before sort
      final newQty = item.quantity + 1;
      final unitDiscount = item.discount / item.quantity;
      final newDiscount = unitDiscount * newQty;
      oldItems[existingIndex] = item.copyWith(quantity: newQty, discount: newDiscount);
      updatedItems = oldItems;
    } else {
      // Add new item
      final newItem = BillItem(
        productId: product.id ?? '',
        stockId: stockId, // Populated
        productName: product.name,
        categoryName: product.categoryName, // Populate category
        price: price ?? product.price, // USE PASSED PRICE OR FALLBACK
        quantity: 1,
        selectedColor: color,
        selectedSize: size,
      );
      updatedItems = [...currentBill.items, newItem];
    }

    // Sort items: Category -> Product Name -> Selected Color -> Selected Size
    updatedItems.sort((a, b) {
      // Defensive coding against runtime nulls (even if typed String)
      final catA = (a.categoryName as String?) ?? 'Uncategorized';
      final catB = (b.categoryName as String?) ?? 'Uncategorized';
      
      final catCompare = catA.compareTo(catB);
      if (catCompare != 0) return catCompare;

      final nameCompare = a.productName.compareTo(b.productName);
      if (nameCompare != 0) return nameCompare;
      
      // Secondary sorts for stable variant ordering
      final colorCompare = (a.selectedColor ?? '').compareTo(b.selectedColor ?? '');
      if (colorCompare != 0) return colorCompare;

      return (a.selectedSize ?? '').compareTo(b.selectedSize ?? '');
    });

    _updateActiveBill(currentBill.copyWith(items: updatedItems));
  }

  void addQuickSaleItem(String name, double price) {
    final currentBill = state.activeBill;
    
    final existingIndex = currentBill.items.indexWhere((item) => 
        item.productId == 'TEMP-001' && item.productName == name && item.price == price);

    List<BillItem> updatedItems;

    if (existingIndex != -1) {
      final oldItems = List<BillItem>.from(currentBill.items);
      final item = oldItems[existingIndex];
      final newQty = item.quantity + 1;
      final unitDiscount = item.discount / item.quantity;
      final newDiscount = unitDiscount * newQty;
      oldItems[existingIndex] = item.copyWith(quantity: newQty, discount: newDiscount);
      updatedItems = oldItems;
    } else {
      final newItem = BillItem(
        productId: 'TEMP-001',
        productName: name,
        categoryName: 'Quick Sale',
        price: price,
        quantity: 1,
      );
      updatedItems = [...currentBill.items, newItem];
    }

    updatedItems.sort((a, b) {
      final catA = (a.categoryName as String?) ?? 'Uncategorized';
      final catB = (b.categoryName as String?) ?? 'Uncategorized';
      
      final catCompare = catA.compareTo(catB);
      if (catCompare != 0) return catCompare;

      final nameCompare = a.productName.compareTo(b.productName);
      if (nameCompare != 0) return nameCompare;
      
      final colorCompare = (a.selectedColor ?? '').compareTo(b.selectedColor ?? '');
      if (colorCompare != 0) return colorCompare;

      return (a.selectedSize ?? '').compareTo(b.selectedSize ?? '');
    });

    _updateActiveBill(currentBill.copyWith(items: updatedItems));
  }

  void removeFromCart(int index) {
    final currentBill = state.activeBill;
    if (index >= 0 && index < currentBill.items.length) {
      final newItems = List<BillItem>.from(currentBill.items)..removeAt(index);
      _updateActiveBill(currentBill.copyWith(items: newItems));
    }
  }

  void updateQuantity(int index, int newQty) {
    // Logic Change: Allow 0 if manually entered? Maybe not.
    // User requested: "remove the 0 stock point if user try to reduce from 1 to - directly got -1"
    
    final currentBill = state.activeBill;
    if (index >= 0 && index < currentBill.items.length) {
      final newItems = List<BillItem>.from(currentBill.items);
      final item = newItems[index];

      int finalQty = newQty;
      
      // If attempting to go to 0, jump over it.
      if (newQty == 0) {
          if (item.quantity > 0) {
             finalQty = -1;
          } else if (item.quantity < 0) {
             finalQty = 1;
          }
      }

      final oldQty = item.quantity;
      // Recalc Discount: discount is total. We need unit discount.
      // If oldQty was 0 (shouldn't be), use price? No, discount/qty.
      final unitDiscount = oldQty != 0 ? item.discount / oldQty : 0.0;
      final newDiscount = unitDiscount * finalQty;
      
      newItems[index] = item.copyWith(quantity: finalQty, discount: newDiscount);
      _updateActiveBill(currentBill.copyWith(items: newItems));
    }
  }
  
  void updateItemPrice(int index, double newUnitPrice) {
     final currentBill = state.activeBill;
     if (index >= 0 && index < currentBill.items.length) {
       final newItems = List<BillItem>.from(currentBill.items);
       final item = newItems[index];
       
       final newDiscount = (item.price - newUnitPrice) * item.quantity;
       
       newItems[index] = item.copyWith(discount: newDiscount);
       _updateActiveBill(currentBill.copyWith(items: newItems));
    }
  }

  void clearCart() {
     // Resets active bill to clean slate but NEW ID
     final newBillId = _generateBillId();
     _updateActiveBill(SingleBillState(id: state.activeBill.id, billIdDisplay: newBillId));
  }

  Future<void> cancelEdit() async {
    clearCart();
  }

  Future<void> checkout({double? receivedAmount, double? splitCashAmount, bool shouldPrint = true}) async {
    final currentBill = state.activeBill;
    if (currentBill.items.isEmpty) return;

    if (currentBill.paymentMethod == 'Credit' && currentBill.customerId == null) {
      throw 'Customer is required for Credit payments';
    }
    
    _updateActiveBill(currentBill.copyWith(isProcessing: true));

    try {
      // Calculate split amounts if applicable
      double? finalSplitCash = splitCashAmount;
      double? finalSplitCard;
      
      if (currentBill.paymentMethod == 'Card' && splitCashAmount != null && splitCashAmount > 0) {
        // If split cash is provided for card payment, verify and set card portion
        final total = currentBill.totalAmount;
        finalSplitCard = total - splitCashAmount;
        // ensure non negative? logic handled in UI but safe check
        if (finalSplitCard < 0) finalSplitCard = 0;
      }

      final bill = Bill(
        id: currentBill.originalBillId ?? const Uuid().v4(),
        billNumber: currentBill.billIdDisplay ?? _generateBillId(),
        items: currentBill.items,
        totalAmount: currentBill.totalAmount,
        subTotal: currentBill.subTotal,
        paymentMethod: currentBill.paymentMethod,
        status: 'Completed',
        createdAt: DateTime.now(),
        customerName: currentBill.customerName,
        customerPhone: currentBill.customerPhone,
        affiliateName: currentBill.affiliateName,
        customerId: currentBill.customerId,
        affiliateId: currentBill.affiliateId,
        receivedAmount: receivedAmount,
        splitCashAmount: finalSplitCash,
        splitCardAmount: finalSplitCard,
        discount: currentBill.discount, 
        referenceBillId: currentBill.referenceBillId,
        originalBillId: currentBill.originalBillId,
        billDate: currentBill.billDate,
        // Resolve Show Discount Setting
        showProductDiscount: currentBill.showProductDiscountOverride ?? ref.read(settingsProvider).value?.showProductDiscount ?? false,
      );

      // --- Change Here: Read attributes ---
      final sizes = await ref.read(sizesProvider.future);
      final colors = await ref.read(colorsProvider.future);
      
      print('Checkout: Loaded ${sizes.length} sizes and ${colors.length} colors.');
      
      await _posService.processCheckout(bill, sizes, colors);
      
      if (shouldPrint) {
        // Fetch settings for print configuration
        final settings = ref.read(settingsProvider).value ?? const AppSettings();
        // Pass the resolved bill which now contains the display preference
        final printer = BillPrinterService(bill, settings);
        await printer.printBill();
      }
      
      clearCart();
    } catch (e) {
      _updateActiveBill(state.activeBill.copyWith(isProcessing: false));
      rethrow;
    }
  }

  Future<void> holdBill() async {
    final currentBill = state.activeBill;
    if (currentBill.items.isEmpty) return;
    
    _updateActiveBill(currentBill.copyWith(isProcessing: true));

    try {
      final bill = Bill(
        id: const Uuid().v4(),
        billNumber: 'HOLD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        items: currentBill.items,
        totalAmount: currentBill.totalAmount,
        subTotal: currentBill.subTotal,
        paymentMethod: currentBill.paymentMethod,
        status: 'Pending',
        createdAt: DateTime.now(),
        customerName: currentBill.customerName,
        customerPhone: currentBill.customerPhone,
        affiliateName: currentBill.affiliateName,
      );

      await _posService.holdBill(bill);
      clearCart();
    } catch (e) {
      _updateActiveBill(state.activeBill.copyWith(isProcessing: false));
      rethrow;
    }
  }

  void resumeBill(Bill bill) {
    // When resuming, we can overwrite current empty bill or create new one.
    // Logic: If current bill is empty, use it. Else create new tab.
    if (state.activeBill.items.isEmpty && state.activeBill.customerName == null) {
        _updateActiveBill(SingleBillState(
          id: state.activeBill.id,
          items: bill.items,
          customerName: bill.customerName,
          customerPhone: bill.customerPhone,
          affiliateName: bill.affiliateName,
          paymentMethod: bill.paymentMethod,
        ));
    } else {
        createNewBill();
        _updateActiveBill(SingleBillState(
          id: state.activeBill.id,
          items: bill.items,
          customerName: bill.customerName,
          customerPhone: bill.customerPhone,
           affiliateName: bill.affiliateName,
          paymentMethod: bill.paymentMethod,
        ));
    }
    _posService.deletePendingBill(bill.id);
  }
}

// --- Providers ---
final cartProvider = NotifierProvider<CartNotifier, GlobalCartState>(CartNotifier.new);

final recentBillsProvider = StreamProvider<List<Bill>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final isAdministrator = user?.isAdministrator ?? false;
  return ref.watch(posServiceProvider).getRecentBills(isAdministrator: isAdministrator);
});

final pendingBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(posServiceProvider).getPendingBills();
});
