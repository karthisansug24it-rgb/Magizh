import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'l10n/app_localizations.dart';

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
          SnackBar(content: Text(context.t('fetchError', args: {'error': e})), backgroundColor: Colors.red),
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
        backgroundColor: const Color(0xFF2D5016),
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('expense'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D5016), strokeWidth: 2))
          : expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text(
                        context.t('noOrdersFound'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _fetchData,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.t('tryAgain')),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF2D5016)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: const Color(0xFF2D5016),
                  child: _buildGroupedListView(expenses),
                ),
    );
  }

  Widget _buildGroupedListView(List<Map<String, dynamic>> expenses) {
    // Group expenses by Month Year
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      final date = DateTime.tryParse(exp['created_at'] ?? '')?.toLocal() ?? DateTime.now();
      final monthYear = DateFormat('MMMM yyyy').format(date);
      
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(exp);
    }

    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: keys.length,
      itemBuilder: (context, sectionIndex) {
        final monthYear = keys[sectionIndex];
        final monthExpenses = grouped[monthYear]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF2D5016)),
                  const SizedBox(width: 8),
                  Text(
                    monthYear,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D5016),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5016).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${monthExpenses.length} Orders",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D5016),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...monthExpenses.asMap().entries.map((entry) {
              final idx = entry.key;
              final exp = entry.value;
              return ExpenseCard(
                expense: exp,
                index: monthExpenses.length - idx,
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final int index;
  const ExpenseCard({super.key, required this.expense, required this.index});

  @override
  Widget build(BuildContext context) {
    // Robust item parsing
    List<dynamic> items = [];
    final rawItems = expense['items'];
    if (rawItems != null) {
      if (rawItems is String) {
        try {
          items = jsonDecode(rawItems);
        } catch (_) {}
      } else if (rawItems is List) {
        items = rawItems;
      }
    }

    final createdAt = DateTime.tryParse(expense['created_at'] ?? '')?.toLocal() ?? DateTime.now();
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final timeStr = DateFormat('h:mma', localeName).format(createdAt).toLowerCase();
    final dayName = DateFormat('EEEE', localeName).format(createdAt);
    final dateStr = DateFormat('dd-MM-yyyy', localeName).format(createdAt);
    final paymentMethod = (expense['payment_method'] as String?)?.toLowerCase() ?? 'unknown';
    final isOnline = paymentMethod == 'online';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D5016), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Items Section (Top)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D5016).withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Order #$index",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: const Color(0xFF2D5016),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Icon(
                      Icons.receipt_rounded,
                      size: 14,
                      color: Color(0xFF2D5016),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final itemMap = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                  final itemName = context.localizedProductValue(
                    itemMap,
                    i18nColumn: 'product_name_i18n',
                    fallbackColumn: 'product_name',
                  );
                  final itemQty = (itemMap['qty'] as num?)?.toInt() ?? 1;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            itemName.isEmpty ? context.t('unknown') : itemName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          "x$itemQty",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: const Color(0xFF2D5016),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // 2. Details Section (Bottom)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Day: $dayName",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Date: $dateStr",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Time: $timeStr",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Payment Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 14,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? context.t('online') : context.t('offline'),
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Amount
                Text(
                  "₹${(expense['total_amount'] as num).toInt()}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: Colors.black,
                    letterSpacing: -0.5,
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

