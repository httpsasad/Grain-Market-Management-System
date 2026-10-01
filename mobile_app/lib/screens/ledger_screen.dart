import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLedger();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.partyName} - کھاتہ'),
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
                      ? const Center(child: Text('Is khata me abhi koi transaction nahi hai.'))
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
                                            const Text('Debit (لینا)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              debit > 0 ? 'Rs. ${formatter.format(debit)}' : '-',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: debit > 0 ? Colors.green.shade700 : Colors.black45),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Text('Credit (دینا)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              credit > 0 ? 'Rs. ${formatter.format(credit)}' : '-',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: credit > 0 ? Colors.red.shade700 : Colors.black45),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Running Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
