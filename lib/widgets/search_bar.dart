import 'package:flutter/material.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/models/product_model.dart';

class SearchBar extends StatefulWidget {
  final Function(Product) onAddProduct;
  final String? initialValue;
  final String? hintText;

  const SearchBar({
    Key? key,
    required this.onAddProduct,
    this.initialValue,
    this.hintText = 'Search by barcode, name or ID',
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;
  List<Product> _searchResults = [];
  Product? _selectedProduct;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _showOverlay() {
    _hideOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 611,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset:
              const Offset(0, 65), // Adjust this value to position the overlay
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle:
                        Text('ID: ${product.id}, Barcode: ${product.barcode}'),
                    onTap: () {
                      widget.onAddProduct(product);
                      _hideOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleSearch(String value) async {
    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedProduct = null;
      });
      _hideOverlay();
      return;
    }

    try {
      final results = await DatabaseHelper.instance.searchProducts(value);
      setState(() {
        _searchResults = results;
        _selectedProduct = null;
      });
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    } catch (e) {
      print('Error searching products: $e');
      _hideOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        width: 611,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _handleSearch,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            Container(
              width: 98,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _handleSearch(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E0FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(
                    color: Color(0xFF313131),
                    fontSize: 15,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
