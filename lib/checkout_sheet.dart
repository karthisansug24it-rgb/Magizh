import 'package:flutter/material.dart';
import 'celebration_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'main.dart'; // Access to tapCountsProvider, productsProvider, SoundManager, Haptics
import 'l10n/app_localizations.dart';
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

  void _onQuickCash(double amount) {
    Haptics.light();
    _cashController.text = amount.toStringAsFixed(0);
    // Listener in initState will update _cashCollected
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
        'product_name_i18n': product['name_i18n'] ?? {'en': product['name']},
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
        if (isAlwaysAvailableProduct(product)) {
          continue;
        }
        final currentStock = (product['stock_qty'] as num?)?.toInt() ?? 0;
        final newStock = currentStock - (item['qty'] as int);
        
        // We do this individually, but in a real app an RPC call is safer for concurrent updates.
        await client.from('products').update({'stock_qty': newStock < 0 ? 0 : newStock}).eq('id', item['product_id']);
      }

      // Success
      Haptics.success();
      
      // Clear basket
      ref.read(tapCountsProvider.notifier).set({});
      
      // Refresh products to get updated stock
      final response = await client.from('products').select().eq('is_active', true).order('name');
      ref.read(productsProvider.notifier).set(List<Map<String, dynamic>>.from(response));

      if (mounted) {
        Navigator.pop(context);
        showCelebration(context, context.t('orderSuccess'), icon: Icons.shopping_bag_rounded, bannerColor: const Color(0xFF2E7D32));
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('errorPlacingOrder', args: {'error': e})), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final tapCounts = ref.watch(tapCountsProvider);
    final totalAmount = tapCounts.entries.fold<double>(0, (sum, entry) {
      final match = products.firstWhere((p) => p["id"] == entry.key, orElse: () => {});
      final price = match["price"] is num ? (match["price"] as num).toDouble() : 0.0;
      return sum + (price * entry.value);
    });

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Fixed
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.t('checkout'), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('paymentMethod'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.7))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PaymentMethodCard(
                            title: context.t('online'),
                            icon: Icons.qr_code_rounded,
                            isSelected: _paymentMethod == 'Online',
                            onTap: () {
                              Haptics.light();
                              setState(() => _paymentMethod = 'Online');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PaymentMethodCard(
                            title: context.t('cash'),
                            icon: Icons.payments_outlined,
                            isSelected: _paymentMethod == 'Offline',
                            onTap: () {
                              Haptics.light();
                              setState(() => _paymentMethod = 'Offline');
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    Text(context.t('summary'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    ...tapCounts.entries.map((e) {
                      final p = products.firstWhere((pr) => pr['id'] == e.key, orElse: () => {});
                      if (p.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("${context.productName(p)} x ${e.value}", style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                            Text("₹${((p['price'] as num) * e.value).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                      );
                    }),
                    
                    const Divider(color: Color(0xFFEEEEEE), height: 24, thickness: 1),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.t('totalAmount'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("₹${totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    if (_paymentMethod == 'Offline') ...[
                      Text(context.t('cashReceived'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.7))),
                      const SizedBox(height: 12),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [10, 20, 50, 100, 200, 500].map((amount) {
                          return InkWell(
                            onTap: () => _onQuickCash(amount.toDouble()),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _cashCollected == amount ? AppTheme.primary : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _cashCollected == amount ? AppTheme.primary : Colors.grey.shade200),
                              ),
                              child: Text(
                                "₹$amount",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _cashCollected == amount ? Colors.white : AppTheme.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: context.t('enterAmount'),
                          prefixText: "₹ ",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _cashCollected >= totalAmount ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _cashCollected >= totalAmount ? context.t('balance') : context.t('short'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _cashCollected >= totalAmount ? Colors.green.shade700 : Colors.red.shade700),
                            ),
                            Text(
                              "₹${(_cashCollected - totalAmount).abs().toStringAsFixed(0)}",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _cashCollected >= totalAmount ? Colors.green.shade900 : Colors.red.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Add bottom padding to avoid keyboard covering the content inside the scrollview
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 0),
                  ],
                ),
              ),
            ),
            
            // Footer - Fixed
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: (_isProcessing || (_paymentMethod == 'Offline' && _cashCollected < totalAmount)) ? null : _processOrder,
                  child: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(context.t('confirmOrder', args: {'amount': totalAmount.toStringAsFixed(0)}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
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
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.7), size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

