import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/pref_keys.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../core/services/pdf_service.dart';
import '../../tenants/models/tenant.dart';
import '../../buildings/models/property.dart';
import '../models/payment.dart';
import 'payment_details.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Tenant> _tenants = [];
  List<Payment> _payments = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? tenantsJson = prefs.getString(PrefKeys.tenants);
    if (tenantsJson != null && tenantsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(tenantsJson);
      setState(() {
        _tenants = decoded.map((e) => Tenant.fromJson(e)).toList();
      });
    }

    final String? paymentsJson = prefs.getString(PrefKeys.payments);
    if (paymentsJson != null && paymentsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(paymentsJson);
      setState(() {
        _payments = decoded.map((e) => Payment.fromJson(e)).toList();
      });
    } else {
      _generateInitialPayments();
    }
  }

  Future<void> _generateInitialPayments() async {
    final now = DateTime.now();
    final payments = <Payment>[];

    for (var tenant in _tenants) {
      final lotRent = await _getLotRent(tenant.buildingId, tenant.lotId);
      for (int i = 0; i < 3; i++) {
        final dueDate = DateTime(now.year, now.month + i, 5);
        payments.add(Payment(
          id: '${tenant.id}_${dueDate.year}_${dueDate.month}',
          tenantId: tenant.id,
          tenantName: tenant.fullName,
          buildingId: tenant.buildingId ?? '',
          lotId: tenant.lotId ?? '',
          lotName: 'Lot ${tenant.lotId}',
          amount: lotRent,
          dueDate: dueDate,
          status: 'pending',
        ));
      }
    }

    setState(() {
      _payments = payments;
    });
    await _savePayments();
  }

  Future<double> _getLotRent(String? buildingId, String? lotId) async {
    if (buildingId == null || lotId == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    final String? buildingsJson = prefs.getString(PrefKeys.buildings);
    if (buildingsJson != null && buildingsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(buildingsJson);
      final buildings = decoded.map((e) => Immeuble.fromJson(e)).toList();
      final building = buildings.firstWhere(
        (b) => b.id == buildingId,
        orElse: () => Immeuble(id: '', name: '', address: '', lots: []),
      );
      final lot = building.lots.firstWhere(
        (l) => l.id == lotId,
        orElse: () => Lot(id: '', name: '', type: '', area: 0, rent: 0, rooms: 0, status: '', floor: ''),
      );
      return lot.rent;
    }
    return 0;
  }

  Future<void> _savePayments() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_payments.map((e) => e.toJson()).toList());
    await prefs.setString(PrefKeys.payments, jsonString);
  }

  List<Payment> get _pendingPayments => _payments.where((p) => p.status == 'pending').toList();
  List<Payment> get _paidPayments => _payments.where((p) => p.status == 'paid').toList();

  double get _totalPending => _pendingPayments.fold(0, (sum, p) => sum + p.amount);
  double get _totalPaid => _paidPayments.fold(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Paiements',
          style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _buildSummaryCards(),
        ),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _selectedIndex == 0 ? _buildPendingList() : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              title: 'À encaisser',
              amount: _totalPending,
              color: Colors.orange,
              icon: Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              title: 'Encaissé',
              amount: _totalPaid,
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Échéances',
              index: 0,
              count: _pendingPayments.length,
              isActive: _selectedIndex == 0,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'Historique',
              index: 1,
              count: _paidPayments.length,
              isActive: _selectedIndex == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int index,
    required int count,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E88E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.white : Colors.grey,
              ),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.urbanist(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF1E88E5) : Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text('Tous les loyers sont à jour !', style: GoogleFonts.urbanist(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingPayments.length,
      itemBuilder: (context, index) => _buildPaymentCard(_pendingPayments[index]),
    );
  }

  Widget _buildHistoryList() {
    if (_paidPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Aucun historique', style: GoogleFonts.urbanist(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paidPayments.length,
      itemBuilder: (context, index) => _buildPaymentCard(_paidPayments[index], isHistory: true),
    );
  }

  Widget _buildPaymentCard(Payment payment, {bool isHistory = false}) {
    final isLate = payment.isLate && !isHistory;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PaymentDetailsScreen(payment: payment)),
            );
            if (result == true) _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: (isHistory ? Colors.green : (isLate ? Colors.red : Colors.orange)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isHistory ? Icons.receipt : (isLate ? Icons.warning : Icons.pending),
                    color: isHistory ? Colors.green : (isLate ? Colors.red : Colors.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment.tenantName, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(payment.lotName, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(payment.formattedAmount, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: isHistory ? Colors.green : Colors.orange)),
                          const SizedBox(width: 12),
                          Text(payment.formattedDueDate, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey)),
                          if (isLate && !isHistory)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('En retard', style: GoogleFonts.urbanist(fontSize: 10, color: Colors.red)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isHistory)
                  ElevatedButton(
                    onPressed: () => _validatePayment(payment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Valider'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validatePayment(Payment payment) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Valider le paiement', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Locataire : ${payment.tenantName}'),
            const SizedBox(height: 8),
            Text('Montant : ${payment.formattedAmount}'),
            const SizedBox(height: 8),
            Text('Période : ${payment.formattedDueDate}'),
            const SizedBox(height: 16),
            Text('Souhaitez-vous générer une quittance ?', style: GoogleFonts.urbanist(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmPayment(payment, generateReceipt: false);
            },
            child: const Text('Valider sans quittance'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmPayment(payment, generateReceipt: true);

            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Valider et quittance'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(Payment payment, {required bool generateReceipt}) async {
    final updatedPayment = Payment(
      id: payment.id,
      tenantId: payment.tenantId,
      tenantName: payment.tenantName,
      buildingId: payment.buildingId,
      lotId: payment.lotId,
      lotName: payment.lotName,
      amount: payment.amount,
      dueDate: payment.dueDate,
      paymentDate: DateTime.now(),
      status: 'paid',
    );

    final index = _payments.indexWhere((p) => p.id == payment.id);
    setState(() => _payments[index] = updatedPayment);
    await _savePayments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paiement validé pour ${_formatMonth(payment.dueDate)}'), backgroundColor: Colors.green),
      );
    }

    if (generateReceipt) _generateAndShareReceipt(updatedPayment);
  }

  Future<void> _generateAndShareReceipt(Payment payment) async {
    try {
      final file = await PdfService.generateAndSave(
        tenantName: payment.tenantName,
        propertyAddress: payment.lotName,
        rentAmount: payment.amount,
        chargesAmount: 0.0,
        totalAmount: payment.amount,
        month: _formatMonth(payment.dueDate),
        paymentDate: _formatDate(payment.paymentDate ?? DateTime.now()),
        paymentMethod: 'Virement',
        reference: payment.id,
      );

      if (file != null) {
        if (!mounted) return; // ensure widget is still mounted
        final shouldShare = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quittance générée'),
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
        if (mounted) _showSnackBar('Erreur lors de la génération du PDF');

      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur : $e');
    }
  }

  String _formatMonth(DateTime date) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  
  void _showSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  }
}