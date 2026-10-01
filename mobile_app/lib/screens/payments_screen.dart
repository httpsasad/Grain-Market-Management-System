import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool isLoading = true;
  List<dynamic> payments = [];
  List<dynamic> parties = [];
  final formatter = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final pList = await ApiService.getPayments();
      final partyList = await ApiService.getParties(partyType: 'All');
      if (mounted) {
        setState(() {
          payments = pList;
          parties = partyList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddPaymentModal() {
    int? partyId = parties.isNotEmpty ? parties[0]['id'] : null;
    String pmtType = 'Payment'; // Payment (Diye) vs Receipt (Vasooli)
    String pmtMode = 'Cash';
    final amountCtrl = TextEditingController(text: '');
    final notesCtrl = TextEditingController(text: '');

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
                const Text('Cash / Bank Voucher (کیش واؤچر)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: partyId,
                  decoration: const InputDecoration(labelText: 'Select Party (کھاتہ دار)'),
                  items: parties.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text('${p['name']} (${p['party_type']})'))).toList(),
                  onChanged: (v) => setModalState(() => partyId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: pmtType,
                        decoration: const InputDecoration(labelText: 'Type (قسم)'),
                        items: const [
                          DropdownMenuItem(value: 'Payment', child: Text('Payment Given (دیے)')),
                          DropdownMenuItem(value: 'Receipt', child: Text('Payment Received (وصولی)')),
                        ],
                        onChanged: (v) => setModalState(() => pmtType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: pmtMode,
                        decoration: const InputDecoration(labelText: 'Mode (طریقہ)'),
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash (نقد)')),
                          DropdownMenuItem(value: 'Bank', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                        ],
                        onChanged: (v) => setModalState(() => pmtMode = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount Rs. (رقم)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes / Remarks (تفصیل)'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (partyId == null || amountCtrl.text.isEmpty) return;
                      final res = await ApiService.createPayment({
                        'party_id': partyId,
                        'payment_type': pmtType,
                        'payment_mode': pmtMode,
                        'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                        'notes': notesCtrl.text.trim(),
                      });
                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        _loadData();
                      }
                    },
                    child: const Text('Record Payment (محفوظ کریں)'),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F5132),
        onPressed: _showAddPaymentModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : payments.isEmpty
              ? const Center(child: Text('Koi payment voucher nahi mila.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: payments.length,
                  itemBuilder: (ctx, i) {
                    final p = payments[i];
                    final bool isGiven = p['payment_type'] == 'Payment';
                    final Color color = isGiven ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.12),
                          child: Icon(
                            isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                            color: color,
                          ),
                        ),
                        title: Text(p['party_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p['voucher_no']} • ${p['payment_mode']} • ${p['date']}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${formatter.format(p['amount'])}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                            ),
                            Text(
                              isGiven ? 'Paid (دیے)' : 'Received (وصولی)',
                              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
