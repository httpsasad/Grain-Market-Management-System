import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'parties_screen.dart';
import 'receiving_screen.dart';
import 'sales_screen.dart';
import 'payments_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool isLoading = true;
  Map<String, dynamic> stats = {};
  final formatter = NumberFormat('#,##0.00', 'en_US');
  final langService = LanguageService();

  @override
  void initState() {
    super.initState();
    _loadStats();
    langService.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    langService.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.getDashboardStats();
      if (mounted) {
        setState(() {
          stats = res;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildKPICard(String enTitle, String urTitle, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langService.t(enTitle, urTitle),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final double todaySales = (stats['today_sales'] ?? 0.0).toDouble();
    final double todayComm = (stats['today_commission'] ?? 0.0).toDouble();
    final double totalReceivable = (stats['total_receivable'] ?? 0.0).toDouble();
    final double totalPayable = (stats['total_payable'] ?? 0.0).toDouble();
    final int pendingReceivings = (stats['pending_receivings_count'] ?? 0);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F5132), Color(0xFF166534)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.store, color: Color(0xFFD4AF37), size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langService.t('Grain Market Advanced ERP', 'گندم و جنس منڈی ایڈوانسڈ ای آر پی'),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          langService.t('Real-Time Mandi Ledger & Multi-Shop Manager', 'ریئل ٹائم منڈی کھاتہ اور ملٹی شاپ ای آر پی'),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadStats,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildKPICard('Today Total Sales', 'آج کی کل فروخت', 'Rs. ${formatter.format(todaySales)}', const Color(0xFF0F5132), Icons.trending_up),
            const SizedBox(height: 12),
            _buildKPICard('Today Commission', 'آج کا کمیشن', 'Rs. ${formatter.format(todayComm)}', const Color(0xFFD4AF37), Icons.monetization_on),
            const SizedBox(height: 12),
            _buildKPICard('Total Receivables', 'کل وصولی (لینا ہے)', 'Rs. ${formatter.format(totalReceivable)}', const Color(0xFF16A34A), Icons.call_received),
            const SizedBox(height: 12),
            _buildKPICard('Total Payables', 'کل ادائیگی (دینا ہے)', 'Rs. ${formatter.format(totalPayable)}', const Color(0xFFDC2626), Icons.call_made),
            const SizedBox(height: 12),
            _buildKPICard('Pending Receivings', 'غیر فروخت شدہ آمد', '$pendingReceivings Items', Colors.purple, Icons.inventory_2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboardTab(),
      const PartiesScreen(),
      const ReceivingScreen(),
      const SalesScreen(),
      const PaymentsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(langService.t('🌾 Grain Market ERP', '🌾 غلہ منڈی ای آر پی')),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Toggle Language (English/Urdu)',
            onPressed: () => langService.toggleLanguage(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F5132),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: langService.t('Dashboard', 'ڈیش بورڈ'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: langService.t('Parties', 'کھاتے'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.agriculture),
            label: langService.t('Receivings', 'آمد'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_cart),
            label: langService.t('Sales', 'فروخت'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: langService.t('Payments', 'ادائیگیاں'),
          ),
        ],
      ),
    );
  }
}
