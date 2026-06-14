import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
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
      await _deleteExpiredOrders();

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

  Future<void> _deleteExpiredOrders() async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - 2, now.day);
    await Supabase.instance.client
        .from('expense_transactions')
        .delete()
        .lt('created_at', cutoff.toUtc().toIso8601String());
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

    Map<int, int> daysInMonthSales = {};
    Map<int, double> monthsInYearSales = {};
    Map<int, int> daysOfWeekSales = {};
    
    // Initialize maps
    for (int i = 1; i <= 31; i++) {
      daysInMonthSales[i] = 0;
    }
    for (int i = 1; i <= 12; i++) {
      monthsInYearSales[i] = 0.0;
    }
    for (int i = 1; i <= 7; i++) {
      daysOfWeekSales[i] = 0;
    }

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
        monthsInYearSales[createdAt.month] = (monthsInYearSales[createdAt.month] ?? 0) + amount;
      }
      
      // All time Day of Week
      daysOfWeekSales[createdAt.weekday] = (daysOfWeekSales[createdAt.weekday] ?? 0) + 1;
    }

    _monthlyRevenue = currentMonthRevenue;
    _monthlyOrders = currentMonthOrders;
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
              primary: AppTheme.primary, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: AppTheme.primary, // body text color
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
    final localeName = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.t('analyticsTitle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        centerTitle: true,
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : RefreshIndicator(
            onRefresh: _fetchData,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthOverview(),
                  const SizedBox(height: 16),
                  _buildDateSearch(),
                  const SizedBox(height: 28),
                  
                  _buildSectionTitle(context.t('dailyOrdersThisMonth')),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildMonthlyDaysChart(), 
                    context.t('ordersByDayFor', args: {'period': DateFormat('MMMM yyyy', localeName).format(DateTime.now())}),
                    _touchedMonthlyIndex,
                    context.t('dayNumber', args: {'day': _touchedMonthlyIndex + 1}),
                    '${_daysInMonthSales[_touchedMonthlyIndex + 1] ?? 0} ${context.t('orders')}',
                    scrollableWidth: 1200, // Even larger width for all 31 thick bars and labels
                    controller: _monthlyScrollController,
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle(context.t('yearlyTrendThisYear')),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildYearlyTrendChart(), 
                    context.t('totalRevenueTrend', args: {'year': DateTime.now().year}),
                    _touchedYearlyIndex,
                    DateFormat('MMMM', localeName).format(DateTime(2024, _touchedYearlyIndex == -1 ? 1 : _touchedYearlyIndex + 1)),
                    "₹${_monthsInYearSales[_touchedYearlyIndex + 1]?.toStringAsFixed(0) ?? '0'}",
                    scrollableWidth: 600, // Space for full Jan, Feb labels
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle(context.t('ordersByWeekday')),
                  const SizedBox(height: 16),
                  _buildBarChartContainer(
                    _buildWeeklyDaysChart(),
                    context.t('busiestDays'),
                    _touchedWeeklyIndex,
                    DateFormat.E(Localizations.localeOf(context).toLanguageTag()).format(DateTime(2024, 1, (_touchedWeeklyIndex == -1 ? 0 : _touchedWeeklyIndex) + 1)),
                    '${_daysOfWeekSales[_touchedWeeklyIndex + 1] ?? 0} ${context.t('orders')}'
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
    );
  }

  Widget _buildMonthOverview() {
    final monthName = DateFormat('MMMM', Localizations.localeOf(context).toLanguageTag()).format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('monthOverview', args: {'month': monthName}),
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          context.t('analyticsWindow'),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOverviewMetric(
                context.t('totalEarned'),
                "₹${_monthlyRevenue.toInt()}",
                context.t('monthTracker', args: {'month': monthName}),
                Icons.payments_outlined,
                AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewMetric(
                context.t('ordersThisMonth'),
                _monthlyOrders.toString(),
                context.t('totalOrders', args: {'count': _monthlyOrders}),
                Icons.shopping_bag_outlined,
                AppTheme.primaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewMetric(String label, String value, String caption, IconData icon, Color accent) {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.t('searchByDate'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
                      onPressed: _searchedDate == null ? null : () {
                        final newDate = _searchedDate!.subtract(const Duration(days: 1));
                        setState(() => _searchedDate = newDate);
                        _calculateSearchedDate(newDate);
                      },
                    ),
                    TextButton(
                      onPressed: _pickDate,
                      child: Text(
                        _searchedDate == null ? context.t('selectDate') : DateFormat('EEE, d MMM', Localizations.localeOf(context).toLanguageTag()).format(_searchedDate!),
                        maxLines: 1,
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
                      onPressed: _searchedDate == null ? null : () {
                        final newDate = _searchedDate!.add(const Duration(days: 1));
                        if (newDate.isAfter(DateTime.now())) return;
                        setState(() => _searchedDate = newDate);
                        _calculateSearchedDate(newDate);
                      },
                    ),
                  ],
                ),
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
                _buildSearchStat(context.t('orders'), _searchedDateOrders.toString(), Icons.shopping_bag_outlined),
                Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
                _buildSearchStat(context.t('revenue'), "₹${_searchedDateRevenue.toInt()}", Icons.currency_rupee),
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
              Icon(icon, size: 16, color: AppTheme.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.primary.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primary)),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: AppTheme.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
          ),
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: AppTheme.primary.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween<double>(begin: 0, end: double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0),
                    curve: Curves.easeOutCirc,
                    builder: (context, val, child) {
                      final prefix = value.contains('₹') ? '₹' : '';
                      final suffix = value.contains('₹') ? '' : ' ${context.t('orders')}';
                      return Text(
                        "$prefix${val.toStringAsFixed(0)}$suffix", 
                        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: -1)
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
            SizedBox(height: 240, child: chart),
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
                    style: GoogleFonts.inter(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)
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
                  style: GoogleFonts.inter(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500)
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
            return FlLine(color: AppTheme.primary.withValues(alpha: 0.06), strokeWidth: 1);
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
                style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.35), fontSize: 10, fontWeight: FontWeight.bold),
                labelResolver: (_) => context.t('avg'),
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
                color: isTouched ? AppTheme.primary : AppTheme.primaryLight.withValues(alpha: 0.45),
                width: isTouched ? 32 : 28,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.primary.withValues(alpha: 0.04),
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

    final localeName = Localizations.localeOf(context).toLanguageTag();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (barTouchResponse != null && barTouchResponse.spot != null) {
              setState(() => _touchedYearlyIndex = barTouchResponse.spot!.touchedBarGroupIndex);
            }
          },
          enabled: true,
          handleBuiltInTouches: false,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt() - 1;
                if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                final monthName = DateFormat('MMM', localeName).format(DateTime(DateTime.now().year, idx + 1));
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(monthName, style: GoogleFonts.inter(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold)),
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
                return Text("₹${value.toInt()}", style: GoogleFonts.inter(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w500));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.primary.withValues(alpha: 0.06), strokeWidth: 1),
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
                color: isTouched ? AppTheme.primary : AppTheme.primaryLight.withValues(alpha: 0.55),
                width: isTouched ? 30 : 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.primary.withValues(alpha: 0.04),
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
                    style: GoogleFonts.inter(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold)
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
                  style: GoogleFonts.inter(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)
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
            return FlLine(color: AppTheme.primary.withValues(alpha: 0.06), strokeWidth: 1);
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
                style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.35), fontSize: 10, fontWeight: FontWeight.bold),
                labelResolver: (_) => context.t('avg'),
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
                color: isTouched ? AppTheme.primary : AppTheme.primaryLight.withValues(alpha: 0.45),
                width: isTouched ? 28 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.primary.withValues(alpha: 0.04),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

