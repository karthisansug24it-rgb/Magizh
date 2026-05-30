import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // To access productsProvider, SoundManager, Haptics
import 'theme/app_theme.dart';

class InventorySheet extends ConsumerStatefulWidget {
  const InventorySheet({super.key});

  @override
  ConsumerState<InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends ConsumerState<InventorySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Local state to track changes before saving
  final Map<String, int> _stockChanges = {};
  final Set<String> _productsToDelete = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateStock(String id, int delta, int currentStock) {
    Haptics.light();
    setState(() {
      int newStock = (_stockChanges[id] ?? currentStock) + delta;
      if (newStock < 0) newStock = 0;
      _stockChanges[id] = newStock;
    });
  }

  void _markForDeletion(String id) {
    Haptics.medium();
    setState(() {
      _productsToDelete.add(id);
    });
  }

  Future<void> _saveChanges() async {
    if (_stockChanges.isEmpty && _productsToDelete.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    Haptics.success();

    try {
      final client = Supabase.instance.client;
      // Process updates
      for (final entry in _stockChanges.entries) {
        if (!_productsToDelete.contains(entry.key)) {
          await client.from('products').update({'stock_qty': entry.value}).eq('id', entry.key);
        }
      }
      // Process deletes (set is_active = false)
      for (final id in _productsToDelete) {
        await client.from('products').update({'is_active': false}).eq('id', id);
      }

      // Refresh global products provider
      final response = await client.from('products').select().eq('is_active', true).order('name');
      ref.read(productsProvider.notifier).set(List<Map<String, dynamic>>.from(response));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  void _openAddProductsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const AddProductsToInventorySheet(),
    ).then((_) {
      // Re-fetch when closed in case items were added
      _fetchProducts();
    });
  }

  Future<void> _fetchProducts() async {
    final response = await Supabase.instance.client.from('products').select().eq('is_active', true).order('name');
    ref.read(productsProvider.notifier).set(List<Map<String, dynamic>>.from(response));
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productsProvider);
    final activeProducts = allProducts.where((p) => !_productsToDelete.contains(p['id'])).toList();

    final filteredProducts = activeProducts.where((p) {
      return p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Inventory",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            "Adjust quantities and upload",
            style: TextStyle(fontSize: 14, color: AppTheme.primary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: "Search products...",
                prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // List
          Expanded(
            child: ListView.separated(
              itemCount: filteredProducts.length,
              separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final p = filteredProducts[index];
                final id = p['id'];
                final originalStock = (p['stock_qty'] as num?)?.toInt() ?? 0;
                final displayStock = _stockChanges[id] ?? originalStock;

                return Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: _buildImage(p['image_url']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black)),
                          Text(p['category'] ?? 'N/A', style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.7), fontSize: 13)),
                        ],
                      ),
                    ),
                    // Controls
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary),
                          onPressed: () => _updateStock(id, -1, originalStock),
                        ),
                        SizedBox(
                          width: 55,
                          child: TextField(
                            key: ValueKey("$id-$displayStock"),
                            onChanged: (val) {
                              final newVal = int.tryParse(val);
                              if (newVal != null) {
                                setState(() => _stockChanges[id] = newVal);
                              }
                            },
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            controller: TextEditingController(text: "$displayStock"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                          onPressed: () => _updateStock(id, 1, originalStock),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.primary),
                          onPressed: () => _markForDeletion(id),
                        ),
                      ],
                    )
                  ],
                );
              },
            ),
          ),
          // Bottom Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_stockChanges.isNotEmpty || _productsToDelete.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? "Saving..." : "Save"),
                        onPressed: _isSaving ? null : _saveChanges,
                      ),
                    ),
                  if (_stockChanges.isNotEmpty || _productsToDelete.isNotEmpty) const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("Add"),
                      onPressed: _openAddProductsSheet,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
    return Container(color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey));
  }
}

class AddProductsToInventorySheet extends StatefulWidget {
  const AddProductsToInventorySheet({super.key});

  @override
  State<AddProductsToInventorySheet> createState() => _AddProductsToInventorySheetState();
}

class _AddProductsToInventorySheetState extends State<AddProductsToInventorySheet> {
  List<Map<String, dynamic>> _inactiveProducts = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchInactiveProducts();
  }

  Future<void> _fetchInactiveProducts() async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('is_active', false)
          .order('name');
      if (mounted) {
        setState(() {
          _inactiveProducts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveSelected() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isSaving = true);
    Haptics.success();

    try {
      for (final id in _selectedIds) {
        await Supabase.instance.client.from('products').update({'is_active': true}).eq('id', id);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Add Products",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Pick snacks to restore in inventory",
            style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _inactiveProducts.isEmpty
                    ? const Center(child: Text("No inactive products found.", style: TextStyle(color: AppTheme.primary)))
                    : ListView.separated(
                        itemCount: _inactiveProducts.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
                        itemBuilder: (context, index) {
                          final p = _inactiveProducts[index];
                          final id = p['id'];
                          final isSelected = _selectedIds.contains(id);

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.fastfood_outlined, color: AppTheme.primary),
                            title: Text(p['name'], style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.primary)),
                            subtitle: Text(p['category'] ?? 'N/A', style: const TextStyle(color: AppTheme.primary)),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: Colors.grey.shade400,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              });
                            },
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedIds.isEmpty ? Colors.grey.shade300 : const Color(0xFFE0E0E0),
                    foregroundColor: _selectedIds.isEmpty ? Colors.grey.shade500 : AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  onPressed: _selectedIds.isEmpty || _isSaving ? null : _saveSelected,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Save to Inventory", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

