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
    if (isItemMode) {
      itemDiscounts[productId] =
          ItemDiscount(value: value, isPercentage: isPercent);
    }
  }

  void removeItemDiscount(String productId) {
    itemDiscounts.remove(productId);
  }

  double calculateDiscount(Map<String, double> items) {
    if (items.isEmpty) {
      reset();
      return 0.0;
    }

    double totalDiscount = 0.0;
    double subtotal = items.values.fold(0.0, (sum, price) => sum + price);

    if (isItemMode) {
      // Calculate individual item discounts
      items.forEach((productId, itemPrice) {
        if (itemDiscounts.containsKey(productId)) {
          final discount = itemDiscounts[productId]!;
          totalDiscount += discount.isPercentage
              ? itemPrice * (discount.value / 100)
              : discount.value;
        }
      });
    } else {
      // Calculate order-level discount
      if (orderDiscountIsPercentage) {
        totalDiscount = subtotal * (orderDiscountValue / 100);
      } else {
        totalDiscount = orderDiscountValue;
      }
    }

    return totalDiscount;
  }

  double calculateItemDiscount(
      String productId, double itemPrice, double currentSubtotal) {
    if (currentSubtotal <= 0) {
      return 0.0;
    }

    if (isItemMode) {
      final itemDiscount = itemDiscounts[productId];
      if (itemDiscount == null) return 0.0;

      return itemDiscount.isPercentage
          ? itemPrice * (itemDiscount.value / 100)
          : itemDiscount.value;
    } else {
      // For order-level discount, calculate proportional amount for this item
      double totalOrderDiscount = orderDiscountIsPercentage
          ? currentSubtotal * (orderDiscountValue / 100)
          : orderDiscountValue;

      return (itemPrice / currentSubtotal) * totalOrderDiscount;
    }
  }

  void reset() {
    orderDiscountValue = 0.0;
    orderDiscountIsPercentage = true;
    itemDiscounts.clear();
  }

  void toggleMode() {
    isItemMode = !isItemMode;
    reset();
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
