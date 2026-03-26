class Lot {
  final String id;
  final String name;
  final String type;
  final double area;
  final double rent;
  final int rooms;
  final String status;
  final String floor;
  final String? tenantId;

  Lot({
    required this.id,
    required this.name,
    required this.type,
    required this.area,
    required this.rent,
    required this.rooms,
    required this.status,
    required this.floor,
    this.tenantId,
  });

  factory Lot.fromJson(Map<String, dynamic> json) {
    return Lot(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      area: json['area'].toDouble(),
      rent: json['rent'].toDouble(),
      rooms: json['rooms'],
      status: json['status'],
      floor: json['floor'],
      tenantId: json['tenantId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'area': area,
      'rent': rent,
      'rooms': rooms,
      'status': status,
      'floor': floor,
      'tenantId': tenantId,
    };
  }
}

class Immeuble {
  final String id;
  final String name;
  final String address;
  final List<Lot> lots;

  Immeuble({
    required this.id,
    required this.name,
    required this.address,
    required this.lots,
  });

  factory Immeuble.fromJson(Map<String, dynamic> json) {
    return Immeuble(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lots: (json['lots'] as List).map((e) => Lot.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lots': lots.map((e) => e.toJson()).toList(),
    };
  }
}