class Tenant {
  final String id;
  final String fullName;
  final String? buildingId;
  final String? lotId;
  final DateTime startDate;
  final String? email;
  final String? phone;

  Tenant({
    required this.id,
    required this.fullName,
    this.buildingId,
    this.lotId,
    required this.startDate,
    this.email,
    this.phone,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'],
      fullName: json['fullName'],
      buildingId: json['buildingId'],
      lotId: json['lotId'],
      startDate: DateTime.parse(json['startDate']),
      email: json['email'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'buildingId': buildingId,
      'lotId': lotId,
      'startDate': startDate.toIso8601String(),
      'email': email,
      'phone': phone,
    };
  }
}