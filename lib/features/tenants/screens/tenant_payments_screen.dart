import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/pref_keys.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/summary_card.dart';
import '../../buildings/models/property.dart';
import '../models/tenant.dart';
import '../../payments/models/payment.dart';

class TenantPaymentsScreen extends StatefulWidget {
  final Tenant tenant;
  const TenantPaymentsScreen({super.key, required this.tenant});

  @override
  State<TenantPaymentsScreen> createState() => _TenantPaymentsScreenState();
}

class _TenantPaymentsScreenState extends State<TenantPaymentsScreen> {
  List<Payment> _payments = [];
  double _monthlyRent = 0;
  bool _isLoading = true;
  String? _lotName;
  String? _propertyAddress;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _getTenantInfo();
    await _loadPayments();
    setState(() => _isLoading = false);
  }

  Future<void> _getTenantInfo() async {
    if (widget.tenant.buildingId == null || widget.tenant.lotId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String? buildingsJson = prefs.getString(PrefKeys.buildings);
    if (buildingsJson != null && buildingsJson.isNotEmpty) {
      final buildings = (jsonDecode(buildingsJson) as List)
          .map((e) => Immeuble.fromJson(e))
          .toList();
      final building = buildings.firstWhere(
        (b) => b.id == widget.tenant.buildingId,
        orElse: () => Immeuble(id: '', name: '', address: '', lots: []),
      );
      _propertyAddress = building.address;
      final lot = building.lots.firstWhere(
        (l) => l.id == widget.tenant.lotId,
        orElse: () => Lot(
          id: '',
          name: '',
          type: '',
          area: 0,
          rent: 0,
          rooms: 0,
          status: '',
          floor: '',
        ),
      );
      _monthlyRent = lot.rent;
      _lotName = lot.name;
    }
  }

  Future<void> _loadPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? paymentsJson = prefs.getString(PrefKeys.payments);
    List<Payment> existing = [];
    if (paymentsJson != null && paymentsJson.isNotEmpty) {
      existing = (jsonDecode(paymentsJson) as List)
          .map((e) => Payment.fromJson(e))
          .toList();
      existing = existing.where((p) => p.tenantId == widget.tenant.id).toList();
    }
    final now = DateTime.now();
    final startDate = widget.tenant.startDate;
    final payments = <Payment>[];
    DateTime current = DateTime(startDate.year, startDate.month, 5);
    while (current.isBefore(DateTime(now.year, now.month + 12, 5))) {
      final existingPayment = existing.firstWhere(
        (p) =>
            p.dueDate.year == current.year && p.dueDate.month == current.month,
        orElse: () => Payment(
          id: '',
          tenantId: widget.tenant.id,
          tenantName: widget.tenant.fullName,
          buildingId: widget.tenant.buildingId ?? '',
          lotId: widget.tenant.lotId ?? '',
          lotName: _lotName ?? 'Lot ${widget.tenant.lotId}',
          amount: _monthlyRent,
          dueDate: current,
          status: 'pending',
        ),
      );
      payments.add(
        Payment(
          id: existingPayment.id.isNotEmpty
              ? existingPayment.id
              : '${widget.tenant.id}_${current.year}_${current.month}',
          tenantId: widget.tenant.id,
          tenantName: widget.tenant.fullName,
          buildingId: widget.tenant.buildingId ?? '',
          lotId: widget.tenant.lotId ?? '',
          lotName: _lotName ?? 'Lot ${widget.tenant.lotId}',
          amount: _monthlyRent,
          dueDate: current,
          paymentDate: existingPayment.paymentDate,
          status: existingPayment.status,
        ),
      );
      current = DateTime(current.year, current.month + 1, 5);
    }
    setState(() => _payments = payments);
    await _savePayments();
  }

  Future<void> _savePayments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? allJson = prefs.getString(PrefKeys.payments);
    List<Payment> all = [];
    if (allJson != null && allJson.isNotEmpty) {
      all = (jsonDecode(allJson) as List)
          .map((e) => Payment.fromJson(e))
          .toList();
    }
    all.removeWhere((p) => p.tenantId == widget.tenant.id);
    all.addAll(_payments);
    final String jsonString = jsonEncode(all.map((e) => e.toJson()).toList());
    await prefs.setString(PrefKeys.payments, jsonString);
  }

  List<Payment> get _pending =>
      _payments.where((p) => p.status == 'pending').toList();
  List<Payment> get _paid =>
      _payments.where((p) => p.status == 'paid').toList();
  double get _totalPending => _pending.fold(0, (s, p) => s + p.amount);
  double get _totalPaid => _paid.fold(0, (s, p) => s + p.amount);

  Future<void> _validatePayment(Payment payment) async {
    final now = DateTime.now();
    final isLate = payment.dueDate.isBefore(now);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Valider le paiement',
          style: GoogleFonts.urbanist(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Période : ${_formatMonth(payment.dueDate)}'),
            const SizedBox(height: 8),
            Text('Montant : ${payment.formattedAmount}'),
            const SizedBox(height: 8),
            if (isLate)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Paiement en retard',
                      style: GoogleFonts.urbanist(color: Colors.red),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Souhaitez-vous générer une quittance ?',
              style: GoogleFonts.urbanist(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
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
              _confirmPayment(payment, generateReceipt: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Valider et quittance'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(
    Payment payment, {
    required bool generateReceipt,
  }) async {
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
        SnackBar(
          content: Text(
            'Paiement validé pour ${_formatMonth(payment.dueDate)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
    if (generateReceipt) _generateAndSendReceipt(updatedPayment);
  }

  Future<File?> _generatePDF(Payment payment) async {
    try {
      final month = _formatMonth(payment.dueDate);
      final paymentDate = payment.paymentDate != null
          ? _formatDate(payment.paymentDate!)
          : _formatDate(DateTime.now());
      final file = await PdfService.generateAndSave(
        tenantName: payment.tenantName,
        propertyAddress: _propertyAddress ?? payment.lotName,
        rentAmount: payment.amount,
        chargesAmount: 0.0,
        totalAmount: payment.amount,
        month: month,
        paymentDate: paymentDate,
        paymentMethod: 'Virement',
        reference: payment.id,
      );
      return file != null && await file.exists() ? file : null;
    } catch (e) {
      _showSnackBar('Erreur de génération PDF : $e');
      return null;
    }
  }

  Future<void> _sharePDFWithAttachment(Payment payment) async {
    final file = await _generatePDF(payment);
    if (file == null) return;

    try {
      // Vérifier que le fichier existe
      if (!await file.exists()) {
        _showSnackBar('Le fichier PDF n\'existe pas');
        return;
      }

      // Sur iOS, il faut utiliser XFile avec un chemin absolu
      final xFile = XFile(file.path);

      await Share.shareXFiles(
        [xFile],
        text: 'Quittance de loyer - ${_formatMonth(payment.dueDate)}',
        subject: 'Quittance de loyer',
      );
    } catch (e) {
      debugPrint('Erreur de partage: $e');
      _showSnackBar('Erreur lors du partage: $e');
    }
  }

  void _generateAndSendReceipt(Payment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt, size: 60, color: Color(0xFF1E88E5)),
              const SizedBox(height: 16),
              Text(
                'Quittance de loyer',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Période : ${_formatMonth(payment.dueDate)}',
                style: GoogleFonts.urbanist(fontSize: 16),
              ),
              Text(
                'Montant : ${payment.formattedAmount}',
                style: GoogleFonts.urbanist(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Bouton Partager avec pièce jointe
              _buildSendButton(
                icon: Icons.share,
                label: 'Partager le PDF',
                color: Colors.blue,
                onPressed: () async {
                  Navigator.pop(context);
                  await _sharePDFWithAttachment(payment);
                },
              ),
              const SizedBox(height: 12),

              // Bouton Ouvrir PDF
              _buildSendButton(
                icon: Icons.picture_as_pdf,
                label: 'Ouvrir le PDF',
                color: Colors.green,
                onPressed: () async {
                  Navigator.pop(context);
                  final file = await _generatePDF(payment);
                  if (file != null) await PdfService.openPDF(file);
                },
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Fermer',
                  style: GoogleFonts.urbanist(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewReceipt(Payment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt, size: 60, color: Color(0xFF1E88E5)),
              const SizedBox(height: 16),
              Text(
                'Quittance de loyer',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Période : ${_formatMonth(payment.dueDate)}',
                style: GoogleFonts.urbanist(fontSize: 16),
              ),
              Text(
                'Montant : ${payment.formattedAmount}',
                style: GoogleFonts.urbanist(fontSize: 14, color: Colors.grey),
              ),
              Text(
                'Payé le : ${payment.paymentDate!.day}/${payment.paymentDate!.month}/${payment.paymentDate!.year}',
                style: GoogleFonts.urbanist(fontSize: 14, color: Colors.green),
              ),
              const SizedBox(height: 24),

              // Bouton Partager
              _buildSendButton(
                icon: Icons.share,
                label: 'Partager le PDF',
                color: Colors.blue,
                onPressed: () async {
                  Navigator.pop(context);
                  await _sharePDFWithAttachment(payment);
                },
              ),
              const SizedBox(height: 12),

              // Bouton Ouvrir PDF
              _buildSendButton(
                icon: Icons.picture_as_pdf,
                label: 'Ouvrir le PDF',
                color: Colors.green,
                onPressed: () async {
                  Navigator.pop(context);
                  final file = await _generatePDF(payment);
                  if (file != null) await PdfService.openPDF(file);
                },
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Fermer',
                  style: GoogleFonts.urbanist(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSendButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getStatusText(String status, DateTime dueDate) {
    if (status == 'paid') return 'Payé';
    if (dueDate.isBefore(DateTime.now())) return 'En retard';
    return 'En attente';
  }

  Color _getStatusColor(String status, DateTime dueDate) {
    if (status == 'paid') return Colors.green;
    if (dueDate.isBefore(DateTime.now())) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tenant.fullName,
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Historique des paiements',
              style: GoogleFonts.urbanist(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildInfoCard(),
                _buildSummaryCards(),
                const SizedBox(height: 8),
                Expanded(child: _buildPaymentsList()),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.tenant.fullName,
                  style: GoogleFonts.urbanist(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.tenant.email != null && widget.tenant.email!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.tenant.email!,
                      style: GoogleFonts.urbanist(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.tenant.phone != null && widget.tenant.phone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.tenant.phone!,
                      style: GoogleFonts.urbanist(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.apartment, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lotName ?? 'Lot non défini',
                    style: GoogleFonts.urbanist(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entrée : ${widget.tenant.startDate.day}/${widget.tenant.startDate.month}/${widget.tenant.startDate.year}',
                    style: GoogleFonts.urbanist(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loyer mensuel',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  color: const Color(0xFF1E88E5),
                ),
              ),
              Text(
                '${_monthlyRent.toStringAsFixed(2)} €',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              title: 'À payer',
              amount: _totalPending,
              color: Colors.orange,
              icon: Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              title: 'Payé',
              amount: _totalPaid,
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final isPaid = payment.status == 'paid';
        final isLate = !isPaid && payment.dueDate.isBefore(DateTime.now());

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      payment.status,
                      payment.dueDate,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.check_circle
                        : (isLate ? Icons.warning : Icons.pending),
                    color: _getStatusColor(payment.status, payment.dueDate),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMonth(payment.dueDate),
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        payment.formattedAmount,
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (isPaid && payment.paymentDate != null)
                        Text(
                          'Payé le ${payment.paymentDate!.day}/${payment.paymentDate!.month}/${payment.paymentDate!.year}',
                          style: GoogleFonts.urbanist(
                            fontSize: 10,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      payment.status,
                      payment.dueDate,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(payment.status, payment.dueDate),
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(payment.status, payment.dueDate),
                    ),
                  ),
                ),
                if (isPaid)
                  IconButton(
                    icon: const Icon(Icons.receipt, color: Color(0xFF1E88E5)),
                    onPressed: () => _viewReceipt(payment),
                    tooltip: 'Voir la quittance',
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.payment, color: Colors.green),
                    onPressed: () => _validatePayment(payment),
                    tooltip: 'Valider le paiement',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
