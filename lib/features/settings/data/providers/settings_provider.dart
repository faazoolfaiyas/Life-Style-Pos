import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple model for App Settings
// Simple model for App Settings
class AppSettings {
  final int purchaseOrderRetentionDays;
  final double productCardSize;
  final double productTextScale;
  final bool printGlobalDiscountOnly;
  final String billAddress;
  final String whatsappLink;
  final String logoPath;
  // New Fields
  final String billFooterText;
  final String whatsappLinkLabel;
  final bool showProductDiscount;

  const AppSettings({
    this.purchaseOrderRetentionDays = 30,
    this.productCardSize = 240.0,
    this.productTextScale = 1.0,
    this.printGlobalDiscountOnly = false,
    this.billAddress = 'No. 123, Main Street, Colombo',
    this.whatsappLink = '',
    this.logoPath = r'D:\Folders\Downloads\life_style\life_style\lifestyle_logo_black.png',
    this.billFooterText = 'Thank You for Shopping!',
    this.whatsappLinkLabel = 'Scan to Contact Us',
    this.showProductDiscount = false,
  });

  AppSettings copyWith({
    int? purchaseOrderRetentionDays,
    double? productCardSize,
    double? productTextScale,
    bool? printGlobalDiscountOnly,
    String? billAddress,
    String? whatsappLink,
    String? logoPath,
    String? billFooterText,
    String? whatsappLinkLabel,
    bool? showProductDiscount,
  }) {
    return AppSettings(
      purchaseOrderRetentionDays: purchaseOrderRetentionDays ?? this.purchaseOrderRetentionDays,
      productCardSize: productCardSize ?? this.productCardSize,
      productTextScale: productTextScale ?? this.productTextScale,
      printGlobalDiscountOnly: printGlobalDiscountOnly ?? this.printGlobalDiscountOnly,
      billAddress: billAddress ?? this.billAddress,
      whatsappLink: whatsappLink ?? this.whatsappLink,
      logoPath: logoPath ?? this.logoPath,
      billFooterText: billFooterText ?? this.billFooterText,
      whatsappLinkLabel: whatsappLinkLabel ?? this.whatsappLinkLabel,
      showProductDiscount: showProductDiscount ?? this.showProductDiscount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseOrderRetentionDays': purchaseOrderRetentionDays,
      'productCardSize': productCardSize,
      'productTextScale': productTextScale,
      'printGlobalDiscountOnly': printGlobalDiscountOnly,
      'billAddress': billAddress,
      'whatsappLink': whatsappLink,
      'logoPath': logoPath,
      'billFooterText': billFooterText,
      'whatsappLinkLabel': whatsappLinkLabel,
      'showProductDiscount': showProductDiscount,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      purchaseOrderRetentionDays: map['purchaseOrderRetentionDays'] as int? ?? 30,
      productCardSize: (map['productCardSize'] is num) 
          ? (map['productCardSize'] as num).toDouble() 
          : 240.0,
      productTextScale: (map['productTextScale'] is num) 
          ? (map['productTextScale'] as num).toDouble() 
          : 1.0,
      printGlobalDiscountOnly: map['printGlobalDiscountOnly'] as bool? ?? false,
      billAddress: map['billAddress'] as String? ?? 'No. 123, Main Street, Colombo',
      whatsappLink: map['whatsappLink'] as String? ?? '',
      logoPath: map['logoPath'] as String? ?? '',
      billFooterText: map['billFooterText'] as String? ?? 'Thank You for Shopping!',
      whatsappLinkLabel: map['whatsappLinkLabel'] as String? ?? 'Scan to Contact Us',
      showProductDiscount: map['showProductDiscount'] as bool? ?? false,
    );
  }
}

// Controller using AsyncNotifier (Riverpod 2.0 compliant)
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<AppSettings> build() async {
    return _fetchSettings();
  }

  Future<AppSettings> _fetchSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('general').get();
      if (doc.exists && doc.data() != null) {
        return AppSettings.fromMap(doc.data()!);
      } else {
        // Initialize default
        final defaultSettings = const AppSettings();
        await _firestore.collection('settings').doc('general').set(defaultSettings.toMap());
        return defaultSettings;
      }
    } catch (e) {
      // Return default on error or rethrow? 
      // Rethrow to let UI handle error state
      rethrow; 
    }
  }

  Future<void> updateRetentionDays(int days) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(purchaseOrderRetentionDays: days);
    await _saveSettings(updated);
  }

  Future<void> updateProductCardSize(double size) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(productCardSize: size);
    await _saveSettings(updated);
  }

  Future<void> updateProductTextScale(double scale) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(productTextScale: scale);
    await _saveSettings(updated);
  }

  Future<void> updatePrintGlobalDiscountOnly(bool val) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(printGlobalDiscountOnly: val);
    await _saveSettings(updated);
  }

  Future<void> updateBillSettings({
    String? address, 
    String? whatsapp, 
    String? logo, 
    String? footerText, 
    String? whatsappLabel,
    bool? showProductDiscount,
  }) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(
      billAddress: address,
      whatsappLink: whatsapp,
      logoPath: logo,
      billFooterText: footerText,
      whatsappLinkLabel: whatsappLabel,
      showProductDiscount: showProductDiscount,
    );
    await _saveSettings(updated);
  }

  Future<void> _saveSettings(AppSettings updated) async {
    state = AsyncValue.data(updated);
    try {
      await _firestore.collection('settings').doc('general').set(updated.toMap(), SetOptions(merge: true));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      ref.invalidateSelf();
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
