import '../../products/data/models/product_model.dart';
import '../../products/data/models/stock_model.dart';
import '../../products/data/models/attribute_models.dart';
import '../data/models/social_settings_model.dart';
import '../data/constants/marketing_templates.dart';
import '../../settings/data/providers/settings_provider.dart'; // Added AppSettings

class MarketingEngine {
  
  static String generateContent({
    required Product product,
    required List<StockItem> stocks,
    required MarketingTemplate template,
    required SocialSettings settings,
    required AppSettings appSettings, // Added
    required List<ProductSize> sizes,
    required List<ProductColor> colors,
    required bool showInstagram,
    required bool showWebsite,
    required bool showContact,
    String? customLinkOverride,
  }) {
    // attribute maps
    final sizeMap = {for (var s in sizes) s.id!: s.name};
    final colorMap = {for (var c in colors) c.id!: c.name};

    String content = template.content;
    
    // 1. Core Placeholders
    content = content.replaceAll('[Name]', product.name);
    content = content.replaceAll('[Price]', product.price.toStringAsFixed(0));
    
    // 2. Stock Logic
    final stockListStr = _formatStockList(stocks, sizeMap, colorMap);
    content = content.replaceAll('[Stock_List]', stockListStr);

    // 3. Link Logic
    final links = <String>[];
    
    if (customLinkOverride != null && customLinkOverride.isNotEmpty) {
       links.add('📲 $customLinkOverride');
    } else {
       // Just the number as requested
       if (settings.whatsappNumber.isNotEmpty) {
           links.add('📲 ${settings.whatsappNumber}');
       }
    }
    
    String mainLink = '';
    if (links.isNotEmpty) {
       mainLink = links.first;
    } else if (settings.websiteUrl.isNotEmpty) {
       mainLink = settings.websiteUrl;
    }
    
    content = content.replaceAll('[Link]', mainLink);

    // Footer Links
    final footer = StringBuffer();
    if (showInstagram && settings.instagramUrl.isNotEmpty) footer.writeln('📸 IG: ${settings.instagramUrl}');
    if (showWebsite && settings.websiteUrl.isNotEmpty) footer.writeln('🌐 Web: ${settings.websiteUrl}');
    if (showContact && settings.customContactName.isNotEmpty) footer.writeln('📍 ${settings.customContactName}');
    
    // Add Community Link from AppSettings (stored in "settings print functions" area)
    if (appSettings.whatsappLink.isNotEmpty) {
      footer.writeln('\n👇 Join our Community:');
      footer.writeln(appSettings.whatsappLink);
    } else if (appSettings.whatsappLinkLabel.isNotEmpty) { // Fallback to label if link empty? Unlikely but safe
       // footer.writeln(appSettings.whatsappLinkLabel); 
    }

    if (footer.isNotEmpty) {
      content = '$content\n\n${footer.toString().trim()}';
    }

    return content;
  }

  static String _formatStockList(
    List<StockItem> stocks, 
    Map<String, String> sizeMap, 
    Map<String, String> colorMap
  ) {
    if (stocks.isEmpty) return 'Out of Stock ❌';

    final Map<String, List<String>> grouped = {};
    
    // Group stocks by Color Name
    for (var stock in stocks) {
      if (stock.quantity <= 0) continue;
      
      final colorName = colorMap[stock.colorId] ?? 'Standard';
      final sizeName = sizeMap[stock.sizeId] ?? 'One Size';
      
      if (!grouped.containsKey(colorName)) {
        grouped[colorName] = [];
      }
      if (!grouped[colorName]!.contains(sizeName)) {
        grouped[colorName]!.add(sizeName);
      }
    }
    
    if (grouped.isEmpty) return 'Out of Stock ❌';

    final buffer = StringBuffer();
    grouped.forEach((color, sizeNames) {
      // Sort sizes using original list if possible, or just alpha
      // For now, simpler alpha sort is fine or we rely on insertion order which is often size-ordered if configured well
      sizeNames.sort(); 
      
      final sizeStr = sizeNames.join(', ');
      final line = '📍 $color ($sizeStr)';
      
      // Privacy/Urgency: Count total for this Color Name
      // We look up all stocks where colorId corresponds to this colorName
      // Optimization: This loop is acceptable for typical inventory sizes (dozens of SKUs)
      
      int totalForColor = 0;
      for (var s in stocks) {
         final sColor = colorMap[s.colorId] ?? 'Standard';
         if (sColor == color) totalForColor += s.quantity;
      }
          
      final status = totalForColor < 3 ? '⚠️ Low Stock' : '✅';
      
      buffer.writeln('$line $status');
    });

    return buffer.toString().trim();
  }
}
