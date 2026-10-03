import 'package:flutter/material.dart';

class VoucherDialog extends StatefulWidget {
  final Map<String, dynamic> data;

  const VoucherDialog({super.key, required this.data});

  @override
  State<VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<VoucherDialog> {
  bool isFarmerSlip = true;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final String date = d['date'] ?? 'N/A';
    final String farmerName = d['farmer_name'] ?? 'N/A';
    final String buyerName = d['buyer_name'] ?? 'N/A';
    final String cropName = d['crop_name'] ?? 'N/A';
    final double qtyKg = (d['quantity_kg'] ?? d['final_weight'] ?? 0.0).toDouble();
    final double mann = qtyKg / 40.0;
    final double saleRate = (d['sale_rate_per_kg'] ?? 0.0).toDouble();
    final double totalGross = (d['total_sale_amount'] ?? d['gross_sale_amount'] ?? 0.0).toDouble();

    // Buyer
    final double buyerComm = (d['buyer_commission_amount'] ?? 0.0).toDouble();
    final double buyerTotal = (d['buyer_total_amount'] ?? totalGross).toDouble();

    // Farmer
    final double farmerComm = (d['farmer_commission_amount'] ?? d['commission_deducted'] ?? 0.0).toDouble();
    final double mazdoori = (d['mazdoori_amount'] ?? d['mazdoori_deducted'] ?? 0.0).toDouble();
    final double brokery = (d['brokery_amount'] ?? d['brokery_deducted'] ?? 0.0).toDouble();
    final double shop = (d['shop_charges_amount'] ?? d['shop_charges_deducted'] ?? 0.0).toDouble();
    final double expenses = (d['approved_expenses'] ?? d['expenses_deducted'] ?? 0.0).toDouble();
    final double netFarmerPayable = (d['net_farmer_payable'] ?? (totalGross - farmerComm - mazdoori - brokery - shop - expenses)).toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Switch Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFarmerSlip ? const Color(0xFF0F5132) : Colors.grey.shade300,
                      foregroundColor: isFarmerSlip ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => setState(() => isFarmerSlip = true),
                    child: const Text('Kisan Parchi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isFarmerSlip ? Colors.blue.shade800 : Colors.grey.shade300,
                      foregroundColor: !isFarmerSlip ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => setState(() => isFarmerSlip = false),
                    child: const Text('Buyer Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Slip Body
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isFarmerSlip ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isFarmerSlip ? Colors.green.shade300 : Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      isFarmerSlip ? '🌾 KISAN SETTLEMENT PARCHI' : '🛒 BUYER CROP INVOICE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isFarmerSlip ? const Color(0xFF0F5132) : Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  Text('Date: $date', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    isFarmerSlip ? 'Kisan: $farmerName' : 'Buyer: $buyerName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text('Crop: $cropName ($qtyKg KG / ${mann.toStringAsFixed(2)} Mann)', style: const TextStyle(fontSize: 12)),
                  const Divider(height: 16),

                  if (isFarmerSlip) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Crop Sale:', style: TextStyle(fontSize: 12)),
                        Text('Rs. ${totalGross.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('(-) Commission:', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text('- Rs. ${farmerComm.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('(-) 1. Mazdoori / Palledari:', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text('- Rs. ${mazdoori.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('(-) 2. Brokery / Dalali:', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text('- Rs. ${brokery.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('(-) 3. Shop Charges:', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text('- Rs. ${shop.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    if (expenses > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('(-) Expenses:', style: TextStyle(fontSize: 12, color: Colors.red)),
                          Text('- Rs. ${expenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('👉 Kisan Net Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Rs. ${netFarmerPayable.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132), fontSize: 15)),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Crop Purchase Amount:', style: TextStyle(fontSize: 12)),
                        Text('Rs. ${totalGross.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    if (buyerComm > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('(+) Buyer Commission:', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          Text('+ Rs. ${buyerComm.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('👉 Buyer Total Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Rs. ${buyerTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 15)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share / Print', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Parchi copy ho gayi! Aap WhatsApp ya Bluetooth Printer par print kar saktay hain.')),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
