import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReceivingScreen extends StatefulWidget {
  const ReceivingScreen({super.key});

  @override
  State<ReceivingScreen> createState() => _ReceivingScreenState();
}

class _ReceivingScreenState extends State<ReceivingScreen> {
  bool isLoading = true;
  List<dynamic> receivings = [];
  List<dynamic> farmers = [];
  List<dynamic> crops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final recs = await ApiService.getReceivings();
      final fList = await ApiService.getParties(partyType: 'Farmer');
      final cList = await ApiService.getCrops();
      if (mounted) {
        setState(() {
          receivings = recs;
          farmers = fList;
          crops = cList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddReceivingModal() {
    if (farmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle "Parties" tab se kam az kam ek Farmer add karein!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? farmerId = farmers[0]['id'];
    int? cropId = crops.isNotEmpty ? crops[0]['id'] : null;

    final bagsCtrl = TextEditingController(text: '100');
    final grossCtrl = TextEditingController(text: '4000');
    final tareCtrl = TextEditingController(text: '100');
    final moistureCtrl = TextEditingController(text: '0');
    final deductionCtrl = TextEditingController(text: '0');
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
                const Text('Fasal Aamad Entry (آمد درج کریں)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: farmerId,
                  decoration: const InputDecoration(labelText: 'Select Farmer (کسان)'),
                  items: farmers.map((f) {
                    return DropdownMenuItem<int>(
                      value: f['id'],
                      child: Text(f['name']),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => farmerId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: cropId,
                  decoration: const InputDecoration(labelText: 'Select Crop (جنس)'),
                  items: crops.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(c['name']),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => cropId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bagsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bags (بوریاں)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: grossCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Gross Wt KG (کل وزن)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tareCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tare Wt KG (کاٹ)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: deductionCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Katt Deduction KG'),
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
                      if (farmerId == null || cropId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Farmer aur Crop select karein.')),
                        );
                        return;
                      }

                      final grossVal = double.tryParse(grossCtrl.text) ?? 0.0;
                      if (grossVal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Gross Weight (وزن) enter karein.')),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final res = await ApiService.createReceiving({
                        'farmer_id': farmerId,
                        'crop_id': cropId,
                        'bags': int.tryParse(bagsCtrl.text) ?? 0,
                        'gross_weight': grossVal,
                        'tare_weight': double.tryParse(tareCtrl.text) ?? 0.0,
                        'moisture_percent': double.tryParse(moistureCtrl.text) ?? 0.0,
                        'deduction_kg': double.tryParse(deductionCtrl.text) ?? 0.0,
                      });
                      setModalState(() => isSaving = false);

                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fasal Aamad successfully darj ho gayi!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['error'] ?? 'Fasal Aamad darj nahi ho saki.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Aamad (آمد محفوظ کریں)'),
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
        onPressed: _showAddReceivingModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : receivings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grass, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Koi fasal aamad record nahi mila.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nayi fasal aamad darj karne ke liye niche + button par click karein.',
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
                    itemCount: receivings.length,
                    itemBuilder: (ctx, i) {
                      final r = receivings[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF0F5132),
                            child: Icon(Icons.grass, color: Colors.white),
                          ),
                          title: Text('${r['farmer_name']} - ${r['crop_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Receipt: ${r['receipt_no']} • Bags: ${r['bags']} • Net: ${r['final_weight']} KG'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: r['status'] == 'Settled' ? Colors.green.shade100 : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['status'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: r['status'] == 'Settled' ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
