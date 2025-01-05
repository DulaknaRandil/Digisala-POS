import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/models/product_model.dart';

class SearchBar extends StatefulWidget {
  final Function(Product) onAddProduct;
  final String? initialValue;
  final String? hintText;
  final FocusNode? focusNode; // Add focusNode parameter

  const SearchBar({
    Key? key,
    required this.onAddProduct,
    this.initialValue,
    this.hintText = 'Search by barcode, name or ID',
    this.focusNode, // Initialize focusNode
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  List<Product> _searchResults = [];
  int _highlightedIndex = -1;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String? _lastProcessedBarcode;
  bool _isProcessingBarcode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ??
        FocusNode(); // Use provided focusNode or create a new one
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideOverlay();
    if (widget.focusNode == null) {
      _focusNode.dispose(); // Dispose only if it was created here
    }
    _controller.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_isProcessingBarcode)
      return; // Prevent showing overlay during barcode processing
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

  bool _isBarcodeMatch(String value, Product product) {
    return product.barcode == value && value.length >= 5;
  }

  void _handleSearch(String value) async {
    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _highlightedIndex = -1;
        _lastProcessedBarcode = null;
      });
      _hideOverlay();
      return;
    }

    // Prevent processing if this barcode was just processed
    if (value == _lastProcessedBarcode) {
      return;
    }

    try {
      final results = await DatabaseHelper.instance.searchProducts(value);

      if (results.isEmpty) {
        setState(() {
          _searchResults = [];
          _highlightedIndex = -1;
        });
        _hideOverlay();
        return;
      }

      // Check if this is a barcode scan
      if (results.length == 1 && _isBarcodeMatch(value, results[0])) {
        _isProcessingBarcode = true;
        _lastProcessedBarcode = value;
        _addProduct(results[0]);

        // Clear text and request focus immediately
        _controller.clear();
        _focusNode.requestFocus();
        _isProcessingBarcode = false;

        _hideOverlay();
        return;
      }

      setState(() {
        _searchResults = results;
        _highlightedIndex = 0;
        _lastProcessedBarcode = null;
      });
      _showOverlay();
    } catch (e) {
      print('Error searching products: $e');
      _hideOverlay();
    }
  }

  void _addProduct(Product product) {
    if (!_isProcessingBarcode) {
      widget.onAddProduct(product);
    }
  }

  void _selectProduct(Product product) {
    if (_isProcessingBarcode)
      return; // Prevent selection during barcode processing
    _addProduct(product);
    _controller.clear();
    setState(() {
      _highlightedIndex = -1;
      _searchResults = [];
      _lastProcessedBarcode = null;
    });
    _hideOverlay();

    // Request focus after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleKeyNavigation(KeyEvent event) {
    if (_searchResults.isEmpty || _isProcessingBarcode) return;

    if (event is KeyDownEvent) {
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
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyNavigation,
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
                  focusNode: _focusNode,
                  onChanged: _handleSearch,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              SizedBox(
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
