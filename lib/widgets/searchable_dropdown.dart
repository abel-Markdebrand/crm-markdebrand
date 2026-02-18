import 'package:flutter/material.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T>? items;
  final Future<List<T>> Function(String query)? asyncItems;
  final String Function(T) itemLabel;
  final Widget Function(T)? itemBuilder;
  final void Function(T?) onChanged;
  final String? hint;
  final bool isRequired;
  final IconData? icon;

  const SearchableDropdown({
    super.key,
    required this.label,
    this.value,
    this.items,
    this.asyncItems,
    required this.itemLabel,
    required this.onChanged,
    this.itemBuilder,
    this.hint,
    this.isRequired = false,
    this.icon,
  }) : assert(items != null || asyncItems != null);

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'Nexa',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: () => _showSearchDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.value != null
                        ? widget.itemLabel(widget.value as T)
                        : (widget.hint ?? "Seleccionar..."),
                    style: TextStyle(
                      fontFamily: 'Nexa',
                      color: widget.value != null
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  widget.icon ?? Icons.arrow_drop_down,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SearchDialog<T>(
        title: widget.label,
        items: widget.items,
        asyncItems: widget.asyncItems,
        itemLabel: widget.itemLabel,
        itemBuilder: widget.itemBuilder,
        onSelected: (val) {
          widget.onChanged(val);
          // Navigator.pop(context) is handled inside _SearchDialog or explicitly here?
          // Usually handled by the item tap.
        },
      ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final String title;
  final List<T>? items;
  final Future<List<T>> Function(String query)? asyncItems;
  final String Function(T) itemLabel;
  final Widget Function(T)? itemBuilder;
  final ValueChanged<T> onSelected;

  const _SearchDialog({
    required this.title,
    this.items,
    this.asyncItems,
    required this.itemLabel,
    required this.onSelected,
    this.itemBuilder,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.items != null) {
      _filteredItems = List.from(widget.items!);
    } else {
      _loadAsyncItems("");
    }
  }

  void _onSearchChanged(String query) {
    if (widget.items != null) {
      // Local Filter
      setState(() {
        _filteredItems = widget.items!
            .where(
              (item) => widget
                  .itemLabel(item)
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList();
      });
    } else {
      // Async Filter (debounce could be added here)
      _loadAsyncItems(query);
    }
  }

  Future<void> _loadAsyncItems(String query) async {
    if (widget.asyncItems == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await widget.asyncItems!(query);
      if (mounted) {
        setState(() {
          _filteredItems = results;
        });
      }
    } catch (e) {
      debugPrint("Error searching: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'CenturyGothic',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Buscar...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        "No se encontraron resultados",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: widget.itemBuilder != null
                              ? widget.itemBuilder!(item)
                              : Text(
                                  widget.itemLabel(item),
                                  style: const TextStyle(
                                    fontFamily: 'Nexa',
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                          onTap: () {
                            widget.onSelected(item);
                            Navigator.pop(context);
                          },
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
