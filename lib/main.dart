import 'dart:io';
import 'celebration_overlay.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'expenses_page.dart';
import 'inventory_sheet.dart';
import 'l10n/app_localizations.dart';
import 'settings_page.dart';
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



class MagizhPosApp extends ConsumerWidget {
  const MagizhPosApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Magizh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: appLanguages.map((language) => Locale(language.code)).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

class TimeSlotNotifier extends Notifier<TimeSlot?> {
  @override
  TimeSlot? build() => null;
  set val(TimeSlot? v) => state = v;
}
final selectedTimeSlotProvider = NotifierProvider<TimeSlotNotifier, TimeSlot?>(TimeSlotNotifier.new);

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

bool isAlwaysAvailableFields(String name, String category) {
  final normalizedName = name.toLowerCase();
  final normalizedCategory = category.toLowerCase();
  final compactName = normalizedName.replaceAll(RegExp(r'[\s\-_]+'), '');
  final compactCategory = normalizedCategory.replaceAll(RegExp(r'[\s\-_]+'), '');
  final matchesName =
      normalizedName.contains('tea') ||
      normalizedName.contains('coffee') ||
      normalizedName.contains('cofee') ||
      normalizedName.contains('juice') ||
      normalizedName.contains('rose milk') ||
      compactName.contains('rosemilk');
  final matchesCategory =
      normalizedCategory.contains('tea') ||
      normalizedCategory.contains('coffee') ||
      normalizedCategory.contains('cofee') ||
      normalizedCategory.contains('juice') ||
      normalizedCategory.contains('drink') ||
      normalizedCategory.contains('rose milk') ||
      compactCategory.contains('rosemilk');
  return matchesName || matchesCategory;
}

bool isAlwaysAvailableProduct(Map<String, dynamic> product) {
  final name = (product['name'] ?? '').toString();
  final category = (product['category'] ?? '').toString();
  return isAlwaysAvailableFields(name, category);
}

enum TimeSlot { morning, evening }

class TimeSlotConfig {
  final TimeSlot slot;
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final List<Color> gradient;
  final List<String> filterKeywords;
  final List<String> filterProductNames;
  final List<String> addCategories;

  const TimeSlotConfig({
    required this.slot,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.gradient,
    required this.filterKeywords,
    this.filterProductNames = const [],
    required this.addCategories,
  });
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    Future.microtask(() {
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  TimeSlotConfig _timeSlotConfig(TimeSlot slot) {
    switch (slot) {
      case TimeSlot.morning:
        return TimeSlotConfig(
          slot: TimeSlot.morning,
          title: context.t('morningTitle'),
          subtitle: context.t('morningSubtitle'),
          tag: context.t('morningTag'),
          icon: Icons.wb_sunny_rounded,
          gradient: const [Color(0xFF2D5016), Color(0xFF6BA84D)],
          filterKeywords: const ['morning', 'drink'],
          addCategories: const ['Morning Snacks', 'Drinks', 'Other'],
        );
      case TimeSlot.evening:
        return TimeSlotConfig(
          slot: TimeSlot.evening,
          title: context.t('eveningTitle'),
          subtitle: context.t('eveningSubtitle'),
          tag: context.t('eveningTag'),
          icon: Icons.nights_stay_rounded,
          gradient: const [Color(0xFFD4A574), Color(0xFFB58452)],
          filterKeywords: const ['evening', 'drink', 'puff', 'juice', 'cake', 'cutlet', 'samosa', 'samo', 'snack'],
          filterProductNames: const ['puff', 'juice', 'cake', 'cutlet', 'samosa', 'samo'],
          addCategories: const ['Puff', 'Samosa', 'Cake', 'Cutlet', 'Drinks', 'Evening Snacks', 'Other'],
        );
    }
  }

  void _openTimeSlotPage(TimeSlot slot) {
    final config = _timeSlotConfig(slot);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeSlotProductsPage(
          config: config,
          onAddTap: (ctx) => _openTimeSlotAddProductSheet(ctx, slot),
          onEdit: (ctx, product, categories) => _openEditProductSheet(ctx, product, categories, activeSlot: slot),
        ),
      ),
    );
  }

