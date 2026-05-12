import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('No .env file found, relying on dart-define');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError('Missing Supabase config.');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await SoundManager.instance.init();

  runApp(const ProviderScope(child: MagizhPosApp()));
}

class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();
  final List<AudioPlayer> _pool = List.generate(10, (_) => AudioPlayer());
  int _currentPlayerIndex = 0;
  bool _isReady = false;

  Future<void> init() async {
    try {
      for (final player in _pool) {
        await player.setPlayerMode(PlayerMode.mediaPlayer);
        await player.setSource(AssetSource('sound/tap.mp3'));
        await player.setVolume(1.0);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      _isReady = true;
    } catch (e) {
      debugPrint('SoundManager error: $e');
    }
  }

  Future<void> playClickSound() async {
    if (!_isReady) return;
    try {
      final player = _pool[_currentPlayerIndex];
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _pool.length;
      await player.stop();
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('SoundManager play error: $e');
    }
  }
}

class MagizhPosApp extends StatelessWidget {
  const MagizhPosApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magizh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B0000)),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        // iOS-like physics globally
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(false),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// Haptic feedback helper
class Haptics {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.vibrate();
}

enum AppTab { home, inventory, expense, history }

// Modern Notifiers for Riverpod 3.0+
class ProductsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];
  void set(List<Map<String, dynamic>> val) => state = val;
  void updateState(List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) fn) => state = fn(state);
}
final productsProvider = NotifierProvider<ProductsNotifier, List<Map<String, dynamic>>>(ProductsNotifier.new);

class LoadingNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  set val(bool v) => state = v;
}
final isLoadingProvider = NotifierProvider<LoadingNotifier, bool>(LoadingNotifier.new);

class CategoryNotifier extends Notifier<String> {
  @override
  String build() => "All";
  set val(String v) => state = v;
}
final selectedCategoryProvider = NotifierProvider<CategoryNotifier, String>(CategoryNotifier.new);

class SearchNotifier extends Notifier<String> {
  @override
  String build() => "";
  set val(String v) => state = v;
}
final searchProvider = NotifierProvider<SearchNotifier, String>(SearchNotifier.new);

class TapCountsNotifier extends Notifier<Map<dynamic, int>> {
  @override
  Map<dynamic, int> build() => {};
  void set(Map<dynamic, int> val) => state = val;
  void updateState(Map<dynamic, int> Function(Map<dynamic, int>) fn) => state = fn(state);
}
final tapCountsProvider = NotifierProvider<TapCountsNotifier, Map<dynamic, int>>(TapCountsNotifier.new);

class ErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  set val(String? v) => state = v;
}
final errorProvider = NotifierProvider<ErrorNotifier, String?>(ErrorNotifier.new);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final List<String> categories = ["All", "Puff", "Samosa", "Roll", "Drinks", "Other"];
  final TextEditingController _searchController = TextEditingController();
  AppTab _currentTab = AppTab.home;
  final Map<String, int> _inventoryQtyById = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    ref.read(isLoadingProvider.notifier).val = true;
    ref.read(errorProvider.notifier).val = null;
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .order('name');
      if (mounted) {
        final items = List<Map<String, dynamic>>.from(response);
        for (final row in items) {
          final id = row['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _inventoryQtyById[id] = (row['stock_qty'] as num?)?.toInt() ?? 0;
          }
        }
        ref.read(productsProvider.notifier).set(items);
        ref.read(isLoadingProvider.notifier).val = false;
      }
    } catch (e) {
      debugPrint('FETCH ERROR: $e');
      if (mounted) {
        ref.read(errorProvider.notifier).val = e.toString();
        ref.read(isLoadingProvider.notifier).val = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchProvider).toLowerCase();
    final tapCounts = ref.watch(tapCountsProvider);

    final filteredProducts = products.where((p) {
      final matchesCategory = selectedCategory == "All" || 
          p["category"].toString().toLowerCase() == selectedCategory.toLowerCase();
      return matchesCategory && p["name"].toString().toLowerCase().contains(searchQuery);
    }).toList();

    final showHome = _currentTab == AppTab.home;
    final selectedCount = tapCounts.values.fold<int>(0, (sum, count) => sum + count);
    final total = tapCounts.entries.fold<double>(0, (sum, entry) {
      final match = products.firstWhere((p) => p["id"] == entry.key, orElse: () => {});
      final priceValue = match["price"];
      final price = priceValue is num ? priceValue.toDouble() : double.tryParse(priceValue?.toString() ?? '') ?? 0.0;
      return sum + (price * entry.value);
    });

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (showHome)
              Column(
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  _buildCategories(),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
                        : ref.watch(errorProvider) != null
                            ? _buildErrorView()
                            : RepaintBoundary(
                                child: ScrollConfiguration(
                                  behavior: const ScrollBehavior().copyWith(physics: const BouncingScrollPhysics()),
                                  child: _buildProductGrid(filteredProducts),
                                ),
                              ),
                  ),
                ],
              )
            else
              _buildTabPlaceholder(),
            if (showHome && selectedCount > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 58 + MediaQuery.of(context).padding.bottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Selected: $selectedCount',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const Spacer(),
                          Text(
                            'Amount: ₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              Haptics.medium();
                              SoundManager.instance.playClickSound();
                              ref.read(tapCountsProvider.notifier).set({});
                            },
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _openCheckoutSheet(total),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF8B0000),
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final error = ref.watch(errorProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Connection Error",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? "Could not connect to Supabase",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProducts,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry Connection"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Magizh", style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w800, color: const Color(0xFF8B0000), letterSpacing: -1.1)),
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFF8B0000),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                Haptics.medium();
                _openAdminAddProductSheet();
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => ref.read(searchProvider.notifier).val = value,
          decoration: InputDecoration(
            hintText: "Search for food...",
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); ref.read(searchProvider.notifier).val = ""; }) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    return SizedBox(
      height: 60,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(physics: const BouncingScrollPhysics()),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = cat == selectedCategory;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  Haptics.light();
                  SoundManager.instance.playClickSound();
                  ref.read(selectedCategoryProvider.notifier).val = cat;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF8B0000) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFF8B0000).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> filteredProducts) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 15, mainAxisSpacing: 15),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) => ProductCard(product: filteredProducts[index]),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 9, 8, 4 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_filled, "Home", _currentTab == AppTab.home, onTap: () {
              setState(() => _currentTab = AppTab.home);
            }),
            _buildNavItem(Icons.inventory_2_outlined, "Inventory", _currentTab == AppTab.inventory, onTap: () async {
              setState(() => _currentTab = AppTab.inventory);
              await _openInventorySheet();
              if (mounted) setState(() => _currentTab = AppTab.home);
            }),
            _buildNavItem(Icons.receipt_long_outlined, "Expense", _currentTab == AppTab.expense, onTap: () async {
              setState(() => _currentTab = AppTab.expense);
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensePage()));
              if (mounted) setState(() => _currentTab = AppTab.home);
            }),
            _buildNavItem(Icons.history_rounded, "History", _currentTab == AppTab.history, onTap: () async {
              setState(() => _currentTab = AppTab.history);
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
              if (mounted) setState(() => _currentTab = AppTab.home);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: SizedBox(
        width: 78,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF8B0000), size: 22),
              const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF8B0000),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPlaceholder() {
    return const Center(
      child: Text(
        "",
        style: TextStyle(color: Colors.transparent),
      ),
    );
  }

  List<Map<String, dynamic>> _buildOrderItemsFromTapCounts(Map<dynamic, int> tapCounts) {
    final products = ref.read(productsProvider);
    final items = <Map<String, dynamic>>[];
    for (final entry in tapCounts.entries) {
      final product = products.firstWhere((p) => p['id'] == entry.key, orElse: () => {});
      if (product.isEmpty) continue;
      final qty = entry.value;
      final unitPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      items.add({
        'product_id': product['id'],
        'product_name': product['name']?.toString() ?? 'Item',
        'qty': qty,
        'unit_price': unitPrice,
        'line_total': unitPrice * qty,
      });
    }
    return items;
  }

  Future<void> _openCheckoutSheet(double total) async {
    final tapCounts = ref.read(tapCountsProvider);
    final items = _buildOrderItemsFromTapCounts(tapCounts);
    if (items.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 14),
              const Text('Select payment method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _completeOrder('online', total, items);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Online'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _openOfflineAmountDialog(total, items);
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8B0000), side: const BorderSide(color: Color(0xFF8B0000)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Offline'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openOfflineAmountDialog(double total, List<Map<String, dynamic>> items) async {
    final controller = TextEditingController();
    double balance = 0;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Offline payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total: ₹${total.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount received'),
                  onChanged: (value) {
                    final paid = double.tryParse(value) ?? 0;
                    setState(() => balance = paid - total);
                  },
                ),
                const SizedBox(height: 8),
                Text('Balance: ₹${balance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _completeOrder('offline', total, items);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
                child: const Text('Done'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _completeOrder(String method, double total, List<Map<String, dynamic>> items) async {
    try {
      await Supabase.instance.client.from('expense_transactions').insert({
        'payment_method': method,
        'total_amount': total,
        'items': items,
      });

      await _reduceStockAfterOrder(items);

      ref.read(tapCountsProvider.notifier).set({});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save order: $e')));
      }
    }
  }

  Future<void> _reduceStockAfterOrder(List<Map<String, dynamic>> items) async {
    final products = List<Map<String, dynamic>>.from(ref.read(productsProvider));
    for (final item in items) {
      final productId = item['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final product = products.firstWhere((p) => p['id'] == productId, orElse: () => {});
      final currentStock = (product['stock_qty'] as num?)?.toInt() ?? 0;
      final nextStock = (currentStock - qty) < 0 ? 0 : (currentStock - qty);

      await Supabase.instance.client.from('products').update({'stock_qty': nextStock}).eq('id', productId);
      await Supabase.instance.client.from('inventory_items').upsert({
        'product_id': productId,
        'stock_qty': nextStock,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'product_id');

      _inventoryQtyById[productId] = nextStock;
    }

    ref.read(productsProvider.notifier).updateState((state) {
      return state.map((row) {
        final id = row['id']?.toString() ?? '';
        final updated = items.firstWhere((i) => i['product_id']?.toString() == id, orElse: () => {});
        if (updated.isEmpty) return row;
        final qty = (updated['qty'] as num?)?.toInt() ?? 0;
        final currentStock = (row['stock_qty'] as num?)?.toInt() ?? 0;
        final nextStock = (currentStock - qty) < 0 ? 0 : (currentStock - qty);
        final next = Map<String, dynamic>.from(row);
        next['stock_qty'] = nextStock;
        return next;
      }).toList();
    });
  }

  Future<void> _openInventorySheet() async {
    final currentProducts = List<Map<String, dynamic>>.from(ref.read(productsProvider));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventorySheet(
        products: currentProducts,
        initialQuantities: Map<String, int>.from(_inventoryQtyById),
        onSave: (updatedQuantities) async {
          for (final entry in updatedQuantities.entries) {
            await Supabase.instance.client.from('products').update({'stock_qty': entry.value}).eq('id', entry.key);
            await Supabase.instance.client.from('inventory_items').upsert({
              'product_id': entry.key,
              'stock_qty': entry.value,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'product_id');
          }
          _inventoryQtyById
            ..clear()
            ..addAll(updatedQuantities);
          if (mounted) {
            ref.read(productsProvider.notifier).updateState((state) {
              return state.map((row) {
                final id = row['id']?.toString();
                if (id == null || !updatedQuantities.containsKey(id)) return row;
                final next = Map<String, dynamic>.from(row);
                next['stock_qty'] = updatedQuantities[id];
                return next;
              }).toList();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory saved')));
          }
        },
        onDelete: (productId) async {
          await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', productId);
          ref.read(productsProvider.notifier).updateState((state) => state.where((row) => row['id']?.toString() != productId).toList());
        },
        onAddTap: () async {
          await _openRestoreProductsSheet();
        },
      ),
    );
  }

  Future<void> _openRestoreProductsSheet() async {
    final response = await Supabase.instance.client
        .from('products')
        .select()
        .eq('is_active', false)
        .order('name');
    if (!mounted) return;
    final rows = List<Map<String, dynamic>>.from(response);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RestoreProductsSheet(
        inactiveProducts: rows,
        onSave: (selectedIds) async {
          if (selectedIds.isEmpty) return;
          await Supabase.instance.client.from('products').update({'is_active': true}).inFilter('id', selectedIds);
          await _fetchProducts();
        },
      ),
    );
  }

  Future<void> _openAdminAddProductSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => AddProductSheet(
        categories: categories,
        onAdd: (name, price, category, imagePath) => _saveProductOptimistically(name, price, category, imagePath),
      ),
    );
  }

  Future<void> _saveProductOptimistically(String name, double price, String category, String localPath) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempProduct = {'id': tempId, 'name': name, 'price': price, 'category': category, 'image_url': localPath, 'is_active': true, 'is_syncing': true};
    ref.read(productsProvider.notifier).updateState((state) => [tempProduct, ...state]);
    try {
      await _saveProductToSupabase(name, price, category, localPath, tempId);
    } catch (e) {
      if (mounted) {
        ref.read(productsProvider.notifier).updateState((state) => state.where((p) => p['id'] != tempId).toList());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _saveProductToSupabase(String name, double price, String category, String localPath, String tempId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage.from('product-images').upload(fileName, File(localPath));
    final publicUrl = Supabase.instance.client.storage.from('product-images').getPublicUrl(fileName);
    final response = await Supabase.instance.client.from('products').insert({'name': name, 'price': price, 'category': category, 'image_url': publicUrl, 'is_active': true}).select().single();
    if (mounted) {
      ref.read(productsProvider.notifier).updateState((state) {
        final newState = List<Map<String, dynamic>>.from(state);
        final index = newState.indexWhere((p) => p['id'] == tempId);
        if (index != -1) newState[index] = Map<String, dynamic>.from(response);
        return newState;
      });
    }
  }
}

class ProductCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productId = product["id"];
    final count = ref.watch(tapCountsProvider)[productId] ?? 0;
    final isSelected = count > 0;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? const Color(0xFF8B0000) : Colors.transparent, width: 1.6), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Haptics.light();
                SoundManager.instance.playClickSound();
                ref.read(tapCountsProvider.notifier).updateState((state) {
                  final newState = Map<dynamic, int>.from(state);
                  newState[productId] = (state[productId] ?? 0) + 1 >= 100 ? 0 : (state[productId] ?? 0) + 1;
                  return newState;
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'img_$productId',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _buildProductImage(product),
                    ),
                  ),
                  if (product['is_syncing'] == true)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "x$count",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          Haptics.medium();
                          SoundManager.instance.playClickSound();
                          ref.read(tapCountsProvider.notifier).updateState((state) {
                            final newState = Map<dynamic, int>.from(state);
                            newState.remove(productId);
                            return newState;
                          });
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.black87),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(product["name"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text("₹${(product["price"] as num).toInt()}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF8B0000))),
        ],
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final imageUrl = product["image_url"] as String?;
    if (product["is_syncing"] == true && imageUrl != null) return Image.file(File(imageUrl), fit: BoxFit.cover);
    if (imageUrl != null && imageUrl.startsWith('http')) return CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: const Color(0xFFF1F3F5), child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B0000)))), errorWidget: (context, url, error) => _buildPlaceholderImage());
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(color: const Color(0xFFF1F3F5), alignment: Alignment.center, child: const Icon(Icons.image_not_supported_outlined, size: 30, color: Color(0xFFADB5BD)));
  }
}

