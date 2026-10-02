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
    if (parties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle "Parties" tab se kam az kam ek Khatadar add karein!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? partyId = parties[0]['id'];
    String pmtType = 'Payment'; // Payment (Diye) vs Receipt (Vasooli)
    String pmtMode = 'Cash';
    final amountCtrl = TextEditingController(text: '');
    final notesCtrl = TextEditingController(text: '');
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
                    onPressed: isSaving ? null : () async {
                      if (partyId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Khatadar select karein.')),
                        );
                        return;
                      }

                      final amtVal = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amtVal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani durust Amount (رقم) enter karein.')),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final res = await ApiService.createPayment({
                        'party_id': partyId,
                        'payment_type': pmtType,
                        'payment_mode': pmtMode,
                        'amount': amtVal,
                        'notes': notesCtrl.text.trim(),
                      });
                      setModalState(() => isSaving = false);

                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment Voucher successfully darj ho gaya!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['error'] ?? 'Payment record nahi ho saki.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Record Payment (محفوظ کریں)'),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Koi payment voucher nahi mila.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Naya cash ya bank voucher darj karne ke liye niche + button par click karein.',
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
                ),
    );
  }
}
