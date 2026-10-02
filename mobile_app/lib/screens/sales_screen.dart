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

  void _showQuickAddBuyerDialog(Function(int newBuyerId) onBuyerCreated) {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Buyer / Mill Add Karein (نیا خریدار)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Buyer / Mill Name (نام)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile No (موبائل)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final res = await ApiService.createParty({
                'name': nameCtrl.text.trim(),
                'mobile': mobileCtrl.text.trim(),
                'party_type': 'Buyer',
                'opening_balance': 0.0,
                'balance_type': 'Receivable',
              });
              if (res['success']) {
                Navigator.pop(ctx);
                final bList = await ApiService.getParties(partyType: 'Buyer');
                setState(() => buyers = bList);
                onBuyerCreated(res['data']['party_id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Naya Buyer kamyabi se add ho gaya!')),
                );
              }
            },
            child: const Text('Save Buyer'),
          ),
        ],
      ),
    );
  }

  void _showProcessSaleModal(Map<String, dynamic> rec) {
    int? buyerId = buyers.isNotEmpty ? buyers[0]['id'] : null;
    
    // Default Gandum Rate e.g. 4000 Rs/Mann
    final rateCtrl = TextEditingController(text: '4000');
    String rateUnit = 'per_mann'; // 'per_mann' (40KG) or 'per_kg'

    final commRateCtrl = TextEditingController(text: '2.0');
    String commType = 'percentage';

    final mazdooriRateCtrl = TextEditingController(text: '1.0');
    String mazdooriType = 'percentage'; // 'percentage' or 'per_bag' or 'fixed'

    final expensesCtrl = TextEditingController(text: '0');
    final advanceCtrl = TextEditingController(text: '0');
    final quantityCtrl = TextEditingController(text: rec['final_weight'].toString());
    
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final qtyKg = double.tryParse(quantityCtrl.text) ?? (rec['final_weight'] ?? 0.0);
          final enteredRate = double.tryParse(rateCtrl.text) ?? 0.0;
          final ratePerKg = rateUnit == 'per_mann' ? (enteredRate / 40.0) : enteredRate;
          final totalGrossSale = qtyKg * ratePerKg;

          final commRateVal = double.tryParse(commRateCtrl.text) ?? 0.0;
          double commAmt = 0.0;
          if (commType == 'percentage') {
            commAmt = (totalGrossSale * commRateVal) / 100.0;
          } else if (commType == 'per_kg') {
            commAmt = qtyKg * commRateVal;
          } else {
            commAmt = commRateVal;
          }

          final mazdooriRateVal = double.tryParse(mazdooriRateCtrl.text) ?? 0.0;
          double mazdooriAmt = 0.0;
          if (mazdooriType == 'percentage') {
            mazdooriAmt = (totalGrossSale * mazdooriRateVal) / 100.0;
          } else if (mazdooriType == 'per_bag') {
            final bagsCount = rec['bags'] > 0 ? rec['bags'] : (qtyKg / 40.0);
            mazdooriAmt = bagsCount * mazdooriRateVal;
          } else {
            mazdooriAmt = mazdooriRateVal;
          }

          final expAmt = double.tryParse(expensesCtrl.text) ?? 0.0;
          final netFarmerPayable = max(0.0, totalGrossSale - commAmt - mazdooriAmt - expAmt);

          return Padding(
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
                  Text('Bikri & Settlement (${rec['receipt_no']})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Farmer: ${rec['farmer_name']} • Crop: ${rec['crop_name']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 16),
                  
                  // Buyer Selection with Quick Add Button
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: buyerId,
                          decoration: const InputDecoration(labelText: 'Select Buyer (خریدار / مل)'),
                          items: buyers.map((b) => DropdownMenuItem<int>(value: b['id'], child: Text(b['name']))).toList(),
                          onChanged: (v) => setModalState(() => buyerId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Color(0xFF0F5132)),
                        tooltip: 'Add New Buyer',
                        onPressed: () {
                          _showQuickAddBuyerDialog((newId) {
                            setModalState(() => buyerId = newId);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Quantity and Rate
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Quantity KG (وزن)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: rateCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            labelText: rateUnit == 'per_mann' ? 'Rate Rs/Mann (ریٹ)' : 'Rate Rs/KG (ریٹ)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Rate Unit Toggle
                  Row(
                    children: [
                      const Text('Rate Unit: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ChoiceChip(
                        label: const Text('Rs / Mann (40 KG)', style: TextStyle(fontSize: 11)),
                        selected: rateUnit == 'per_mann',
                        onSelected: (sel) {
                          if (sel) setModalState(() => rateUnit = 'per_mann');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Rs / KG', style: TextStyle(fontSize: 11)),
                        selected: rateUnit == 'per_kg',
                        onSelected: (sel) {
                          if (sel) setModalState(() => rateUnit = 'per_kg');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Commission Settings
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
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Commission Rate'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mazdoori / Labour Settings
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: mazdooriType,
                          decoration: const InputDecoration(labelText: 'Mazdoori Type (مزدوری)'),
                          items: const [
                            DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                            DropdownMenuItem(value: 'per_bag', child: Text('Per Bag (بوریاں)')),
                            DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                          ],
                          onChanged: (v) => setModalState(() => mazdooriType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: mazdooriRateCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Mazdoori Rate'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Approved Expenses and Advance
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: expensesCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Approved Expenses (خراجات)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: advanceCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Advance Paid (پیشنگی)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live Calculation Summary Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📊 Calculated Settlement Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F5132))),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Sale (Gross):', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                            Text('Rs. ${formatter.format(totalGrossSale)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Commission Deduction:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                            Text('- Rs. ${formatter.format(commAmt)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mazdoori Deduction:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                            Text('- Rs. ${formatter.format(mazdooriAmt)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                          ],
                        ),
                        if (expAmt > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Expenses Deduction:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                              Text('- Rs. ${formatter.format(expAmt)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                            ],
                          ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Farmer Net Payable (صافی رقم):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Rs. ${formatter.format(netFarmerPayable)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132), fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                      onPressed: isSaving ? null : () async {
                        if (buyerId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Baraye meharbani Buyer select karein.')),
                          );
                          return;
                        }

                        if (enteredRate <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Baraye meharbani Rate enter karein.')),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);
                        final res = await ApiService.processSale({
                          'receiving_id': rec['id'],
                          'buyer_id': buyerId,
                          'sale_rate_per_kg': ratePerKg,
                          'commission_type': commType,
                          'commission_rate': commRateVal,
                          'mazdoori_type': mazdooriType,
                          'mazdoori_rate': mazdooriRateVal,
                          'approved_expenses': expAmt,
                          'advance_payment_made': double.tryParse(advanceCtrl.text) ?? 0.0,
                          'sale_quantity_kg': qtyKg,
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
          );
        },
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
