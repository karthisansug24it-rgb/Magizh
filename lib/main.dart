import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase config. Run with --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const MagizhPosApp());
}

class SoundManager {
  SoundManager._();

  static final SoundManager instance = SoundManager._();
  final AudioPlayer _player = AudioPlayer();

  Future<void> playClickSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sound/click.mp3.wav'));
    } catch (e) {
      debugPrint('Failed to play tap sound: $e');
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
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> categories = ["All", "Puff", "Samosa", "Roll", "Drinks", "Other"];
  String selectedCategory = "All";
  int _nextProductId = 7;

  final List<Map<String, dynamic>> products = [
    {
      "id": 1,
      "name": "Chicken Puff",
      "price": 1,
      "category": "Puff",
      "image": "assets/images/chicken puff.jpeg",
      "isLocalImage": false,
    },
    {
      "id": 2,
      "name": "Egg Puff",
      "price": 1,
      "category": "Puff",
      "image": "assets/images/egg puff.png",
      "isLocalImage": false,
    },
    {
      "id": 3,
      "name": "Samosa",
      "price": 1,
      "category": "Samosa",
      "image": "assets/images/samosa.jpeg",
      "isLocalImage": false,
    },
    {
      "id": 4,
      "name": "Veg Puff",
      "price": 1,
      "category": "Puff",
      "image": "assets/images/veg puff.jpeg",
      "isLocalImage": false,
    },
    {
      "id": 5,
      "name": "Paneer Puff",
      "price": 1,
      "category": "Puff",
      "image": "assets/images/paneer puff.jpeg",
      "isLocalImage": false,
    },
    {
      "id": 6,
      "name": "Mushroom Puff",
      "price": 1,
      "category": "Puff",
      "image": "assets/images/mushroom puff.jpeg",
      "isLocalImage": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredProducts = selectedCategory == "All"
        ? products
        : products
              .where(
                (p) => p["category"].toString().toLowerCase() == selectedCategory.toLowerCase(),
              )
              .toList();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildAdminQuickAction(),
                _buildCategories(),
                Expanded(child: _buildProductGrid(filteredProducts)),
              ],
            ),
            _buildBottomNav(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdminAddProductSheet,
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text("Admin"),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Magizh",
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8B0000),
              letterSpacing: -1.1,
              height: 1.0,
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openAdminAddProductSheet,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _openAdminAddProductSheet() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    var category = "Puff";
    XFile? selectedImage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage() async {
              final image = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 80,
              );
              if (image != null) {
                setModalState(() {
                  selectedImage = image;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Admin: Add Product",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Product name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Price",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .where((c) => c != "All")
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() {
                          category = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              selectedImage == null ? "Choose photo" : "Photo selected",
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedImage != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(selectedImage!.path),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final name = nameController.text.trim();
                          final price = double.tryParse(priceController.text.trim());

                          if (name.isEmpty || price == null || price <= 0 || selectedImage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Enter valid name, price, and choose a photo from gallery.",
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            products.add({
                              "id": _nextProductId++,
                              "name": name,
                              "price": price,
                              "category": category,
                              "image": selectedImage!.path,
                              "isLocalImage": true,
                            });
                          });

                          Navigator.pop(context);
                        },
                        child: const Text("Add product"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const TextField(
          decoration: InputDecoration(
            hintText: "Search for food...",
            hintStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminQuickAction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openAdminAddProductSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.admin_panel_settings),
          label: const Text("ADMIN: Add product"),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 60,
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
                setState(() {
                  selectedCategory = cat;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B0000) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: isSelected ? null : Border.all(color: Colors.grey.shade200),
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
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    SoundManager.instance.playClickSound();
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: (product["isLocalImage"] == true)
                            ? Image.file(
                                File(product["image"]),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFFF1F3F5),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 30,
                                    color: Color(0xFFADB5BD),
                                  ),
                                ),
                              )
                            : Image.asset(
                                product["image"],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFFF1F3F5),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 30,
                                    color: Color(0xFFADB5BD),
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_border,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product["name"],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "₹${product["price"]}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF8B0000),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, "Home", true),
            _buildNavItem(Icons.shopping_basket_outlined, "Basket", false),
            _buildNavItem(Icons.favorite_border, "Favorites", false),
            _buildNavItem(Icons.person_outline, "Profile", false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF8B0000) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade400,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