  Future<void> _openTimeSlotAddProductSheet(BuildContext context, TimeSlot slot) async {
    final config = _timeSlotConfig(slot);
    final allProducts = ref.read(productsProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SelectExistingProductSheet(
        products: allProducts,
        onSelect: (product) {
          final updates = {
            'id': product['id'],
            'category': config.addCategories.first,
          };
          _updateProduct(product['id'], updates, null);
        },
        onCreateNew: () {
          if (!mounted) return;
          showModalBottomSheet<void>(
            context: this.context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            builder: (context) => AddProductSheet(
              categories: config.addCategories,
                onAdd: (name, price, category, imagePath, nameI18n, categoryI18n) =>
                    _saveProductOptimistically(name, price, category, imagePath, nameI18n, categoryI18n),
            ),
          );
        },
      ),
    );
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

    // Dynamic categories from products
    final List<String> categories = ["All"];
    final existingCats = products.map((p) => p['category'] as String?).where((c) => c != null && c.isNotEmpty).cast<String>().toSet().toList()..sort();
    categories.addAll(existingCats);
    if (!categories.contains("Other")) {
      categories.add("Other");
    }

    final selectedTimeSlot = ref.watch(selectedTimeSlotProvider);
    final filteredProducts = products.where((p) {
      final matchesCategory = selectedCategory == "All" ||
          p["category"].toString().toLowerCase() == selectedCategory.toLowerCase();
      final matchesSearch = context.productName(p).toLowerCase().contains(searchQuery);

      // If a time slot is selected, ensure the product matches its filters
      if (selectedTimeSlot != null) {
        final cfg = _timeSlotConfig(selectedTimeSlot);
        final category = (p['category'] ?? '').toString().toLowerCase();
        final name = context.productName(p).toLowerCase();
        final matchesCategoryKeywords = cfg.filterKeywords.any((k) => category.contains(k));
        final matchesNameKeywords = cfg.filterProductNames.any((k) => name.contains(k));
        final isAlwaysAvailable = isAlwaysAvailableProduct(p) && category != 'other';
        final matchesTimeSlot = matchesCategoryKeywords || matchesNameKeywords || isAlwaysAvailable;
        return matchesCategory && matchesSearch && matchesTimeSlot;
      }

      return matchesCategory && matchesSearch;
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : ref.watch(errorProvider) != null
                            ? _buildErrorView()
                            : _searchFocusNode.hasFocus
                                ? _buildRecommendationsList(products)
                                : RefreshIndicator(
                                    onRefresh: _fetchProducts,
                                    color: AppTheme.primary,
                                    child: CustomScrollView(
                                      slivers: [
                                        SliverToBoxAdapter(child: _buildPromoBanner()),
                                        SliverToBoxAdapter(child: _buildCategories(categories, products)),
                                        if (filteredProducts.isEmpty)
                                          SliverFillRemaining(
                                            hasScrollBody: false,
                                            child: _buildEmptyState(),
                                          )
                                        else
                                          SliverToBoxAdapter(
                                            child: _buildProductGridInScroll(filteredProducts, categories),
                                          ),
                                      ],
                                    ),
                                  ),
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
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, color: AppTheme.primary, size: 28),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Text(context.t('noProducts')));

  Widget _buildErrorView() {
    final error = ref.watch(errorProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              context.t('connectionError'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? context.t('couldNotConnect'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProducts,
              icon: const Icon(Icons.refresh),
              label: Text(context.t('retryConnection')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.waving_hand_rounded, size: 14, color: AppTheme.gold),
                    const SizedBox(width: 6),
                    Text(
                      context.t('welcomeBack'),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "மகிழ்",
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openAdminAddProductSheet,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E2DD), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (value) => ref.read(searchProvider.notifier).val = value,
          style: GoogleFonts.roboto(
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: context.t('searchHint'),
            hintStyle: GoogleFonts.roboto(
              fontSize: 14,
              color: AppTheme.textLight,
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchProvider.notifier).val = "";
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsList(List<Map<String, dynamic>> allProducts) {
    final query = _searchController.text.toLowerCase();
    final selectedTimeSlot = ref.watch(selectedTimeSlotProvider);

    final recommended = allProducts.where((p) {
      final name = context.productName(p).toLowerCase();
      final category = (p['category'] ?? '').toString().toLowerCase();
      final matchesQuery = name.contains(query) || category.contains(query);

      if (selectedTimeSlot != null) {
        final cfg = _timeSlotConfig(selectedTimeSlot);
        final matchesCategoryKeywords = cfg.filterKeywords.any((k) => category.contains(k));
        final matchesNameKeywords = cfg.filterProductNames.any((k) => name.contains(k));
        final isAlwaysAvailable = isAlwaysAvailableProduct(p) && category != 'other';
        final matchesTimeSlot = matchesCategoryKeywords || matchesNameKeywords || isAlwaysAvailable;
        return matchesQuery && matchesTimeSlot;
      }

      return matchesQuery;
    }).toList();

    if (recommended.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(
                context.t('noProducts'),
                style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recommended.length,
      separatorBuilder: (context, index) => Divider(
        color: const Color(0xFFE5E2DD).withValues(alpha: 0.5),
        thickness: 1,
        indent: 20,
        endIndent: 20,
      ),
      itemBuilder: (context, index) {
        final product = recommended[index];
        final name = context.productName(product);
        final category = context.productCategory(product);
        final price = (product['price'] as num).toInt();
        final alwaysAvailable = isAlwaysAvailableProduct(product);
        final stockQty = (product['stock_qty'] as num?)?.toInt() ?? 0;
        final isSoldOut = !alwaysAvailable && stockQty <= 0;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Hero(
            tag: 'img_rec_${product["id"]}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: _buildProductImageSmall(product),
              ),
            ),
          ),
          title: Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSoldOut ? AppTheme.textLight : AppTheme.textPrimary,
              decoration: isSoldOut ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            "$category • ₹$price",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          trailing: isSoldOut
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.t('soldOut'),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    Haptics.light();
                    SoundManager.instance.playClickSound();
                    final productId = product['id'];
                    ref.read(tapCountsProvider.notifier).updateState((state) {
                      final newState = Map<dynamic, int>.from(state);
                      newState[productId] = (state[productId] ?? 0) + 1;
                      return newState;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 20),
                  ),
                ),
          onTap: () {
            _searchController.text = name;
            ref.read(searchProvider.notifier).val = name;
            _searchFocusNode.unfocus();
          },
        );
      },
    );
  }

  Widget _buildProductImageSmall(Map<String, dynamic> product) {
    final imageUrl = product["image_url"] as String?;
    if (product["is_syncing"] == true && imageUrl != null) {
      return Image.file(File(imageUrl), fit: BoxFit.cover);
    }
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFFF1F3F5),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderImageSmall(),
      );
    }
    return _buildPlaceholderImageSmall();
  }

