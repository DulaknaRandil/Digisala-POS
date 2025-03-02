import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/product_model.dart';

class SearchBar extends StatefulWidget {
  final Function(Product) onAddProduct;
  final String? initialValue;
  final String? hintText;
  final FocusNode? focusNode;

  const SearchBar({
    Key? key,
    required this.onAddProduct,
    this.initialValue,
    this.hintText = 'Search by barcode, name or ID',
    this.focusNode,
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

  // State variable to track the selected search type.
  String _selectedSearchType = 'Barcode';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();

    // Set initial focus to the search bar after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideOverlay();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_isProcessingBarcode) return;
    _hideOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(),
    );
    overlay.insert(_overlayEntry!);
  }

  // Extract overlay building to a separate method
  Widget _buildOverlay() {
    return Positioned(
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
                    subtitle:
                        Text('ID: ${product.id}, Barcode: ${product.barcode}'),
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
    );
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
        _lastProcessedBarcode = null;
      });
      _hideOverlay();
      return;
    }

    // Prevent processing if this barcode was just processed.
    if (value == _lastProcessedBarcode) {
      return;
    }

    try {
      final results = await DatabaseHelper.instance.searchProducts(value);

      // Filter out inactive products or those with zero quantity.
      final initialFiltered = results.where((product) {
        return product.status != 'Inactive' && product.quantity > 0;
      }).toList();

      if (_selectedSearchType == 'Barcode') {
        // Find all exact matches for the barcode.
        final matchingProducts = initialFiltered
            .where((product) => product.barcode == value)
            .toList();

        if (matchingProducts.isEmpty) {
          // No exact match found: clear suggestions.
          setState(() {
            _searchResults = [];
            _highlightedIndex = -1;
          });
          _hideOverlay();
        } else if (matchingProducts.length == 1) {
          // Only one match, auto-select it.
          _isProcessingBarcode = true;
          _lastProcessedBarcode = value;
          _addProduct(matchingProducts.first);
          _controller.clear();
          _focusNode.requestFocus();
          _isProcessingBarcode = false;
          _hideOverlay();
          _lastProcessedBarcode = null;
        } else {
          // Multiple matches exist; show them in the overlay for manual selection.
          setState(() {
            _searchResults = matchingProducts;
            _highlightedIndex = 0;
            _lastProcessedBarcode = null;
          });
          _showOverlay();
        }
        return;
      }

      // For Name or ID search types, filter results accordingly.
      final filteredResults = initialFiltered.where((product) {
        if (_selectedSearchType == 'Name') {
          return product.name.toLowerCase().contains(value.toLowerCase());
        } else if (_selectedSearchType == 'ID') {
          return product.id.toString().contains(value);
        }
        return false;
      }).toList();

      if (filteredResults.isEmpty) {
        setState(() {
          _searchResults = [];
          _highlightedIndex = -1;
        });
        _hideOverlay();
        return;
      }

      setState(() {
        _searchResults = filteredResults;
        _highlightedIndex = 0;
        _lastProcessedBarcode = null;
      });
      _showOverlay();
    } catch (e) {
      print('Error searching products: $e');
      _hideOverlay();
    }
  }

  // _addProduct simply calls the callback.
  void _addProduct(Product product) {
    widget.onAddProduct(product);
    _controller.clear();
    _focusNode.requestFocus(); // Clear the search bar and request focus.
  }

  void _selectProduct(Product product) {
    if (_isProcessingBarcode) return;
    _addProduct(product);
    _controller.clear();
    setState(() {
      _highlightedIndex = -1;
      _searchResults = [];
      _lastProcessedBarcode = null;
    });
    _hideOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _moveSelectionUp() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _highlightedIndex = (_highlightedIndex - 1 + _searchResults.length) %
          _searchResults.length;
    });
    // Key fix: Refresh the overlay to show the new highlighted index
    _refreshOverlay();
  }

  void _moveSelectionDown() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _highlightedIndex = (_highlightedIndex + 1) % _searchResults.length;
    });
    // Key fix: Refresh the overlay to show the new highlighted index
    _refreshOverlay();
  }

  // New method to refresh the overlay when selection changes
  void _refreshOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _selectHighlightedProduct() {
    if (_searchResults.isEmpty ||
        _highlightedIndex < 0 ||
        _highlightedIndex >= _searchResults.length) return;
    _selectProduct(_searchResults[_highlightedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowUp): _moveSelectionUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown): _moveSelectionDown,
        const SingleActivator(LogicalKeyboardKey.enter):
            _selectHighlightedProduct,
        const SingleActivator(LogicalKeyboardKey.escape): _hideOverlay,
      },
      child: Focus(
        autofocus: true,
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
                // Dropdown to select the search type.
                Container(
                  margin: const EdgeInsets.only(left: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSearchType,
                      dropdownColor: Colors.white,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSearchType = newValue!;
                        });
                        // After a dropdown selection, shift focus back to the search bar.
                        _focusNode.requestFocus();
                      },
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.black),
                      items: <String>['Barcode', 'Name', 'ID']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(color: Colors.black),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _handleSearch,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (value) {
                      if (_searchResults.isNotEmpty && _highlightedIndex >= 0) {
                        _selectProduct(_searchResults[_highlightedIndex]);
                      } else {
                        _handleSearch(value);
                      }
                    },
                    // Key handlers for the TextField specifically
                    onEditingComplete: () {
                      if (_searchResults.isNotEmpty && _highlightedIndex >= 0) {
                        _selectProduct(_searchResults[_highlightedIndex]);
                      }
                    },
                    // Force focus to stay in the field when arrow keys are pressed
                    textInputAction: TextInputAction.none,
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
      ),
    );
  }
}