class AddProductSheet extends StatefulWidget {
  final List<String> categories;
  final Function(String name, double price, String category, String imagePath) onAdd;
  const AddProductSheet({super.key, required this.categories, required this.onAdd});
  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late String _category;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _category = widget.categories.firstWhere((c) => c != "All", orElse: () => "Puff"); }
  @override
  void dispose() { _nameController.dispose(); _priceController.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Product", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Product name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Price", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              items: widget.categories.where((c) => c != "All").map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (value) { if (value != null) setState(() => _category = value); },
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_selectedImage == null ? "Choose photo" : "Photo selected"))),
            if (_selectedImage != null) ...[const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_selectedImage!.path), height: 120, width: double.infinity, fit: BoxFit.cover))],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text.trim());
              if (name.isEmpty || price == null || price <= 0 || _selectedImage == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter valid name, price, and choose a photo."))); return; }
              widget.onAdd(name, price, _category, _selectedImage!.path);
              Navigator.pop(context);
            }, child: const Text("+ Add"))),
          ],
        ),
      ),
    );
  }
}

class InventorySheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, int> initialQuantities;
  final Future<void> Function(Map<String, int> updatedQuantities) onSave;
  final Future<void> Function(String productId) onDelete;
  final Future<void> Function() onAddTap;

  const InventorySheet({
    super.key,
    required this.products,
    required this.initialQuantities,
    required this.onSave,
    required this.onDelete,
    required this.onAddTap,
  });

  @override
  State<InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<InventorySheet> {
  late final TextEditingController _searchController;
  late Map<String, int> _qtyById;
  late Map<String, int> _baseQtyById;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _qtyById = Map<String, int>.from(widget.initialQuantities);
    _baseQtyById = Map<String, int>.from(widget.initialQuantities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    for (final row in widget.products) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if ((_qtyById[id] ?? 0) != (_baseQtyById[id] ?? 0)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.products.where((row) {
      final name = row['name']?.toString().toLowerCase() ?? '';
      final category = row['category']?.toString().toLowerCase() ?? '';
      return name.contains(query) || category.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory', style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w800, color: const Color(0xFF222222))),
              const SizedBox(height: 6),
              const Text('Adjust quantities and upload', style: TextStyle(fontSize: 15, color: Color(0xFF8D8D8D))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFA39B9B)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, size: 30),
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final id = row['id']?.toString() ?? '';
                    final qty = _qtyById[id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: _inventoryImage(row['image_url']?.toString()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row['name']?.toString() ?? 'Item', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                                Text(row['category']?.toString() ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF4D4D4D))),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _qtyById[id] = (qty > 0) ? qty - 1 : 0),
                            icon: const Icon(Icons.remove_circle_outline, size: 40, color: Color(0xFF504848)),
                          ),
                          Container(
                            width: 92,
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: const Color(0xFFA39B9B)),
                            ),
                            child: Text('$qty', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _qtyById[id] = qty + 1),
                            icon: const Icon(Icons.add_circle_outline, size: 40, color: Color(0xFF504848)),
                          ),
                          IconButton(
                            onPressed: () async {
                              await widget.onDelete(id);
                              if (mounted) {
                                setState(() {
                                  _qtyById.remove(id);
                                  _baseQtyById.remove(id);
                                });
                              }
                            },
                            icon: const Icon(Icons.delete_outline, size: 36, color: Color(0xFFD34040)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_isDirty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            await widget.onSave(_qtyById);
                            if (mounted) {
                              setState(() {
                                _baseQtyById = Map<String, int>.from(_qtyById);
                                _isSaving = false;
                              });
                            }
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onAddTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                  child: const Text('+ Add', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inventoryImage(String? url) {
    if (url != null && url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFFEFEFEF)),
        errorWidget: (_, __, ___) => _inventoryPlaceholder(),
      );
    }
    return _inventoryPlaceholder();
  }

  Widget _inventoryPlaceholder() {
    return Container(
      color: const Color(0xFFEFEFEF),
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood_outlined, color: Color(0xFF8D8D8D)),
    );
  }
}

class RestoreProductsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> inactiveProducts;
  final Future<void> Function(List<String> selectedIds) onSave;

  const RestoreProductsSheet({
    super.key,
    required this.inactiveProducts,
    required this.onSave,
  });

  @override
  State<RestoreProductsSheet> createState() => _RestoreProductsSheetState();
}

class _RestoreProductsSheetState extends State<RestoreProductsSheet> {
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Products', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Pick snacks to restore in inventory', style: TextStyle(fontSize: 16, color: Color(0xFF8D8D8D))),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.inactiveProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = widget.inactiveProducts[index];
                    final id = row['id']?.toString() ?? '';
                    final checked = _selected.contains(id);
                    return ListTile(
                      leading: const Icon(Icons.fastfood_outlined, color: Color(0xFF8D8D8D)),
                      title: Text(row['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, color: Color(0xFF646464))),
                      subtitle: Text(row['category']?.toString() ?? '', style: const TextStyle(fontSize: 15, color: Color(0xFF8D8D8D))),
                      trailing: Checkbox(
                        value: checked,
                        onChanged: (_) {
                          setState(() {
                            if (checked) {
                              _selected.remove(id);
                            } else {
                              _selected.add(id);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || _selected.isEmpty
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await widget.onSave(_selected.toList());
                          if (mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFDADADA),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save to Inventory', style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final response = await Supabase.instance.client.from('expense_transactions').select().order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(response);
    _entries = rows.map((row) {
      final createdAtUtc = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now().toUtc();
      final createdAtIst = createdAtUtc.toUtc().add(const Duration(hours: 5, minutes: 30));
      final items = row['items'] is List ? (row['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      return {
        'items': items
            .map((i) => {
                  'name': i['product_name']?.toString() ?? 'Item',
                  'qty': i['qty'] ?? 0,
                })
            .toList(),
        'day': _dayName(createdAtIst.weekday),
        'date': '${createdAtIst.day.toString().padLeft(2, '0')}-${createdAtIst.month.toString().padLeft(2, '0')}-${createdAtIst.year}',
        'time': _format12(createdAtIst),
        'method': (row['payment_method']?.toString() ?? 'offline').toLowerCase(),
        'amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
      };
    }).toList();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEEF1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        title: const Text('Expense'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                itemBuilder: (_, index) => _expenseCard(_entries[index]),
              ),
            ),
    );
  }

  Widget _expenseCard(Map<String, dynamic> entry) {
    final items = List<Map<String, dynamic>>.from(entry['items'] as List? ?? []);
    final method = entry['method']?.toString() ?? 'offline';
    final isOnline = method == 'online';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: items.isEmpty
                ? const Text('Ordered items: Not captured')
                : Column(
                    children: items
                        .map((row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(child: Text(row['name']?.toString() ?? 'Item', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
                                  Text('x${row['qty']}', style: const TextStyle(fontSize: 20, color: Color(0xFF8B0000), fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Day: ${entry['day']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                    Text('₹${(entry['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 42, color: Color(0xFF8B0000), fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Date: ${entry['date']}', style: const TextStyle(fontSize: 19)),
                const SizedBox(height: 6),
                Text('Time: ${entry['time']}', style: const TextStyle(fontSize: 19)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFFE5F0FF) : const Color(0xFFEAF8EC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF8B0000)),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: isOnline ? const Color(0xFF1E62B5) : const Color(0xFF2D8D3C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        title: const Text('History'),
      ),
      body: const Center(
        child: Text('History screen'),
      ),
    );
  }
}

String _dayName(int weekday) {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  if (weekday < 1 || weekday > 7) return '';
  return names[weekday - 1];
}

String _format12(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'pm' : 'am';
  return '$h:$m$suffix';
}
