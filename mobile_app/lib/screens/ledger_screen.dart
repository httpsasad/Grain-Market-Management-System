import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class LedgerScreen extends StatefulWidget {
  final int partyId;
  final String partyName;

  const LedgerScreen({super.key, required this.partyId, required this.partyName});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  bool isLoading = true;
  List<dynamic> entries = [];
  String partyType = '';
  final formatter = NumberFormat('#,##0.00', 'en_US');
  final langService = LanguageService();

  @override
  void initState() {
    super.initState();
    _loadLedger();
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

  Future<void> _loadLedger() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.getLedger(widget.partyId);
      if (mounted) {
        setState(() {
          entries = res['ledger'] ?? [];
          partyType = res['party_type'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddLedgerEntryModal() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String entryType = 'Debit'; // Debit (Lena / Paid) vs Credit (Dena / Received)

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
                Text(
                  langService.t('Add Entry to ${widget.partyName}\'s Khata', '${widget.partyName} کے کھاتے میں نیا اندراج'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: entryType,
                  decoration: InputDecoration(labelText: langService.t('Entry Type', 'اندراج کی قسم')),
                  items: [
                    DropdownMenuItem(
                      value: 'Debit',
                      child: Text(langService.t('Debit (Lena / Paid Out)', 'ڈیبٹ (ہمارا لینا / رقم دی)')),
                    ),
                    DropdownMenuItem(
                      value: 'Credit',
                      child: Text(langService.t('Credit (Dena / Received In)', 'کریڈٹ (ہمارا دینا / رقم لی)')),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => entryType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: langService.t('Amount (Rs.)', 'رقم (روپے)')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: langService.t('Description / Details', 'تفصیل / تفصیلات')),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                    onPressed: () async {
                      if (amountCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
                      final res = await ApiService.addLedgerEntry({
                        'party_id': widget.partyId,
                        'entry_type': entryType,
                        'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                        'description': descCtrl.text.trim(),
                      });
                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        _loadLedger();
                      }
                    },
                    child: Text(langService.t('Add Khata Entry', 'کھاتے میں درج کریں')),
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
      appBar: AppBar(
        title: Text('${widget.partyName} - ${langService.t("Khata Ledger", "کھاتہ")}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F5132),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          langService.t('Add Entry', 'نیا اندراج'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _showAddLedgerEntryModal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0F5132).withOpacity(0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Party Type: $partyType', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? Center(child: Text(langService.t('No transactions in this account yet.', 'اس کھاتے میں ابھی کوئی اینٹری نہیں ہے۔')))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: entries.length,
                          itemBuilder: (ctx, i) {
                            final e = entries[i];
                            final double debit = (e['debit'] ?? 0.0).toDouble();
                            final double credit = (e['credit'] ?? 0.0).toDouble();
                            final double running = (e['running_balance'] ?? 0.0).toDouble();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e['date'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(e['reference_type'] ?? 'Gen', style: const TextStyle(fontSize: 10)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(e['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(langService.t('Debit (Lena)', 'ڈیبٹ (لینا)'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              debit > 0 ? 'Rs. ${formatter.format(debit)}' : '-',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: debit > 0 ? Colors.green.shade700 : Colors.black45),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(langService.t('Credit (Dena)', 'کریڈٹ (دینا)'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              credit > 0 ? 'Rs. ${formatter.format(credit)}' : '-',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: credit > 0 ? Colors.red.shade700 : Colors.black45),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(langService.t('Running Balance', 'بقایا موازنہ'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              'Rs. ${formatter.format(running.abs())} ${running >= 0 ? "Dr" : "Cr"}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: running >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