  Widget _buildPlaceholderImageSmall() {
    return Container(
      color: const Color(0xFFF1F3F5),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, size: 20, color: Color(0xFFADB5BD)),
    );
  }

  Widget _buildPromoBanner() {
    final promoItems = [
      _timeSlotConfig(TimeSlot.morning),
      _timeSlotConfig(TimeSlot.evening),
    ];
    final selectedTimeSlot = ref.watch(selectedTimeSlotProvider);
    
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive height - made slightly taller to fit 2-line subtitle comfortably like in the reference image
    final bannerHeight = (screenHeight * 0.17).clamp(135.0, 150.0);
    // Card width - 82% of screen width so the second card is slightly visible on the right
    final cardWidth = screenWidth * 0.82;

    return SizedBox(
      height: bannerHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 8, top: 4, bottom: 8), // aligns perfectly with search and headers
        itemCount: promoItems.length,
        itemBuilder: (context, index) {
          final item = promoItems[index];
          final grad = item.gradient;
          final isSelected = selectedTimeSlot == item.slot;
          
          // Dynamically add matching emoji for titles like in the reference image
          final emoji = item.slot == TimeSlot.morning ? " 🌅" : " 🌇";
          final displayTitle = "${item.title}$emoji";

          return SizedBox(
            width: cardWidth,
            child: GestureDetector(
              onTap: () {
                Haptics.light();
                SoundManager.instance.playClickSound();
                // Toggle: tap again to deselect
                if (isSelected) {
                  ref.read(selectedTimeSlotProvider.notifier).val = null;
                } else {
                  ref.read(selectedTimeSlotProvider.notifier).val = item.slot;
                }
                ref.read(selectedCategoryProvider.notifier).val = "All";
              },
              onLongPress: () {
                Haptics.medium();
                _openTimeSlotPage(item.slot);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4), // right margin only for horizontal list
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad, // Original green/brown gradient is always visible
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20), // Premium rounded corners matching reference image
                  border: isSelected
                      ? Border.all(color: const Color(0xFFE8C547), width: 2.2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFFE8C547).withValues(alpha: 0.3)
                          : grad[0].withValues(alpha: 0.25),
                      blurRadius: isSelected ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Very light yellow overlay when selected to let background green show through
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFFFF7C2).withValues(alpha: 0.18),
                        ),
                      ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        item.icon,
                        size: bannerHeight * 0.75,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8C547).withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFFE8C547)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0), // Generous padding matching reference image
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF7C2).withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              displayTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: cardWidth - 44, // bounds subtitle text horizontally
                              child: Text(
                                item.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                                maxLines: 2, // Wraps up to 2 lines exactly like the reference image
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories(List<String> categories, List<Map<String, dynamic>> products) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    return SizedBox(
      height: 64,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(physics: const BouncingScrollPhysics()),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = cat == selectedCategory;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: GestureDetector(
                onTap: () {
                  Haptics.light();
                  ref.read(selectedCategoryProvider.notifier).val = cat;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? null
                        : Border.all(color: const Color(0xFFE5E2DD), width: 1.2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _categoryLabel(cat, products),
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildProductGridInScroll(List<Map<String, dynamic>> filteredProducts, List<String> categories) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 6 : width > 900 ? 5 : width > 600 ? 4 : 2;

    double aspectRatio;
    if (width > 1200) {
      aspectRatio = 0.78;
    } else if (width > 900) {
      aspectRatio = 0.72;
    } else if (width > 600) {
      aspectRatio = 0.68;
    } else {
      aspectRatio = width < 365 ? 0.54 : 0.58;
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 220),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: crossAxisCount,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: ProductCard(
                  product: filteredProducts[index],
                  onEdit: () => _openEditProductSheet(context, filteredProducts[index], categories),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
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
              const CheckoutFloatingBar(),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWhatsAppNavItem(Icons.home, context.t('home'), true, () {}),
                    _buildWhatsAppNavItem(Icons.inventory_2_outlined, context.t('inventory'), false, () {
                      Haptics.light();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width > 900 
                              ? 800 
                              : MediaQuery.of(context).size.width > 600 
                                  ? MediaQuery.of(context).size.width * 0.85
                                  : double.infinity,
                        ),
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (context) => const InventorySheet(),
                      );
                    }),
                    _buildWhatsAppNavItem(Icons.receipt_long_outlined, context.t('expense'), false, () {
                      Haptics.light();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesPage()));
                    }),
                    _buildWhatsAppNavItem(Icons.bar_chart_rounded, context.t('analytics'), false, () {
                      Haptics.light();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
                    }),
                    _buildWhatsAppNavItem(Icons.settings_outlined, context.t('settings'), false, () {
                      Haptics.light();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.6),
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.6),
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String category, List<Map<String, dynamic>> products) {
    if (category == 'All') return context.t('all');
    if (category == 'Other') return context.t('other');
    final match = products.firstWhere(
      (product) => (product['category'] ?? '').toString().toLowerCase() == category.toLowerCase(),
      orElse: () => const <String, dynamic>{},
    );
    if (match.isEmpty) return category;
    final translated = context.productCategory(match);
    return translated.isEmpty ? category : translated;
  }

  Future<void> _openAdminAddProductSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => AddProductSheet(
        categories: ["Puff", "Samosa", "Roll", "Drinks", "Sandwich", "Other"],
        onAdd: (name, price, category, imagePath, nameI18n, categoryI18n) =>
            _saveProductOptimistically(name, price, category, imagePath, nameI18n, categoryI18n),
      ),
    );
  }

  Future<void> _saveProductOptimistically(
    String name,
    double price,
    String category,
    String localPath,
    Map<String, String> nameI18n,
    Map<String, String> categoryI18n,
  ) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempProduct = {
      'id': tempId,
      'name': name,
      'price': price,
      'category': category,
      'name_i18n': nameI18n,
      'category_i18n': categoryI18n,
      'image_url': localPath,
      'is_active': true,
      'is_syncing': true,
    };
    ref.read(productsProvider.notifier).updateState((state) => [tempProduct, ...state]);
    try {
      await _saveProductToSupabase(name, price, category, localPath, tempId, nameI18n, categoryI18n);
    } catch (e) {
      if (mounted) {
        ref.read(productsProvider.notifier).updateState((state) => state.where((p) => p['id'] != tempId).toList());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('failed', args: {'error': e}))));
      }
    }
  }

  Future<void> _saveProductToSupabase(
    String name,
    double price,
    String category,
    String localPath,
    String tempId,
    Map<String, String> nameI18n,
    Map<String, String> categoryI18n,
  ) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage.from('product-images').upload(fileName, File(localPath));
    final publicUrl = Supabase.instance.client.storage.from('product-images').getPublicUrl(fileName);
    final response = await Supabase.instance.client.from('products').insert({
      'name': name,
      'price': price,
      'category': category,
      'name_i18n': nameI18n,
      'category_i18n': categoryI18n,
      'image_url': publicUrl,
      'is_active': true,
    }).select().single();
    if (mounted) {
      ref.read(productsProvider.notifier).updateState((state) {
        final newState = List<Map<String, dynamic>>.from(state);
        final index = newState.indexWhere((p) => p['id'] == tempId);
        if (index != -1) newState[index] = Map<String, dynamic>.from(response);
        return newState;
      });
    }
  }

  Future<void> _openEditProductSheet(BuildContext context, Map<String, dynamic> product, List<String> categories, {TimeSlot? activeSlot}) async {
    final slot = activeSlot ?? ref.read(selectedTimeSlotProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => EditProductSheet(
        product: product,
        categories: categories,
        activeSlot: slot,
        onUpdate: (updates, newImagePath) => _updateProduct(product['id'], updates, newImagePath),
        onDelete: () => _deleteProduct(product['id'], slot),
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

      final productUpdates = {...updates};
      if (imageUrl != null) {
        productUpdates['image_url'] = imageUrl;
      }

      final response = await Supabase.instance.client
          .from('products')
          .update(productUpdates)
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
        showCelebration(context, context.t('productUpdated'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('updateFailed', args: {'error': e}))));
      }
    }
  }

  Future<void> _deleteProduct(String id, TimeSlot? activeSlot) async {
    if (activeSlot != null) {
      final slotName = activeSlot == TimeSlot.morning ? "Morning" : "Evening";
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Delete Options"),
          content: Text("Choose how you want to delete this product:"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, "slot"),
              child: Text("Delete in $slotName"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, "everywhere"),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              child: const Text("Delete Snack"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, "cancel"),
              child: Text(context.t('cancel')),
            ),
          ],
        ),
      );

      if (result == "slot") {
        final updates = {
          'category': 'Other',
          'category_i18n': {'en': 'Other'},
        };
        await _updateProduct(id, updates, null);
        return;
      } else if (result == "everywhere") {
        // Continue to delete everywhere
      } else {
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t('deleteProduct')),
          content: Text(context.t('deleteProductConfirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t('cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              child: Text(context.t('delete'))
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', id);
      if (mounted) {
        ref.read(productsProvider.notifier).updateState((state) => state.where((p) => p['id'] != id).toList());
        showCelebration(context, context.t('productDeleted'), icon: Icons.delete_rounded, bannerColor: const Color(0xFFD32F2F));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('deleteFailed', args: {'error': e}))));
      }
    }
  }
}

