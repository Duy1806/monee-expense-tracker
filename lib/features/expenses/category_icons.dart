import 'package:flutter/material.dart';

IconData iconForCategory(String category) {
  switch (category) {
    case 'Ăn uống':
      return Icons.restaurant_rounded;
    case 'Di chuyển':
      return Icons.directions_bike_rounded;
    case 'Mua sắm':
      return Icons.shopping_bag_rounded;
    case 'Hóa đơn':
      return Icons.receipt_long_rounded;
    case 'Sức khỏe':
      return Icons.favorite_rounded;
    case 'Giải trí':
      return Icons.movie_rounded;
    case 'Giáo dục':
      return Icons.school_rounded;
    default:
      return Icons.category_rounded;
  }
}

Color colorForCategory(String category) {
  switch (category) {
    case 'Ăn uống':
      return const Color(0xFFF59E0B);
    case 'Di chuyển':
      return const Color(0xFF3B82F6);
    case 'Mua sắm':
      return const Color(0xFFEC4899);
    case 'Hóa đơn':
      return const Color(0xFF8B5CF6);
    case 'Sức khỏe':
      return const Color(0xFFEF4444);
    case 'Giải trí':
      return const Color(0xFF14B8A6);
    case 'Giáo dục':
      return const Color(0xFF6366F1);
    default:
      return const Color(0xFF64748B);
  }
}