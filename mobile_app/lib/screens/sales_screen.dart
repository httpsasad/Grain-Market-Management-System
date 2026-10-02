import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool isLoading = true;
  List<dynamic> pendingReceivings = [];
  List<dynamic> buyers = [];
  final formatter = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final recs = await ApiService.getReceivings();
      final bList = await ApiService.getParties(partyType: 'Buyer');
      if (mounted) {
        setState(() {
          pendingReceivings = recs.where((r) => r['status'] != 'Settled').toList();
          buyers = bList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showProcessSaleModal(Map<String, dynamic> rec) {
    if (buyers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle "Parties" tab se kam az kam ek Buyer (خریدار / مل) add karein!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? buyerId = buyers[0]['id'];
    final rateCtrl = TextEditingController(text: '250');
    final commRateCtrl = TextEditingController(text: '2.0');
    final expensesCtrl = TextEditingController(text: '0');
    final advanceCtrl = TextEditingController(text: '0');
    final quantityCtrl = TextEditingController(text: rec['final_weight'].toString());
    String commType = 'percentage';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bikri & Commission Settlement (${rec['receipt_no']})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Farmer: ${rec['farmer_name']} • Crop: ${rec['crop_name']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: buyerId,
                  decoration: const InputDecoration(labelText: 'Select Buyer (خریدار / مل)'),
                  items: buyers.map((b) => DropdownMenuItem<int>(value: b['id'], child: Text(b['name']))).toList(),
                  onChanged: (v) => setModalState(() => buyerId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity KG (وزن)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Rate Rs/KG (ریٹ)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: commType,
                        decoration: const InputDecoration(labelText: 'Commission Type'),
                        items: const [
                          DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                          DropdownMenuItem(value: 'per_kg', child: Text('Per KG Rate')),
                          DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                        ],
                        onChanged: (v) => setModalState(() => commType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: commRateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Comm Rate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expensesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Approved Expenses (خراجات)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: advanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Advance Paid (پیشنگی)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (buyerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Buyer select karein.')),
                        );
                        return;
                      }

                      final rateVal = double.tryParse(rateCtrl.text) ?? 0.0;
                      if (rateVal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Rate per KG enter karein.')),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final res = await ApiService.processSale({
                        'receiving_id': rec['id'],
                        'buyer_id': buyerId,
                        'sale_rate_per_kg': rateVal,
                        'commission_type': commType,
                        'commission_rate': double.tryParse(commRateCtrl.text) ?? 2.0,
                        'approved_expenses': double.tryParse(expensesCtrl.text) ?? 0.0,
                        'advance_payment_made': double.tryParse(advanceCtrl.text) ?? 0.0,
                        'sale_quantity_kg': double.tryParse(quantityCtrl.text),
                      });
                      setModalState(() => isSaving = false);

                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bikri & Settlement processed! Farmer & Buyer Khata update ho gaya.')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['error'] ?? 'Sale process nahi ho saka.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Process Sale & Clear Hisab (حساب فائنل کریں)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingReceivings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Koi ghair-fروخت شدہ آمد (Pending Aamad) nahi hai.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pehle "Receiving (آمد)" tab se Aamad entry karein, phir yahan se uski Bikri (Sale) processed kar saktay hain.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingReceivings.length,
                    itemBuilder: (ctx, i) {
                      final r = pendingReceivings[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r['farmer_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(r['status'], style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Crop: ${r['crop_name']} • Weight: ${r['final_weight']} KG (${r['bags']} bags)', style: TextStyle(color: Colors.grey.shade700)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                                  icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                                  label: const Text('Process Bikri (فروخت کریں)'),
                                  onPressed: () => _showProcessSaleModal(r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
