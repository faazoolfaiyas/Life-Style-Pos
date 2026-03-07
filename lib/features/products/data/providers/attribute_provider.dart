import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attribute_models.dart';
import '../services/attribute_service.dart';

final categoriesProvider = StreamProvider<List<ProductCategory>>((ref) {
  return ref.watch(attributeServiceProvider).getCategories();
});

final sizesProvider = StreamProvider<List<ProductSize>>((ref) {
  return ref.watch(attributeServiceProvider).getSizes();
});

final colorsProvider = StreamProvider<List<ProductColor>>((ref) {
  return ref.watch(attributeServiceProvider).getColors();
});

final designsProvider = StreamProvider<List<ProductDesign>>((ref) {
  return ref.watch(attributeServiceProvider).getDesigns();
});
