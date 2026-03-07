enum MarketingTemplateType {
  luxury,
  flashSale,
  newArrival,
  restockAlert,
  featureFocus,
  giftGuide,
  bestSeller,
  limitedEdition,
  clearance,
  dailyEssential,
  weekendSpecial,
}

class MarketingTemplate {
  final MarketingTemplateType type;
  final String label;
  final String icon;
  final String content;

  const MarketingTemplate({
    required this.type,
    required this.label,
    required this.icon,
    required this.content,
  });
}

class MarketingTemplates {
  static const List<MarketingTemplate> all = [
    MarketingTemplate(
      type: MarketingTemplateType.luxury,
      label: 'Luxury Boutique',
      icon: '💎',
      content: "✨ [Name] ✨\n\n💎 Elevate your style with this premium piece.\n💰 LKR [Price]\n\n🛍️ [Stock_List]\n\n📲 Order: [Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.flashSale,
      label: 'Flash Sale',
      icon: '🔥',
      content: "🔥 FLASH SALE! 🔥\n\n[Name]\n💸 ONLY LKR [Price]!\n\n⚠️ LOW STOCK:\n[Stock_List]\n\n🏃‍♂️ First come, first served!\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.newArrival,
      label: 'New Arrival',
      icon: '🆕',
      content: "🆕 JUST LANDED! 🆕\n\nBe the first to own the [Name].\n💰 LKR [Price]\n\n✨ Available:\n[Stock_List]\n\n🛍️ Shop now: [Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.restockAlert,
      label: 'Restock Alert',
      icon: '🎉',
      content: "🎉 BACK IN STOCK! 🎉\n\nYou asked, we delivered. [Name] is back!\n💰 LKR [Price]\n\n✅ [Stock_List]\n\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.featureFocus,
      label: 'Feature Focus',
      icon: '☁️',
      content: "☁️ QUALITY YOU CAN FEEL ☁️\n\n[Name]\n✨ Imported, skin-friendly material.\n💰 LKR [Price]\n\n📍 Available in:\n[Stock_List]\n\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.giftGuide,
      label: 'Gift Guide',
      icon: '🎁',
      content: "🎁 THE PERFECT GIFT 🎁\n\nSurprise her with the [Name].\n💰 LKR [Price]\n\n🎀 Available designs:\n[Stock_List]\n\n🚚 Islandwide Delivery.\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.bestSeller,
      label: 'Best Seller',
      icon: '⭐',
      content: "⭐️ OUR #1 BEST SELLER ⭐️\n\nThe [Name] is loved by 100+ customers!\n💰 LKR [Price]\n\n✅ Grab yours:\n[Stock_List]\n\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.limitedEdition,
      label: 'Limited Edition',
      icon: '💎',
      content: "💎 EXCLUSIVE & LIMITED 💎\n\nOnce it's gone, it's gone. [Name].\n💰 LKR [Price]\n\n📍 [Stock_List]\n\n📲 Reserve now: [Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.clearance,
      label: 'Clearance',
      icon: '🚨',
      content: "🚨 FINAL CLEARANCE 🚨\n\nHuge savings on [Name].\n📉 LKR [Price]\n\n⚠️ [Stock_List] only.\nNo restocks!\n\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.dailyEssential,
      label: 'Daily Essential',
      icon: '🌸',
      content: "🌸 YOUR DAILY FAVORITE 🌸\n\n[Name] for effortless style.\n💰 LKR [Price]\n\n✅ In Stock:\n[Stock_List]\n\n[Link]",
    ),
    MarketingTemplate(
      type: MarketingTemplateType.weekendSpecial,
      label: 'Weekend Special',
      icon: '🥂',
      content: "🥂 WEEKEND VIBES 🥂\n\nGrab the [Name] for your weekend plans!\n💰 LKR [Price]\n\n✨ [Stock_List]\n\n🚀 Fast Dispatch.\n[Link]",
    ),
  ];
}
