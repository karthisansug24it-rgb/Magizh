import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';

// Simple notifiers to hold the data
class ExpensesListNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];
  void update(List<Map<String, dynamic>> data) => state = data;
}

class ExpensesLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void update(bool loading) => state = loading;
}

final expensesListProvider = NotifierProvider<ExpensesListNotifier, List<Map<String, dynamic>>>(ExpensesListNotifier.new);
final isExpensesLoadingProvider = NotifierProvider<ExpensesLoadingNotifier, bool>(ExpensesLoadingNotifier.new);

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  @override
  void initState() {
    super.initState();
    // Fetch data as soon as the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    ref.read(isExpensesLoadingProvider.notifier).update(true);
    
    try {
      debugPrint("EXPENSE_DEBUG: Starting fetch from 'expense_transactions'...");
      
      final response = await Supabase.instance.client
          .from('expense_transactions')
          .select('*')
          .order('created_at', ascending: false);
      
      debugPrint("EXPENSE_DEBUG: Successfully fetched ${response.length} rows.");
      
      if (mounted) {
        ref.read(expensesListProvider.notifier).update(List<Map<String, dynamic>>.from(response));
        ref.read(isExpensesLoadingProvider.notifier).update(false);
      }
    } catch (e) {
      debugPrint("EXPENSE_DEBUG: FATAL ERROR during fetch: $e");
      if (mounted) {
        ref.read(isExpensesLoadingProvider.notifier).update(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fetch error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesListProvider);
    final isLoading = ref.watch(isExpensesLoadingProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
        title: const Text("Expense", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _fetchData,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 80, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      const Text("No orders found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetchData, child: const Text("Try Again", style: TextStyle(color: AppTheme.primary))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) => ExpenseCard(expense: expenses[index]),
                  ),
                ),
    );
  }
}

class ExpenseCard extends StatefulWidget {
  final Map<String, dynamic> expense;
  const ExpenseCard({super.key, required this.expense});

  @override
  State<ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<ExpenseCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Robust item parsing
    List<dynamic> items = [];
    final rawItems = widget.expense['items'];
    if (rawItems != null) {
      if (rawItems is String) {
        try { items = jsonDecode(rawItems); } catch (_) {}
      } else if (rawItems is List) {
        items = rawItems;
      }
    }

    final createdAt = DateTime.tryParse(widget.expense['created_at'] ?? '')?.toLocal() ?? DateTime.now();
    final timeStr = DateFormat('h:mma').format(createdAt).toLowerCase();
    final dayName = DateFormat('EEEE').format(createdAt);
    final dateStrFormatted = DateFormat('dd-MM-yyyy').format(createdAt);
    final paymentMethod = (widget.expense['payment_method'] as String?)?.toLowerCase() ?? 'unknown';

    return GestureDetector(
      onTap: () {
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Total and Time summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "₹${(widget.expense['total_amount'] as num).toInt()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: paymentMethod == 'online' ? Colors.blue.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              paymentMethod == 'online' ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: paymentMethod == 'online' ? Colors.blue.shade700 : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$dayName, $timeStr • ${items.length} items",
                        style: TextStyle(fontSize: 12, color: AppTheme.primary.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppTheme.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
            
            // Collapsible Section
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "x${item['qty'] ?? 1}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Text(
                "Date: $dateStrFormatted",
                style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

