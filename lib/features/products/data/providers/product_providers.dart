import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final service = ref.watch(productServiceProvider);
  return service.getProducts();
});
