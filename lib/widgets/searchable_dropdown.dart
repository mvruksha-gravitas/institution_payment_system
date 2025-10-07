import 'package:flutter/material.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final List<T> options;
  final String Function(T option) displayString;
  final void Function(T option)? onSelected;
  final void Function(String query)? onQueryChanged;
  final String labelText;
  final IconData prefixIcon;
  final double maxOptionsHeight;
  final String? initialText;

  const SearchableDropdown({super.key, required this.options, required this.displayString, this.onSelected, this.onQueryChanged, this.labelText = 'Search', this.prefixIcon = Icons.search, this.maxOptionsHeight = 300, this.initialText});

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText && widget.initialText != null && widget.initialText != _controller.text) {
      _controller.text = widget.initialText!;
    }
    // Rebuild overlay when options change
    if (_overlayEntry != null) _overlayEntry!.markNeedsBuild();
  }

  void _onTextChanged() {
    widget.onQueryChanged?.call(_controller.text.trim());
    _overlayEntry?.markNeedsBuild();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(builder: (context) {
      final theme = Theme.of(context);
      final query = _controller.text.toLowerCase();
      final filtered = widget.options.where((o) {
        final label = widget.displayString(o).toLowerCase();
        return query.isEmpty || label.contains(query);
      }).toList();
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _focusNode.unfocus(),
          child: Stack(children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 56),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxOptionsHeight, minWidth: 240),
                  child: filtered.isEmpty
                      ? Container(
                          color: theme.cardColor,
                          padding: const EdgeInsets.all(12),
                          child: const Text('No results'),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final option = filtered[index];
                            final label = widget.displayString(option);
                            return InkWell(
                              onTap: () {
                                _controller.text = label;
                                _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                                widget.onQueryChanged?.call(label);
                                widget.onSelected?.call(option);
                                _focusNode.unfocus();
                              },
                              child: Container(
                                color: theme.cardColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(label, overflow: TextOverflow.ellipsis),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
    Overlay.of(context, debugRequiredFor: widget)!.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: widget.labelText,
          prefixIcon: Icon(widget.prefixIcon, color: Colors.blue),
          isDense: true,
        ),
        onTap: () {
          // Open the dropdown immediately on tap
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          } else {
            // Force rebuild to ensure options visible even if text is unchanged
            _overlayEntry?.markNeedsBuild();
          }
        },
        onChanged: (_) {},
      ),
    );
  }
}
