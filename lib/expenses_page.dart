import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseTransactionsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    _fetch();
    return const AsyncValue.loading();
  }

  Future<void> _fetch() async {
    try {
      final response = await Supabase.instance.client
          .from('expense_transactions')
          .select()
          .order('created_at', ascending: false);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final expensesProvider = NotifierProvider<ExpenseTransactionsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
    ExpenseTransactionsNotifier.new);

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        title: Text(
          "Expense",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No sales yet today!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              return ExpenseCard(expense: expenses[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000))),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;

  const ExpenseCard({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    if (expense['items'] != null) {
      try {
        items = jsonDecode(expense['items'] as String);
      } catch (e) {
        items = [];
      }
    }

    final createdAt = DateTime.tryParse(expense['created_at'] ?? '')?.toLocal() ?? DateTime.now();
    final dayName = DateFormat('EEEE').format(createdAt);
    final dateStr = DateFormat('dd-MM-yyyy').format(createdAt);
    final timeStr = DateFormat('h:mma').format(createdAt).toLowerCase();

    final totalAmount = (expense['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = (expense['payment_method'] as String?)?.toLowerCase() ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items List
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['product_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  Text(
                    "x${item['qty'] ?? 1}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B0000), fontSize: 14),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date and Time info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Day: $dayName", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Date: $dateStr", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text("Time: $timeStr", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 12),
                  // Payment Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'online' ? Colors.blue.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 14,
                          color: paymentMethod == 'online' ? Colors.blue.shade700 : Colors.green.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          paymentMethod == 'online' ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: paymentMethod == 'online' ? Colors.blue.shade700 : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              // Total Amount
              Text(
                "₹${totalAmount.toInt()}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Color(0xFF8B0000),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
