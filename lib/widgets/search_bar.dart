import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _highlightedIndex = -1; // Track the highlighted item
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
          offset: const Offset(0, 65),
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
                  final isHighlighted = index == _highlightedIndex;
                  return Container(
                    color: isHighlighted ? Colors.blue.withOpacity(0.2) : null,
                    child: ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                          'ID: ${product.id}, Barcode: ${product.barcode}'),
                      onTap: () {
                        _selectProduct(product);
                      },
                    ),
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
        _highlightedIndex = -1;
      });
      _hideOverlay();
      return;
    }

    try {
      final results = await DatabaseHelper.instance.searchProducts(value);
      setState(() {
        _searchResults = results;
        _highlightedIndex = results.isNotEmpty ? 0 : -1;
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

  void _selectProduct(Product product) {
    widget.onAddProduct(product);
    _controller.clear(); // Clear the search bar
    _hideOverlay();
    setState(() {
      _highlightedIndex = -1;
      _searchResults = [];
    });
  }

  void _handleKeyNavigation(RawKeyEvent event) {
    if (_searchResults.isEmpty) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _highlightedIndex = (_highlightedIndex + 1) % _searchResults.length;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _highlightedIndex = (_highlightedIndex - 1 + _searchResults.length) %
              _searchResults.length;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_highlightedIndex >= 0 &&
            _highlightedIndex < _searchResults.length) {
          _selectProduct(_searchResults[_highlightedIndex]);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyNavigation,
      child: CompositedTransformTarget(
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
      ),
    );
  }
}