class TimeSlotProductsPage extends ConsumerWidget {
  final TimeSlotConfig config;
  final Future<void> Function(BuildContext context) onAddTap;
  final Future<void> Function(BuildContext context, Map<String, dynamic> product, List<String> categories) onEdit;

  const TimeSlotProductsPage({
    super.key,
    required this.config,
    required this.onAddTap,
    required this.onEdit,
  });

  bool _matchesSlot(Map<String, dynamic> product) {
    final category = (product['category'] ?? '').toString().toLowerCase();
    final name = (product['name'] ?? '').toString().toLowerCase();
    final matchesCategory = config.filterKeywords.any((keyword) => category.contains(keyword));
    final matchesName = config.filterProductNames.any((keyword) => name.contains(keyword));
    return matchesCategory || matchesName;
  }

  List<String> _buildCategories(List<Map<String, dynamic>> products) {
    final List<String> categories = ["All"];
    final existingCats = products
        .map((p) => p['category'] as String?)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    categories.addAll(existingCats);
    return categories;
  }

  Widget _buildProductGrid(BuildContext context, List<Map<String, dynamic>> filteredProducts, List<String> categories) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 6 : width > 900 ? 5 : width > 600 ? 4 : 2;
    
    double aspectRatio;
    if (width > 1200) {
      aspectRatio = 0.78;
    } else if (width > 900) {
      aspectRatio = 0.72;
    } else if (width > 600) {
      aspectRatio = 0.68;
    } else {
      aspectRatio = width < 365 ? 0.54 : 0.58;
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: crossAxisCount,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: ProductCard(
                  product: filteredProducts[index],
                  onEdit: () => onEdit(context, filteredProducts[index], categories),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final filteredProducts = products.where((p) {
      return _matchesSlot(p);
    }).toList();
    final categories = _buildCategories(products);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primary),
        title: Text(
          config.title,
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () {
              Haptics.light();
              onAddTap(context);
            },
            icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(child: Text(context.t('noTimeSlotProducts')))
                : _buildProductGrid(context, filteredProducts, categories),
          ),
          const CheckoutFloatingBar(),
        ],
      ),
    );
  }
}

class ProductCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;

  const ProductCard({
    super.key, 
    required this.product, 
    required this.onEdit,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    final count = ref.read(tapCountsProvider)[widget.product["id"]] ?? 0;
    _qtyController = TextEditingController(text: count > 0 ? "$count" : "");
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final onEdit = widget.onEdit;
    final productId = product["id"];
    final count = ref.watch(tapCountsProvider)[productId] ?? 0;

    if (_qtyController.text != "$count") {
      _qtyController.text = count > 0 ? "$count" : "";
    }

    final isSelected = count > 0;
    
    // Dynamic responsive parameters for small screens to prevent overflows
    final isSmallScreen = MediaQuery.of(context).size.width < 365;
    final cardPadding = isSmallScreen ? 8.0 : 12.0;
    final titleFontSize = isSmallScreen ? 12.0 : 14.0;
    final priceFontSize = isSmallScreen ? 14.0 : 16.0;
    
    // Deterministic rating based on product name/id
    final double rating = 4.0 + (context.productName(product).hashCode % 10) / 10.0;
    
    // Deterministic badge text based on product category
    String badgeText = context.t('classic');
    final category = (product['category'] ?? '').toString().toLowerCase();
    if (category.contains('cake')) {
      badgeText = context.t('specialty');
    } else if (category.contains('puff') || category.contains('samosa')) {
      badgeText = context.t('fresh');
    } else if (category.contains('roll')) {
      badgeText = context.t('popular');
    } else if (category.contains('drink')) {
      badgeText = context.t('chilled');
    }

    // Refined stock remaining pill with high-end dot indicator design (Larger text/dot size)
    final stockQty = (product['stock_qty'] as num?)?.toInt() ?? 0;
    final alwaysAvailable = isAlwaysAvailableProduct(product);
    Widget stockWidget;
    if (alwaysAvailable) {
      stockWidget = const SizedBox.shrink();
    } else if (stockQty <= 0) {
      stockWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              context.t('soldOut'),
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 10 : 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFC62828),
              ),
            ),
          ],
        ),
      );
    } else if (stockQty <= 5) {
      stockWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFFB8C00),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              context.t('leftCount', args: {'count': stockQty}),
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 10 : 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF6C00),
              ),
            ),
          ],
        ),
      );
    } else {
      stockWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF43A047),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              context.t('availableCount', args: {'count': stockQty}),
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 10 : 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppTheme.primary : const Color(0xFFE5E2DD),
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!alwaysAvailable && stockQty <= 0) {
                      // Haptic notification for disabled/sold out click
                      HapticFeedback.heavyImpact();
                      return;
                    }
                    Haptics.light();
                    SoundManager.instance.playClickSound();
                    ref.read(tapCountsProvider.notifier).updateState((state) {
                      final newState = Map<dynamic, int>.from(state);
                      final nextVal = (state[productId] ?? 0) + 1;
                      if (nextVal >= 100 || nextVal <= 0) {
                        newState.remove(productId);
                      } else {
                        newState[productId] = nextVal;
                      }
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
                          borderRadius: BorderRadius.circular(14),
                          child: _buildProductImage(product),
                        ),
                      ),
                      if (product['is_syncing'] == true)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                      if (!alwaysAvailable && stockQty <= 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white30, width: 1),
                              ),
                              child: Text(
                                context.t('soldOut').toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: isSmallScreen ? 10 : 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      // Top Left Selection Badge / Regular Badge
                      Positioned(
                        top: isSmallScreen ? 4 : 8,
                        left: isSmallScreen ? 4 : 8,
                        child: isSelected
                            ? AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                scale: 1.0,
                                child: Container(
                                  width: isSmallScreen ? 28 : 32,
                                  height: isSmallScreen ? 28 : 32,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.gold, width: 1.2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: TextField(
                                      key: ValueKey("qty-$productId"),
                                      onChanged: (val) {
                                        final newVal = int.tryParse(val);
                                        if (val.isEmpty || newVal == 0 || (newVal != null && newVal < 0)) {
                                          ref.read(tapCountsProvider.notifier).updateState((state) {
                                            final newState = Map<dynamic, int>.from(state);
                                            newState.remove(productId);
                                            return newState;
                                          });
                                        } else if (newVal != null) {
                                          ref.read(tapCountsProvider.notifier).updateState((state) {
                                            final newState = Map<dynamic, int>.from(state);
                                            newState[productId] = newVal;
                                            return newState;
                                          });
                                        }
                                      },
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      controller: _qtyController,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 8, vertical: isSmallScreen ? 3 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 8 : 9,
                                  ),
                                ),
                              ),
                      ),
                      
                      // Top Right Ratings Badge
                      Positioned(
                        top: isSmallScreen ? 4 : 8,
                        right: isSmallScreen ? 4 : 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 6, vertical: isSmallScreen ? 2 : 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 2),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: AppTheme.gold, size: isSmallScreen ? 10 : 12),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 8.5 : 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              
              // Product Info Block
              Text(
                context.productName(product),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "₹${(product["price"] as num).toInt()}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: priceFontSize,
                      color: AppTheme.primary,
                      height: 1.1,
                    ),
                  ),
                  Flexible(child: stockWidget),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
          
          // X Close button when selected
          if (isSelected)
            Positioned(
              top: isSmallScreen ? -10 : -6,
              right: isSmallScreen ? -10 : -6,
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
                  width: isSmallScreen ? 20 : 24,
                  height: isSmallScreen ? 20 : 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E2DD), width: 1.2),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Icon(Icons.close_rounded, size: isSmallScreen ? 12 : 14, color: AppTheme.textSecondary),
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
    if (imageUrl != null && imageUrl.startsWith('http')) return CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: const Color(0xFFF1F3F5), child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))), errorWidget: (context, url, error) => _buildPlaceholderImage());
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(color: const Color(0xFFF1F3F5), alignment: Alignment.center, child: const Icon(Icons.image_not_supported_outlined, size: 30, color: Color(0xFFADB5BD)));
  }
}

