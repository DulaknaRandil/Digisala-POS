import 'package:digisala_pos/models/product_model.dart';

class DiscountManager {
  bool isItemMode = false;
  Map<String, ItemDiscount> itemDiscounts = {};
  double orderDiscountValue = 0.0;
  bool orderDiscountIsPercentage = true;

  void setOrderDiscount(double value, bool isPercent) {
    orderDiscountValue = value;
    orderDiscountIsPercentage = isPercent;
  }

  void setItemDiscount(String productId, double value, bool isPercent) {
    itemDiscounts[productId] =
        ItemDiscount(value: value, isPercentage: isPercent);
  }

  void removeItemDiscount(String productId) {
    itemDiscounts.remove(productId);
  }

  double calculateDiscount(Map<String, dynamic> items) {
    double totalDiscount = 0.0;

    // Calculate item-specific discounts
    items.forEach((productId, item) {
      if (item is Product) {
        double itemTotal = item.price * item.quantity;

        // Built-in product discount
        if (item.discount.isNotEmpty) {
          try {
            if (item.discount.endsWith('%')) {
              double percentValue =
                  double.parse(item.discount.replaceAll('%', '').trim());
              totalDiscount += itemTotal * (percentValue / 100);
            } else {
              double fixedValue = double.parse(item.discount.trim());
              totalDiscount += fixedValue * item.quantity;
            }
          } catch (e) {
            print('Error parsing product discount: ${e.toString()}');
          }
        }

        // Manual item discount
        if (isItemMode && itemDiscounts.containsKey(productId)) {
          final discount = itemDiscounts[productId]!;
          totalDiscount += discount.isPercentage
              ? itemTotal * (discount.value / 100)
              : discount.value;
        }
      }
    });

    // Order-level discount if not in item mode
    if (!isItemMode) {
      double subtotal = items.values.fold(0.0, (sum, item) {
        if (item is Product) {
          return sum + (item.price * item.quantity);
        }
        return sum;
      });

      if (subtotal > 0) {
        totalDiscount += orderDiscountIsPercentage
            ? subtotal * (orderDiscountValue / 100)
            : orderDiscountValue;
      }
    }

    return totalDiscount;
  }

  double calculateItemDiscount(String productId, double itemTotal,
      double currentSubtotal, Product product) {
    double totalItemDiscount = 0.0;

    // Calculate built-in product discount
    if (product.discount.isNotEmpty) {
      try {
        if (product.discount.endsWith('%')) {
          double percentValue =
              double.parse(product.discount.replaceAll('%', '').trim());
          totalItemDiscount += itemTotal * (percentValue / 100);
        } else {
          double fixedValue = double.parse(product.discount.trim());
          totalItemDiscount += fixedValue * product.quantity;
        }
      } catch (e) {
        print('Error parsing product discount: ${e.toString()}');
      }
    }

    // Add manual item discount if in item mode
    if (isItemMode && itemDiscounts.containsKey(productId)) {
      final discount = itemDiscounts[productId]!;
      totalItemDiscount += discount.isPercentage
          ? itemTotal * (discount.value / 100)
          : discount.value;
    }

    // Add proportional order discount if not in item mode
    if (!isItemMode && currentSubtotal > 0) {
      double orderDiscount = orderDiscountIsPercentage
          ? currentSubtotal * (orderDiscountValue / 100)
          : orderDiscountValue.clamp(0,
              currentSubtotal); // Prevent negative discount or exceeding subtotal
      totalItemDiscount += (itemTotal / currentSubtotal) * orderDiscount;
    }

    return totalItemDiscount;
  }

  void reset() {
    orderDiscountValue = 0.0;
    orderDiscountIsPercentage = true;
    itemDiscounts.clear();
  }

  void toggleMode() {
    isItemMode = !isItemMode;

    // Clear order discounts if switching to item mode and vice versa
    if (isItemMode) {
      orderDiscountValue = 0.0;
    } else {
      itemDiscounts.clear();
    }
  }
}

class ItemDiscount {
  final double value;
  final bool isPercentage;

  ItemDiscount({
    required this.value,
    required this.isPercentage,
  });
}
