import 'package:flutter/material.dart';
import '../../../core/services/pdf_service.dart';
import '../models/payment.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final Payment payment;
  const PaymentDetailsScreen({super.key, required this.payment});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isGenerating = false;

  late String _tenantName;
  late String _propertyAddress;
  late double _rentAmount;
  late double _chargesAmount;
  late double _totalAmount;
  late String _month;
  late String _paymentDate;
  late String _paymentMethod;
  late String _reference;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _tenantName = p.tenantName;
    _propertyAddress = p.lotName;
    _rentAmount = p.amount;
    _chargesAmount = 0.0;
    _totalAmount = p.amount;
    _month = _formatMonth(p.dueDate);
    _paymentDate = p.paymentDate != null ? _formatDate(p.paymentDate!) : _formatDate(DateTime.now());
    _paymentMethod = 'Virement';
    _reference = p.id;
  }

  String _formatMonth(DateTime date) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du paiement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(initialValue: _tenantName, decoration: const InputDecoration(labelText: 'Locataire'), onChanged: (v) => _tenantName = v),
              TextFormField(initialValue: _propertyAddress, decoration: const InputDecoration(labelText: 'Adresse du bien'), onChanged: (v) => _propertyAddress = v),
              TextFormField(initialValue: _rentAmount.toString(), decoration: const InputDecoration(labelText: 'Loyer (€)'), keyboardType: TextInputType.number, onChanged: (v) => _rentAmount = double.tryParse(v) ?? 0),
              TextFormField(initialValue: _chargesAmount.toString(), decoration: const InputDecoration(labelText: 'Charges (€)'), keyboardType: TextInputType.number, onChanged: (v) => _chargesAmount = double.tryParse(v) ?? 0),
              TextFormField(initialValue: _totalAmount.toString(), decoration: const InputDecoration(labelText: 'Total (€)'), keyboardType: TextInputType.number, onChanged: (v) => _totalAmount = double.tryParse(v) ?? 0),
              TextFormField(initialValue: _month, decoration: const InputDecoration(labelText: 'Mois'), onChanged: (v) => _month = v),
              TextFormField(initialValue: _paymentDate, decoration: const InputDecoration(labelText: 'Date de paiement'), onChanged: (v) => _paymentDate = v),
              TextFormField(initialValue: _paymentMethod, decoration: const InputDecoration(labelText: 'Mode de paiement'), onChanged: (v) => _paymentMethod = v),
              TextFormField(initialValue: _reference, decoration: const InputDecoration(labelText: 'Référence'), onChanged: (v) => _reference = v),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateAndShare,
                child: _isGenerating ? const CircularProgressIndicator() : const Text('Générer et partager le PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndShare() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);
    try {
      final file = await PdfService.generateAndSave(
        tenantName: _tenantName,
        propertyAddress: _propertyAddress,
        rentAmount: _rentAmount,
        chargesAmount: _chargesAmount,
        totalAmount: _totalAmount,
        month: _month,
        paymentDate: _paymentDate,
        paymentMethod: _paymentMethod,
        reference: _reference,
      );
      if (file != null) {
        final shouldShare = await showDialog<bool>(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF généré'),
            content: const Text('Voulez-vous partager ce PDF ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ouvrir')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Partager')),
            ],
          ),
        );
        if (shouldShare == true) {
          await PdfService.sharePDF(file);
        } else {
          await PdfService.openPDF(file);
        }
      } else {
        if (mounted)_showSnackBar('Erreur lors de la génération du PDF');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Une erreur est survenue : $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}