class AddProductSheet extends StatefulWidget {
  final List<String> categories;
  final Function(
    String name,
    double price,
    String category,
    String imagePath,
    Map<String, String> nameI18n,
    Map<String, String> categoryI18n,
  ) onAdd;
  const AddProductSheet({super.key, required this.categories, required this.onAdd});
  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _nameController = TextEditingController();
  final _nameTaController = TextEditingController();
  final _priceController = TextEditingController();
  final _otherCategoryController = TextEditingController();
  final _categoryTaController = TextEditingController();
  late String _category;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _category = widget.categories.firstWhere((c) => c != "All", orElse: () => "Puff"); }
  @override
  void dispose() { 
    _nameController.dispose(); 
    _nameTaController.dispose();
    _priceController.dispose(); 
    _otherCategoryController.dispose();
    _categoryTaController.dispose();
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
            Text(context.t('addProduct'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: context.t('productNameEnglish'), border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameTaController,
              decoration: InputDecoration(labelText: context.t('productNameTamil'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.t('price'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: context.t('categoryEnglish'), border: const OutlineInputBorder()),
              items: widget.categories.where((c) => c != "All").map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (value) { if (value != null) setState(() => _category = value); },
            ),
            if (_category == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherCategoryController,
                decoration: InputDecoration(labelText: context.t('enterNewCategory'), border: const OutlineInputBorder(), hintText: context.t('categoryHint')),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _categoryTaController,
              decoration: InputDecoration(labelText: context.t('categoryTamil'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('tamilOptional'),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_selectedImage == null ? context.t('choosePhoto') : context.t('photoSelected')))),
            if (_selectedImage != null) ...[const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_selectedImage!.path), height: 120, width: double.infinity, fit: BoxFit.cover))],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text.trim());
              String finalCategory = _category;
              if (_category == "Other") {
                finalCategory = _otherCategoryController.text.trim();
              }
              if (name.isEmpty || price == null || price <= 0 || _selectedImage == null || (finalCategory == "Other" && finalCategory.isEmpty) || finalCategory.isEmpty) { 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('validAddProduct')))); 
                return; 
              }
              final nameI18n = _buildI18nMap(en: name, ta: _nameTaController.text.trim());
              final categoryI18n = _buildI18nMap(en: finalCategory, ta: _categoryTaController.text.trim());
              widget.onAdd(name, price, finalCategory, _selectedImage!.path, nameI18n, categoryI18n);
              Navigator.pop(context);
            }, child: Text(context.t('addProductButton')))),
          ],
        ),
      ),
    );
  }

  Map<String, String> _buildI18nMap({required String en, required String ta}) {
    return {
      'en': en,
      if (ta.isNotEmpty) 'ta': ta,
    };
  }
}

