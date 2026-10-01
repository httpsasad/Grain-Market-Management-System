import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'ledger_screen.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  bool isLoading = true;
  List<dynamic> parties = [];
  String selectedType = 'All';
  final formatter = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() => isLoading = true);
    try {
      final list = await ApiService.getParties(partyType: selectedType);
      if (mounted) {
        setState(() {
          parties = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddPartyModal() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final openingBalCtrl = TextEditingController(text: '0');
    String type = 'Farmer';
    String balType = 'Receivable';

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
                const Text('Naya Account Shamil Karein (نیا کھاتہ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Party Name (نام)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  decoration: const InputDecoration(labelText: 'Mobile Number (موبائل)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Party Type (قسم)'),
                  items: const [
                    DropdownMenuItem(value: 'Farmer', child: Text('Farmer (کسان / زمیندار)')),
                    DropdownMenuItem(value: 'Buyer', child: Text('Buyer (خریدار / مل)')),
                    DropdownMenuItem(value: 'Supplier', child: Text('Supplier (سپلائر)')),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: openingBalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Opening Balance (ابتدائی رقم)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: balType,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'Receivable', child: Text('Lena Hai (وصولی)')),
                          DropdownMenuItem(value: 'Payable', child: Text('Dena Hai (ادائیگی)')),
                        ],
                        onChanged: (v) => setModalState(() => balType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final res = await ApiService.createParty({
                        'name': nameCtrl.text.trim(),
                        'mobile': mobileCtrl.text.trim(),
                        'cnic': cnicCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'party_type': type,
                        'opening_balance': double.tryParse(openingBalCtrl.text) ?? 0.0,
                        'balance_type': balType,
                      });
                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        _loadParties();
                      }
                    },
                    child: const Text('Save Account (محفوظ کریں)'),
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
        onPressed: _showAddPartyModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Farmer', 'Buyer', 'Supplier'].map((type) {
                  final isSel = selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSel,
                      selectedColor: const Color(0xFF0F5132),
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => selectedType = type);
                          _loadParties();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : parties.isEmpty
                    ? const Center(child: Text('Koi khata account nahi mila.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: parties.length,
                        itemBuilder: (ctx, i) {
                          final p = parties[i];
                          final bool isReceivable = (p['balance_status'] ?? '').contains('Lena');
                          final Color balColor = isReceivable ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0F5132).withOpacity(0.1),
                                child: Icon(
                                  p['party_type'] == 'Farmer' ? Icons.person : Icons.store,
                                  color: const Color(0xFF0F5132),
                                ),
                              ),
                              title: Text(
                                p['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                '${p['party_type']} • Mobile: ${p['mobile'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs. ${formatter.format(p['balance'])}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: balColor),
                                  ),
                                  Text(
                                    p['balance_status'],
                                    style: TextStyle(fontSize: 10, color: balColor, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => LedgerScreen(
                                      partyId: p['id'],
                                      partyName: p['name'],
                                    ),
                                  ),
                                );
                              },
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
