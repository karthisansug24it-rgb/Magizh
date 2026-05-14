import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'main.dart'; // Access to tapCountsProvider, productsProvider, SoundManager, Haptics
import 'expenses_page.dart';
import 'theme/app_theme.dart';

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  String _paymentMethod = 'Online'; // Default payment method
  bool _isProcessing = false;
  final TextEditingController _cashController = TextEditingController();
  double _cashCollected = 0.0;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(() {
      setState(() {
        _cashCollected = double.tryParse(_cashController.text) ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _processOrder() async {
    final tapCounts = ref.read(tapCountsProvider);
    if (tapCounts.isEmpty) return;

    setState(() => _isProcessing = true);
    Haptics.medium();

    final allProducts = ref.read(productsProvider);
    double totalAmount = 0;
    List<Map<String, dynamic>> orderItems = [];

    // Build order data
    for (final entry in tapCounts.entries) {
      final productId = entry.key;
      final qty = entry.value;
      
      final product = allProducts.firstWhere((p) => p['id'] == productId, orElse: () => {});
      if (product.isEmpty) continue;

      final price = (product['price'] as num).toDouble();
      final lineTotal = price * qty;
      totalAmount += lineTotal;

      orderItems.add({
        'product_id': productId,
        'product_name': product['name'],
        'unit_price': price,
        'qty': qty,
        'line_total': lineTotal,
      });
    }

    try {
      final client = Supabase.instance.client;

      // final now = DateTime.now();
      // final dayName = DateFormat('EEEE').format(now);
      // final dateStr = DateFormat('dd-MM-yyyy').format(now);
      // final timeStr = DateFormat('h:mma').format(now).toLowerCase();

      final generatedId = const Uuid().v4();
      final payload = {
        'id': generatedId,
        'payment_method': _paymentMethod.toLowerCase(),
        'total_amount': totalAmount,
        'items': orderItems,
      };
      
      debugPrint("Attempting to insert order: $payload");

      // 1. Insert into expense_transactions
      await client.from('expense_transactions').insert(payload);

      // 2. Update stock quantities
      for (final item in orderItems) {
        final product = allProducts.firstWhere((p) => p['id'] == item['product_id']);
        final currentStock = (product['stock_qty'] as num?)?.toInt() ?? 0;
        final newStock = currentStock - (item['qty'] as int);
        
        // We do this individually, but in a real app an RPC call is safer for concurrent updates.
        await client.from('products').update({'stock_qty': newStock < 0 ? 0 : newStock}).eq('id', item['product_id']);
      }

      // Success
      Haptics.success();
      SoundManager.instance.playClickSound(); // Or a specific success sound
      
      // Clear basket
      ref.read(tapCountsProvider.notifier).set({});
      
      // Refresh products to get updated stock
      final response = await client.from('products').select().eq('is_active', true).order('name');
      ref.read(productsProvider.notifier).set(List<Map<String, dynamic>>.from(response));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order placed successfully! 🎉'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            margin: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tapCounts = ref.watch(tapCountsProvider);
    final products = ref.watch(productsProvider);

    if (tapCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    double totalAmount = 0;
    final itemsList = tapCounts.entries.map((entry) {
      final match = products.firstWhere((p) => p["id"] == entry.key, orElse: () => {});
      final price = match["price"] is num ? (match["price"] as num).toDouble() : 0.0;
      final name = match["name"] ?? "Unknown";
      final lineTotal = price * entry.value;
      totalAmount += lineTotal;
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "$name  x${entry.value}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              "₹${lineTotal.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Checkout",
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 8),
          
          // Order Items
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...itemsList,
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Amount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("₹${totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Payment Method
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Payment Method", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentMethodCard(
                          title: "Online",
                          icon: Icons.qr_code,
                          isSelected: _paymentMethod == 'Online',
                          onTap: () {
                            Haptics.light();
                            SoundManager.instance.playClickSound();
                            setState(() => _paymentMethod = 'Online');
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PaymentMethodCard(
                          title: "Cash",
                          icon: Icons.payments_outlined,
                          isSelected: _paymentMethod == 'Offline', // "Offline" matches existing db convention
                          onTap: () {
                            Haptics.light();
                            SoundManager.instance.playClickSound();
                            setState(() => _paymentMethod = 'Offline');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Cash Collection UI
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _paymentMethod == 'Offline' ? Column(
                      key: const ValueKey('cash'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
                        const SizedBox(height: 16),
                        const Text("Cash Received from Customer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Enter amount...",
                            prefixText: "₹ ",
                            prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                          ),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        if (_cashController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _cashCollected >= totalAmount ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _cashCollected >= totalAmount ? Colors.green.shade200 : Colors.red.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _cashCollected >= totalAmount ? "Balance to Give" : "Amount Pending",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _cashCollected >= totalAmount ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                    Text(
                                      _cashCollected >= totalAmount 
                                          ? "₹${(_cashCollected - totalAmount).toStringAsFixed(0)}"
                                          : "₹${(totalAmount - _cashCollected).toStringAsFixed(0)}",
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: _cashCollected >= totalAmount ? Colors.green.shade900 : Colors.red.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_cashCollected >= totalAmount)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "Give ₹${(_cashCollected - totalAmount).toStringAsFixed(0)} back to customer",
                                      style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 32),
                      ],
                    ) : const SizedBox(key: ValueKey('none'), height: 32),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Action
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  onPressed: (_isProcessing || (_paymentMethod == 'Offline' && _cashCollected < totalAmount)) ? null : _processOrder,
                  child: _isProcessing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text("Place Order (₹${totalAmount.toStringAsFixed(0)})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.black, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
