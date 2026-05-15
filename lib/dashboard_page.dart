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
  Map<int, double> _monthsInYearSales = <int, double>{};
  Map<int, int> _daysOfWeekSales = {};

  // Search by Date state
  DateTime? _searchedDate;
  int _searchedDateOrders = 0;
  double _searchedDateRevenue = 0;

  // Chart Interaction State
  final ScrollController _monthlyScrollController = ScrollController();
  int _touchedMonthlyIndex = -1;
  int _touchedYearlyIndex = -1;
  int _touchedWeeklyIndex = -1;

  @override
  void dispose() {
    _monthlyScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchedDate = DateTime.now(); // Default to today
    _touchedMonthlyIndex = DateTime.now().day - 1; // Highlight today in chart
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
      if (mounted) {
        setState(() {
          _transactions = data;
        });
        _processData(data);
        setState(() {
          _isLoading = false;
        });
        _scrollToCurrentDay();
      }
    } catch (e) {
      debugPrint('DASHBOARD FETCH ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToCurrentDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_monthlyScrollController.hasClients) {
        final day = DateTime.now().day;
        if (day > 3) { // Only scroll if past the first few days
          final offset = (day - 3) * (1200 / 31);
          _monthlyScrollController.animateTo(
            offset,
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  void _processData(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    double currentMonthRevenue = 0;
    int currentMonthOrders = 0;
    int currentYearOrders = 0;
    
    Map<int, int> daysInMonthSales = {};
    Map<int, double> monthsInYearSales = {};
    Map<int, int> daysOfWeekSales = {};
    
    // Initialize maps
    for (int i = 1; i <= 31; i++) daysInMonthSales[i] = 0;
    for (int i = 1; i <= 12; i++) monthsInYearSales[i] = 0.0;
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
      
      // Current Year Revenue per Month
      if (createdAt.year == now.year) {
        currentYearOrders++;
        monthsInYearSales[createdAt.month] = (monthsInYearSales[createdAt.month] ?? 0) + amount;
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
                    "${_daysInMonthSales[_touchedMonthlyIndex + 1] ?? 0} Orders",
                    scrollableWidth: 1200, // Even larger width for all 31 thick bars and labels
                    controller: _monthlyScrollController,
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle("Yearly Trend (This Year)"),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildYearlyTrendChart(), 
                    "Total revenue trend per month for ${DateTime.now().year}",
                    _touchedYearlyIndex,
                    DateFormat('MMMM').format(DateTime(2024, _touchedYearlyIndex == -1 ? 1 : _touchedYearlyIndex + 1)),
                    "₹${_monthsInYearSales[_touchedYearlyIndex + 1]?.toStringAsFixed(0) ?? '0'}",
                    scrollableWidth: 600, // Space for full Jan, Feb labels
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current Month Salary", style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    Text("$monthName Tracker", style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "₹${_monthlyRevenue.toInt()}",
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF8B0000), letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$_monthlyOrders total orders",
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up, color: Color(0xFF8B0000), size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Growth",
                      style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Search by Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Row(
                mainAxisSize: MainAxisSize.min,
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
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartContainer(Widget chart, String subtitle, int touchedIndex, String label, String value, {double? scrollableWidth, ScrollController? controller}) {
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
                  Text(label, style: const TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween<double>(begin: 0, end: double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0),
                    curve: Curves.easeOutCirc,
                    builder: (context, val, child) {
                      final prefix = value.contains('₹') ? '₹' : '';
                      final suffix = value.contains('Orders') ? ' Orders' : '';
                      return Text(
                        "$prefix${val.toStringAsFixed(0)}$suffix", 
                        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF8B0000), letterSpacing: -1)
                      );
                    },
                  ),
                ],
              ),
            ),
            )
          else
            const SizedBox(height: 62), // Placeholder to prevent jump
          const SizedBox(height: 32),
          if (scrollableWidth != null)
            ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(physics: const BouncingScrollPhysics()),
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: scrollableWidth,
                  height: 180,
                  child: chart,
                ),
              ),
            )
          else
            SizedBox(height: 300, child: chart),
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
            if (barTouchResponse != null && barTouchResponse.spot != null) {
              setState(() => _touchedMonthlyIndex = barTouchResponse.spot!.touchedBarGroupIndex);
            }
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
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    value.toInt().toString(), 
                    style: GoogleFonts.inter(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)
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
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: _daysInMonthSales.values.isEmpty ? 0 : _daysInMonthSales.values.reduce((a, b) => a + b) / daysInMonth,
              color: AppTheme.primary.withValues(alpha: 0.2),
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                labelResolver: (_) => "AVG",
              ),
            ),
          ],
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
                    : [
                        _getRainbowColor(i).withValues(alpha: 0.8),
                        _getRainbowColor(i).withValues(alpha: 0.4),
                      ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: isTouched ? 32 : 28,
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

  Widget _buildYearlyTrendChart() {
    double maxY = 500;
    for (int i = 1; i <= 12; i++) {
      if ((_monthsInYearSales[i] ?? 0) > maxY) {
        maxY = (_monthsInYearSales[i] ?? 0).toDouble() + 500;
      }
    }

    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.black.withValues(alpha: 0.03), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt() - 1;
                if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(monthNames[idx], style: GoogleFonts.inter(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox.shrink();
                return Text("₹${value.toInt()}", style: GoogleFonts.inter(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.w500));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
              setState(() => _touchedYearlyIndex = response.lineBarSpots!.first.x.toInt() - 1);
            }
          },
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                FlLine(color: AppTheme.primary.withValues(alpha: 0.15), strokeWidth: 3),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 8,
                    color: AppTheme.primary,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.transparent,
            getTooltipItems: (spots) => [],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(12, (i) => FlSpot(i + 1.0, (_monthsInYearSales[i + 1] ?? 0).toDouble())),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [
                Colors.purple,
                Colors.indigo,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.orange,
                Colors.red,
              ],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: index == _touchedYearlyIndex ? 6 : 0,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: _getRainbowColor(index),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withValues(alpha: 0.3),
                  Colors.blue.withValues(alpha: 0.3),
                  Colors.green.withValues(alpha: 0.3),
                  Colors.orange.withValues(alpha: 0.3),
                  Colors.red.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        maxY: maxY,
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
    final avgOrders = _daysOfWeekSales.values.isEmpty ? 0.0 : _daysOfWeekSales.values.reduce((a, b) => a + b) / 7;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (barTouchResponse != null && barTouchResponse.spot != null) {
              setState(() => _touchedWeeklyIndex = barTouchResponse.spot!.touchedBarGroupIndex);
            }
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
              reservedSize: 45, // Increased for 500+ orders
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(), 
                  style: GoogleFonts.inter(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)
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
          horizontalInterval: maxY > 100 ? 100 : (maxY > 20 ? 10 : 5),
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.black.withValues(alpha: 0.03), strokeWidth: 1);
          },
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: avgOrders,
              color: AppTheme.primary.withValues(alpha: 0.2),
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                labelResolver: (_) => "AVG",
              ),
            ),
          ],
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
                    : [
                        _getWeeklyColor(i).withValues(alpha: 0.8),
                        _getWeeklyColor(i).withValues(alpha: 0.4),
                      ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: isTouched ? 28 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
  Color _getRainbowColor(int index) {
    const colors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
    ];
    return colors[index % colors.length];
  }

  Color _getWeeklyColor(int index) {
    const colors = [
      Color(0xFFE53935), // Mon - Red
      Color(0xFFFB8C00), // Tue - Orange
      Color(0xFFFDD835), // Wed - Yellow
      Color(0xFF43A047), // Thu - Green
      Color(0xFF1E88E5), // Fri - Blue
      Color(0xFF5E35B1), // Sat - Deep Purple
      Color(0xFF8E24AA), // Sun - Purple
    ];
    return colors[index % colors.length];
  }
}
