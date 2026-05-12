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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Good Morning,", style: Theme.of(context).textTheme.bodyMedium),
              Text("Magizh", style: Theme.of(context).textTheme.displayLarge),
            ],
          ),
            GestureDetector(
            onTap: () {
              Haptics.medium();
              _openAdminAddProductSheet();
            },
            child: CircleAvatar(
              backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.1),
              radius: 24,
              child: const Icon(Icons.add, color: AppTheme.primary),
            ),
          )
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
                child: ProductCard(product: filteredProducts[index]),
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
      bottom: 12 + MediaQuery.of(context).padding.bottom,
      left: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCount > 0)
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (context) => const CheckoutSheet(),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFF8B0000), borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Selected: $selectedCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text("Amount: ₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, "Home", true, () {}),
                _buildNavItem(Icons.shopping_basket_outlined, "Basket", false, () {
                  Haptics.light();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (context) => const CheckoutSheet(),
                  );
                }),
                _buildNavItem(Icons.inventory_2_outlined, "Inventory", false, () {
                  Haptics.light();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (context) => const InventorySheet(),
                  );
                }),
                _buildNavItem(Icons.receipt_long, "Expenses", false, () {
                  Haptics.light();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesPage()));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF8B0000) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade400, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? const Color(0xFF8B0000) : Colors.transparent, width: 1.6), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
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
              initialValue: _category,
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
            }, child: const Text("Add product"))),
          ],
        ),
      ),
    );
  }
}
