import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  
  // Processed Data
  double _monthlyRevenue = 0;
  int _monthlyOrders = 0;
  int _yearlyOrders = 0;
  
  Map<int, int> _daysInMonthSales = {};
  Map<int, int> _monthsInYearSales = {};
  Map<int, int> _daysOfWeekSales = {};

  // Search by Date state
  DateTime? _searchedDate;
  int _searchedDateOrders = 0;
  double _searchedDateRevenue = 0;

  // Chart Interaction State
  int _touchedMonthlyIndex = -1;
  int _touchedYearlyIndex = -1;
  int _touchedWeeklyIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('expense_transactions')
          .select('*')
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);
      _processData(data);
      
      if (mounted) {
        setState(() {
          _transactions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DASHBOARD FETCH ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    double currentMonthRevenue = 0;
    int currentMonthOrders = 0;
    int currentYearOrders = 0;
    
    Map<int, int> daysInMonthSales = {};
    Map<int, int> monthsInYearSales = {};
    Map<int, int> daysOfWeekSales = {};
    
    // Initialize maps
    for (int i = 1; i <= 31; i++) daysInMonthSales[i] = 0;
    for (int i = 1; i <= 12; i++) monthsInYearSales[i] = 0;
    for (int i = 1; i <= 7; i++) daysOfWeekSales[i] = 0;

    for (final tx in data) {
      final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
      final createdAt = DateTime.tryParse(tx['created_at'] ?? '')?.toLocal() ?? DateTime.now();
      
      // Current Month Salary / Orders
      if (createdAt.year == now.year && createdAt.month == now.month) {
        currentMonthRevenue += amount;
        currentMonthOrders++;
        daysInMonthSales[createdAt.day] = (daysInMonthSales[createdAt.day] ?? 0) + 1;
      }
      
      // Current Year Orders
      if (createdAt.year == now.year) {
        currentYearOrders++;
        monthsInYearSales[createdAt.month] = (monthsInYearSales[createdAt.month] ?? 0) + 1;
      }
      
      // All time Day of Week
      daysOfWeekSales[createdAt.weekday] = (daysOfWeekSales[createdAt.weekday] ?? 0) + 1;
    }

    _monthlyRevenue = currentMonthRevenue;
    _monthlyOrders = currentMonthOrders;
    _yearlyOrders = currentYearOrders;
    _daysInMonthSales = daysInMonthSales;
    _monthsInYearSales = monthsInYearSales;
    _daysOfWeekSales = daysOfWeekSales;
    
    if (_searchedDate != null) {
      _calculateSearchedDate(_searchedDate!);
    }
  }

  void _calculateSearchedDate(DateTime date) {
    int orders = 0;
    double revenue = 0;
    for (final tx in _transactions) {
      final createdAt = DateTime.tryParse(tx['created_at'] ?? '')?.toLocal() ?? DateTime.now();
      if (createdAt.year == date.year && createdAt.month == date.month && createdAt.day == date.day) {
        orders++;
        revenue += (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    setState(() {
      _searchedDateOrders = orders;
      _searchedDateRevenue = revenue;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _searchedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B0000), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _searchedDate = picked;
      });
      _calculateSearchedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Analytics & Tracker", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchData,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
        : RefreshIndicator(
            onRefresh: _fetchData,
            color: const Color(0xFF8B0000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSalaryCard(),
                  const SizedBox(height: 24),
                  _buildDateSearch(),
                  const SizedBox(height: 32),
                  
                  _buildSectionTitle("Daily Orders (This Month)"),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildMonthlyDaysChart(), 
                    "Orders by day for ${DateFormat('MMMM yyyy').format(DateTime.now())}",
                    _touchedMonthlyIndex,
                    "Day ${_touchedMonthlyIndex + 1}",
                    "${_daysInMonthSales[_touchedMonthlyIndex + 1] ?? 0} Orders"
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle("Monthly Orders (This Year)"),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildYearlyMonthsChart(),
                    "Orders per month for ${DateTime.now().year}",
                    _touchedYearlyIndex,
                    DateFormat('MMMM').format(DateTime(2024, _touchedYearlyIndex == -1 ? 1 : _touchedYearlyIndex + 1)),
                    "${_monthsInYearSales[_touchedYearlyIndex + 1] ?? 0} Orders"
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle("Orders by Weekday (All Time)"),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildWeeklyDaysChart(),
                    "Which days are the busiest?",
                    _touchedWeeklyIndex,
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][_touchedWeeklyIndex == -1 ? 0 : _touchedWeeklyIndex],
                    "${_daysOfWeekSales[_touchedWeeklyIndex + 1] ?? 0} Orders"
                  ),
                  
                  const SizedBox(height: 100), // Space for bottom nav
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
    );
  }

  Widget _buildSalaryCard() {
    final monthName = DateFormat('MMMM').format(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFF8B0000).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF8B0000), size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Current Month Salary", style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                  Text("$monthName Tracker", style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "₹${_monthlyRevenue.toInt()}",
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF8B0000), letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$_monthlyOrders total orders this month",
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDateSearch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Search by Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF8B0000)),
                    onPressed: _searchedDate == null ? null : () {
                      final newDate = _searchedDate!.subtract(const Duration(days: 1));
                      setState(() => _searchedDate = newDate);
                      _calculateSearchedDate(newDate);
                    },
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(
                      _searchedDate == null ? "Select Date" : DateFormat('EEE, d MMM').format(_searchedDate!), 
                      style: const TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold)
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF8B0000)),
                    onPressed: _searchedDate == null ? null : () {
                      final newDate = _searchedDate!.add(const Duration(days: 1));
                      if (newDate.isAfter(DateTime.now())) return;
                      setState(() => _searchedDate = newDate);
                      _calculateSearchedDate(newDate);
                    },
                  ),
                ],
              )
            ],
          ),
          if (_searchedDate != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFEEEEEE)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSearchStat("Orders", _searchedDateOrders.toString(), Icons.shopping_bag_outlined),
                Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
                _buildSearchStat("Revenue", "₹${_searchedDateRevenue.toInt()}", Icons.currency_rupee),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildSearchStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.black54),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black)),
      ],
    );
  }

  Widget _buildBarChartContainer(Widget chart, String subtitle, int touchedIndex, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 30, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          if (touchedIndex != -1)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              builder: (context, val, child) => Opacity(
                opacity: val,
                child: Column(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1),
                    ),
                    Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 62), // Placeholder to prevent jump
          const SizedBox(height: 32),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _buildMonthlyDaysChart() {
    final daysInMonth = DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month);
    
    // Find max value for Y axis
    double maxY = 5;
    for (int i = 1; i <= daysInMonth; i++) {
      if ((_daysInMonthSales[i] ?? 0) > maxY) {
        maxY = (_daysInMonthSales[i] ?? 0).toDouble() + 2;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  barTouchResponse == null ||
                  barTouchResponse.spot == null) {
                _touchedMonthlyIndex = -1;
                return;
              }
              _touchedMonthlyIndex = barTouchResponse.spot!.touchedBarGroupIndex;
            });
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return null; // Custom UI below chart
            },
          ),
          enabled: true,
          handleBuiltInTouches: false,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value % 5 != 0 && value != 1 && value != daysInMonth) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    value.toInt().toString(), 
                    style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w600)
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(), 
                  style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w500)
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 10 ? 5 : 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.black.withValues(alpha: 0.03), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(daysInMonth, (i) {
          final day = i + 1;
          final isTouched = i == _touchedMonthlyIndex;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: (_daysInMonthSales[day] ?? 0).toDouble(),
                gradient: LinearGradient(
                  colors: isTouched 
                    ? [const Color(0xFF8B0000), const Color(0xFFE53935)] 
                    : [const Color(0xFF8B0000).withValues(alpha: 0.3), const Color(0xFF8B0000).withValues(alpha: 0.1)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: isTouched ? 12 : 8,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.black.withValues(alpha: 0.01),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildYearlyMonthsChart() {
    double maxY = 5;
    for (int i = 1; i <= 12; i++) {
      if ((_monthsInYearSales[i] ?? 0) > maxY) {
        maxY = (_monthsInYearSales[i] ?? 0).toDouble() + 5;
      }
    }

    final monthNames = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  barTouchResponse == null ||
                  barTouchResponse.spot == null) {
                _touchedYearlyIndex = -1;
                return;
              }
              _touchedYearlyIndex = barTouchResponse.spot!.touchedBarGroupIndex;
            });
          },
          enabled: true,
          handleBuiltInTouches: false,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final month = value.toInt();
                if (month < 1 || month > 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    monthNames[month - 1], 
                    style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(), 
                  style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w500)
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 20 ? 10 : 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.black.withValues(alpha: 0.03), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (i) {
          final month = i + 1;
          final isTouched = i == _touchedYearlyIndex;
          return BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: (_monthsInYearSales[month] ?? 0).toDouble(),
                gradient: LinearGradient(
                  colors: isTouched 
                    ? [const Color(0xFF8B0000), const Color(0xFFE53935)] 
                    : [const Color(0xFF8B0000).withValues(alpha: 0.2), const Color(0xFF8B0000).withValues(alpha: 0.05)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: isTouched ? 32 : 24,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.black.withValues(alpha: 0.01),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWeeklyDaysChart() {
    double maxY = 5;
    for (int i = 1; i <= 7; i++) {
      if ((_daysOfWeekSales[i] ?? 0) > maxY) {
        maxY = (_daysOfWeekSales[i] ?? 0).toDouble() + 5;
      }
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  barTouchResponse == null ||
                  barTouchResponse.spot == null) {
                _touchedWeeklyIndex = -1;
                return;
              }
              _touchedWeeklyIndex = barTouchResponse.spot!.touchedBarGroupIndex;
            });
          },
          enabled: true,
          handleBuiltInTouches: false,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final day = value.toInt();
                if (day < 1 || day > 7) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    dayNames[day - 1], 
                    style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(), 
                  style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w500)
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 20 ? 10 : 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.black.withValues(alpha: 0.03), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          final day = i + 1;
          final isTouched = i == _touchedWeeklyIndex;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: (_daysOfWeekSales[day] ?? 0).toDouble(),
                gradient: LinearGradient(
                  colors: isTouched 
                    ? [const Color(0xFF8B0000), const Color(0xFFE53935)] 
                    : [const Color(0xFF8B0000).withValues(alpha: 0.2), const Color(0xFF8B0000).withValues(alpha: 0.05)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: isTouched ? 42 : 36,
                borderRadius: BorderRadius.circular(8),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.black.withValues(alpha: 0.01),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
