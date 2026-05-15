import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'expenses_page.dart';
import 'inventory_sheet.dart';
import 'theme/app_theme.dart';
import 'checkout_sheet.dart';
import 'dashboard_page.dart';

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
      theme: AppTheme.lightTheme,
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
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        ref.read(productsProvider.notifier).set(List<Map<String, dynamic>>.from(response));
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
    final selectedCount = tapCounts.values.fold<int>(0, (sum, count) => sum + count);

    final filteredProducts = products.where((p) {
      final matchesCategory = selectedCategory == "All" || 
          p["category"].toString().toLowerCase() == selectedCategory.toLowerCase();
      return matchesCategory && p["name"].toString().toLowerCase().contains(searchQuery);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
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
                      )
                ),
              ],
            ),
            _buildBottomNav(context),
            if (selectedCount > 0)
              Positioned(
                bottom: 210,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    Haptics.medium();
                    ref.read(tapCountsProvider.notifier).set({});
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B0000).withValues(alpha: 0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close, color: Color(0xFF8B0000), size: 28),
                  ),
                ),
              ),
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
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.black),
            const SizedBox(height: 16),
            const Text(
              "Connection Error",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? "Could not connect to Supabase",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Magizh", style: Theme.of(context).textTheme.displayLarge, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openAdminAddProductSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => ref.read(searchProvider.notifier).val = value,
          decoration: InputDecoration(
            hintText: "Search for food...",
            prefixIcon: const Icon(Icons.search, color: Colors.black),
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
                        color: const Color(0xFF8B0000).withValues(alpha: 0.3),
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
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 15, mainAxisSpacing: 15),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: ProductCard(
                  product: filteredProducts[index],
                  onEdit: () => _openEditProductSheet(filteredProducts[index]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final products = ref.watch(productsProvider);
    final tapCounts = ref.watch(tapCountsProvider);
    final selectedCount = tapCounts.values.fold<int>(0, (sum, count) => sum + count);
    final total = tapCounts.entries.fold<double>(0, (sum, entry) {
      final match = products.firstWhere((p) => p["id"] == entry.key, orElse: () => {});
      final price = match["price"] is num ? (match["price"] as num).toDouble() : 0.0;
      return sum + (price * entry.value);
    });

    return Positioned(
      bottom: 0,
      left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedCount > 0)
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B0000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text("Selected: $selectedCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 12),
                          Flexible(child: Text("Amount: ₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Haptics.light();
                          showDialog(
                            context: context,
                            builder: (context) => const CheckoutSheet(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF8B0000),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF8B0000), width: 1),
                          ),
                        ),
                        child: const Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWhatsAppNavItem(Icons.home, "Home", true, () {}),
                    _buildWhatsAppNavItem(Icons.inventory_2_outlined, "Inventory", false, () {
                      Haptics.light();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (context) => const InventorySheet(),
                      );
                    }),
                    _buildWhatsAppNavItem(Icons.receipt_long_outlined, "Expense", false, () {
                      Haptics.light();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesPage()));
                    }),
                    _buildWhatsAppNavItem(Icons.bar_chart_rounded, "Analytics", false, () {
                      Haptics.light();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppNavItem(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isSelected ? const Color(0xFF8B0000) : Colors.black, 
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label, 
              style: TextStyle(
                color: isSelected ? const Color(0xFF8B0000) : Colors.black, 
                fontSize: 11, 
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400
              ),
            ),
          ],
        ),
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

  Future<void> _openEditProductSheet(Map<String, dynamic> product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => EditProductSheet(
        product: product,
        categories: categories,
        onUpdate: (updates, newImagePath) => _updateProduct(product['id'], updates, newImagePath),
        onDelete: () => _deleteProduct(product['id']),
      ),
    );
  }

  Future<void> _updateProduct(String id, Map<String, dynamic> updates, String? localImagePath) async {
    try {
      String? imageUrl = updates['image_url'];
      if (localImagePath != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('product-images').upload(fileName, File(localImagePath));
        imageUrl = Supabase.instance.client.storage.from('product-images').getPublicUrl(fileName);
      }

      final response = await Supabase.instance.client
          .from('products')
          .update({...updates, if (imageUrl != null) 'image_url': imageUrl})
          .eq('id', id)
          .select()
          .single();

      if (mounted) {
        ref.read(productsProvider.notifier).updateState((state) {
          final newState = List<Map<String, dynamic>>.from(state);
          final index = newState.indexWhere((p) => p['id'] == id);
          if (index != -1) newState[index] = Map<String, dynamic>.from(response);
          return newState;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _deleteProduct(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B0000)),
            child: const Text("Delete")
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', id);
        if (mounted) {
          ref.read(productsProvider.notifier).updateState((state) => state.where((p) => p['id'] != id).toList());
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }
}

class ProductCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  const ProductCard({super.key, required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productId = product["id"];
    final count = ref.watch(tapCountsProvider)[productId] ?? 0;
    final isSelected = count > 0;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? const Color(0xFF8B0000) : Colors.transparent, width: 1.6), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Column(
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
                  onLongPress: () {
                    Haptics.medium();
                    onEdit();
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
                            color: Colors.black.withValues(alpha: 0.3),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B0000),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text("x", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                    SizedBox(
                                      width: 25,
                                      child: TextField(
                                        key: ValueKey("qty-$productId-$count"),
                                        onChanged: (val) {
                                          final newVal = int.tryParse(val);
                                          if (newVal != null) {
                                            ref.read(tapCountsProvider.notifier).updateState((state) {
                                              final newState = Map<dynamic, int>.from(state);
                                              newState[productId] = newVal;
                                              return newState;
                                            });
                                          }
                                        },
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                        decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                        controller: TextEditingController(text: "$count"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product["name"], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${(product["price"] as num).toInt()}", 
                          style: const TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 18, 
                            color: Color(0xFF8B0000)
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${product["stock_qty"] ?? 0}",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: (product["stock_qty"] ?? 0) <= 5 
                          ? Colors.red 
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // X button only visible when selected
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  Haptics.medium();
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
  final _otherCategoryController = TextEditingController();
  late String _category;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _category = widget.categories.firstWhere((c) => c != "All", orElse: () => "Puff"); }
  @override
  void dispose() { 
    _nameController.dispose(); 
    _priceController.dispose(); 
    _otherCategoryController.dispose();
    super.dispose(); 
  }

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
            if (_category == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherCategoryController,
                decoration: const InputDecoration(labelText: "Enter new category name", border: OutlineInputBorder(), hintText: "e.g. Pizza, Cake"),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_selectedImage == null ? "Choose photo" : "Photo selected"))),
            if (_selectedImage != null) ...[const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_selectedImage!.path), height: 120, width: double.infinity, fit: BoxFit.cover))],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text.trim());
              String finalCategory = _category;
              if (_category == "Other") {
                finalCategory = _otherCategoryController.text.trim();
              }
              if (name.isEmpty || price == null || price <= 0 || _selectedImage == null || (finalCategory == "Other" && finalCategory.isEmpty) || finalCategory.isEmpty) { 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter valid name, price, category and choose a photo."))); 
                return; 
              }
              widget.onAdd(name, price, finalCategory, _selectedImage!.path);
              Navigator.pop(context);
            }, child: const Text("Add product"))),
          ],
        ),
      ),
    );
  }
}

class EditProductSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<String> categories;
  final Function(Map<String, dynamic> updates, String? newImagePath) onUpdate;
  final VoidCallback onDelete;
  const EditProductSheet({super.key, required this.product, required this.categories, required this.onUpdate, required this.onDelete});
  @override
  State<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<EditProductSheet> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _otherCategoryController;
  late String _category;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { 
    super.initState(); 
    _nameController = TextEditingController(text: widget.product['name']);
    _priceController = TextEditingController(text: widget.product['price'].toString());
    _stockController = TextEditingController(text: (widget.product['stock_qty'] ?? 0).toString());
    _category = widget.product['category'] ?? "Other";
    _otherCategoryController = TextEditingController();
    if (!widget.categories.contains(_category)) {
      _otherCategoryController.text = _category;
      _category = "Other";
    }
  }

  @override
  void dispose() { 
    _nameController.dispose(); 
    _priceController.dispose(); 
    _stockController.dispose();
    _otherCategoryController.dispose();
    super.dispose(); 
  }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Edit Product", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF8B0000)),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Product name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Price", border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock Qty", border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              items: widget.categories.where((c) => c != "All").map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (value) { if (value != null) setState(() => _category = value); },
            ),
            if (_category == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherCategoryController,
                decoration: const InputDecoration(labelText: "Enter category name", border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_selectedImage == null ? "Change photo" : "New photo selected"))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text.trim());
              final stock = int.tryParse(_stockController.text.trim()) ?? 0;
              String finalCategory = _category;
              if (_category == "Other") {
                finalCategory = _otherCategoryController.text.trim();
              }
              if (name.isEmpty || price == null || price <= 0 || (finalCategory == "Other" && finalCategory.isEmpty) || finalCategory.isEmpty) { 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter valid name, price and category."))); 
                return; 
              }
              widget.onUpdate({'name': name, 'price': price, 'category': finalCategory, 'stock_qty': stock}, _selectedImage?.path);
              Navigator.pop(context);
            }, child: const Text("Save Changes"))),
          ],
        ),
      ),
    );
  }
}
