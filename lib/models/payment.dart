class Payment {
  final String id;
  final String tenantId;
  final String tenantName;
  final String buildingId;
  final String lotId;
  final String lotName;
  final double amount;
  final DateTime dueDate;
  final DateTime? paymentDate;
  final String status;

  Payment({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.buildingId,
    required this.lotId,
    required this.lotName,
    required this.amount,
    required this.dueDate,
    this.paymentDate,
    required this.status,
  });

  String get formattedAmount => '${amount.toStringAsFixed(2)} €';
  String get formattedDueDate => '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  bool get isLate => dueDate.isBefore(DateTime.now()) && status == 'pending';

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      tenantId: json['tenantId'],
      tenantName: json['tenantName'],
      buildingId: json['buildingId'],
      lotId: json['lotId'],
      lotName: json['lotName'],
      amount: json['amount'].toDouble(),
      dueDate: DateTime.parse(json['dueDate']),
      paymentDate: json['paymentDate'] != null ? DateTime.parse(json['paymentDate']) : null,
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'buildingId': buildingId,
      'lotId': lotId,
      'lotName': lotName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paymentDate': paymentDate?.toIso8601String(),
      'status': status,
    };
  }
}