class SelectExistingProductSheet extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onSelect;
  final VoidCallback onCreateNew;

  const SelectExistingProductSheet({
    super.key,
    required this.products,
    required this.onSelect,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.t('addToCard'),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onCreateNew();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(context.t('createNew'), style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: products.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E2DD)),
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: _buildImage(product['image_url'] as String?),
                    ),
                  ),
                  title: Text(
                    context.productName(product),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    context.productCategory(product),
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  onTap: () {
                    onSelect(product);
                    Navigator.pop(context);
                  },
                );
              },
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
        placeholder: (context, url) => Container(color: const Color(0xFFF1F3F5)),
        errorWidget: (context, url, error) => Container(color: const Color(0xFFF1F3F5), child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFFADB5BD))),
      );
    } else if (imageUrl != null) {
      return Image.file(File(imageUrl), fit: BoxFit.cover);
    }
    return Container(color: const Color(0xFFF1F3F5), child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFFADB5BD)));
  }
}

class EditProductSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<String> categories;
  final Function(Map<String, dynamic> updates, String? newImagePath) onUpdate;
  final VoidCallback onDelete;
  final TimeSlot? activeSlot;

  const EditProductSheet({
    super.key,
    required this.product,
    required this.categories,
    required this.onUpdate,
    required this.onDelete,
    this.activeSlot,
  });

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

  void _showAddToSlotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add to Time Slot"),
        content: const Text("Select which slot you want to add this product to:"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updates = {
                ...widget.product,
                'category': 'Morning Snacks',
                'name_i18n': {'en': _nameController.text.trim()},
                'category_i18n': {'en': 'Morning Snacks'},
              };
              widget.onUpdate(updates, null);
              Navigator.pop(context); // Close the edit sheet
            },
            child: const Text("Morning"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updates = {
                ...widget.product,
                'category': 'Evening Snacks',
                'name_i18n': {'en': _nameController.text.trim()},
                'category_i18n': {'en': 'Evening Snacks'},
              };
              widget.onUpdate(updates, null);
              Navigator.pop(context); // Close the edit sheet
            },
            child: const Text("Evening"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedCategory = _category == "Other" ? _otherCategoryController.text.trim() : _category;
    final isAlwaysAvailable = isAlwaysAvailableFields(_nameController.text, resolvedCategory);
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
                Text(context.t('editProduct'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                      tooltip: "Add to slot",
                      onPressed: () => _showAddToSlotDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.primary),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDelete();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: context.t('productNameEnglish'), border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (isAlwaysAvailable)
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: context.t('price'), border: const OutlineInputBorder()),
              )
            else
              Row(
                children: [
                  Expanded(child: TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.t('price'), border: const OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _stockController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('stockQty'), border: const OutlineInputBorder()))),
                ],
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: context.t('categoryEnglish'), border: const OutlineInputBorder()),
              items: widget.categories.where((c) => c != "All").map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (value) { if (value != null) setState(() => _category = value); },
            ),
            if (_category == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherCategoryController,
                decoration: InputDecoration(labelText: context.t('enterNewCategory'), border: const OutlineInputBorder(), hintText: context.t('categoryHint')),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_selectedImage == null ? context.t('changePhoto') : context.t('newPhotoSelected')))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text.trim());
              String finalCategory = _category;
              if (_category == "Other") {
                finalCategory = _otherCategoryController.text.trim();
              }
              final alwaysAvailable = isAlwaysAvailableFields(name, finalCategory);
              if (name.isEmpty || price == null || price <= 0 || (finalCategory == "Other" && finalCategory.isEmpty) || finalCategory.isEmpty) { 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('validEditProduct')))); 
                return; 
              }
              final updates = <String, dynamic>{
                'name': name,
                'price': price,
                'category': finalCategory,
                'name_i18n': {'en': name},
                'category_i18n': {'en': finalCategory},
              };
              if (!alwaysAvailable) {
                final stock = int.tryParse(_stockController.text.trim()) ?? 0;
                updates['stock_qty'] = stock;
              }
              widget.onUpdate(updates, _selectedImage?.path);
              Navigator.pop(context);
            }, child: Text(context.t('saveChanges')))),
          ],
        ),
      ),
    );
  }
}

class CheckoutFloatingBar extends ConsumerWidget {
  const CheckoutFloatingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final tapCounts = ref.watch(tapCountsProvider);
    final selectedCount = tapCounts.values.fold<int>(0, (sum, count) => sum + count);
    
    if (selectedCount <= 0) return const SizedBox.shrink();

    final total = tapCounts.entries.fold<double>(0, (sum, entry) {
      final match = products.firstWhere((p) => p["id"] == entry.key, orElse: () => {});
      final price = match["price"] is num ? (match["price"] as num).toDouble() : 0.0;
      return sum + (price * entry.value);
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(context.t('selectedCount', args: {'count': selectedCount}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Flexible(child: Text(context.t('amount', args: {'amount': total.toStringAsFixed(0)}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.primary, width: 1),
              ),
            ),
            child: Text(
              context.t('continue'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

