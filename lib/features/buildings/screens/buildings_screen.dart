import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/pref_keys.dart';
import '../models/property.dart';
import '../../tenants/models/tenant.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  List<Immeuble> _buildings = [];
  List<Tenant> _tenants = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadBuildings();
    await _loadTenants();
    setState(() => _isLoading = false);
  }

  Future<void> _loadBuildings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? buildingsJson = prefs.getString(PrefKeys.buildings);
    if (buildingsJson != null && buildingsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(buildingsJson);
      setState(() {
        _buildings = decoded.map((e) => Immeuble.fromJson(e)).toList();
      });
    }
  }

  Future<void> _loadTenants() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tenantsJson = prefs.getString(PrefKeys.tenants);
    if (tenantsJson != null && tenantsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(tenantsJson);
      setState(() {
        _tenants = decoded.map((e) => Tenant.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveBuildings() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_buildings.map((e) => e.toJson()).toList());
    await prefs.setString(PrefKeys.buildings, jsonString);
  }

  void _addBuilding() {
    if (_nameController.text.isEmpty) {
      _showSnackBar('Veuillez entrer un nom');
      return;
    }

    final newBuilding = Immeuble(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      address: _addressController.text,
      lots: [],
    );

    setState(() {
      _buildings.add(newBuilding);
    });
    _saveBuildings();

    _nameController.clear();
    _addressController.clear();
    Navigator.pop(context);
    _showSnackBar('Immeuble ajouté avec succès');
  }

  void _editBuilding(Immeuble building) {
    _nameController.text = building.name;
    _addressController.text = building.address;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier l\'immeuble'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final updatedBuilding = Immeuble(
                id: building.id,
                name: _nameController.text,
                address: _addressController.text,
                lots: building.lots,
              );
              final index = _buildings.indexWhere((b) => b.id == building.id);
              setState(() => _buildings[index] = updatedBuilding);
              _saveBuildings();
              _nameController.clear();
              _addressController.clear();
              Navigator.pop(context);
              _showSnackBar('Immeuble modifié avec succès');
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _deleteBuilding(Immeuble building) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'immeuble'),
        content: Text('Voulez-vous vraiment supprimer ${building.name} ?\nTous les lots seront également supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              setState(() => _buildings.removeWhere((b) => b.id == building.id));
              _saveBuildings();
              if (mounted) Navigator.pop(context);
              _showSnackBar('Immeuble supprimé');
              _loadData();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addLot(String buildingId) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final areaController = TextEditingController();
    final rentController = TextEditingController();
    final roomsController = TextEditingController();
    final floorController = TextEditingController();
    String selectedStatus = 'libre';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Ajouter un lot'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom du lot', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: areaController, decoration: const InputDecoration(labelText: 'Surface (m²)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: rentController, decoration: const InputDecoration(labelText: 'Loyer (€)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: roomsController, decoration: const InputDecoration(labelText: 'Nombre de pièces', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Étage', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'libre', child: Text('Libre')),
                        DropdownMenuItem(value: 'occupé', child: Text('Occupé')),
                        DropdownMenuItem(value: 'travaux', child: Text('En travaux')),
                      ],
                      onChanged: (value) => setDialogState(() => selectedStatus = value!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    _showSnackBar('Veuillez entrer un nom');
                    return;
                  }
                  final newLot = Lot(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: typeController.text,
                    area: double.tryParse(areaController.text) ?? 0,
                    rent: double.tryParse(rentController.text) ?? 0,
                    rooms: int.tryParse(roomsController.text) ?? 0,
                    status: selectedStatus,
                    floor: floorController.text,
                    tenantId: null,
                  );
                  final index = _buildings.indexWhere((b) => b.id == buildingId);
                  setState(() => _buildings[index].lots.add(newLot));
                  _saveBuildings();
                  if (mounted) Navigator.pop(context);
                  _showSnackBar('Lot ajouté avec succès');
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editLot(Immeuble building, Lot lot) {
    final nameController = TextEditingController(text: lot.name);
    final typeController = TextEditingController(text: lot.type);
    final areaController = TextEditingController(text: lot.area.toString());
    final rentController = TextEditingController(text: lot.rent.toString());
    final roomsController = TextEditingController(text: lot.rooms.toString());
    final floorController = TextEditingController(text: lot.floor);
    String selectedStatus = lot.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Modifier le lot'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: areaController, decoration: const InputDecoration(labelText: 'Surface (m²)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: rentController, decoration: const InputDecoration(labelText: 'Loyer (€)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: roomsController, decoration: const InputDecoration(labelText: 'Pièces', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Étage', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'libre', child: Text('Libre')),
                        DropdownMenuItem(value: 'occupé', child: Text('Occupé')),
                        DropdownMenuItem(value: 'travaux', child: Text('En travaux')),
                      ],
                      onChanged: (value) => setDialogState(() => selectedStatus = value!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  final updatedLot = Lot(
                    id: lot.id,
                    name: nameController.text,
                    type: typeController.text,
                    area: double.tryParse(areaController.text) ?? 0,
                    rent: double.tryParse(rentController.text) ?? 0,
                    rooms: int.tryParse(roomsController.text) ?? 0,
                    status: selectedStatus,
                    floor: floorController.text,
                    tenantId: lot.tenantId,
                  );
                  final buildingIndex = _buildings.indexWhere((b) => b.id == building.id);
                  final lotIndex = _buildings[buildingIndex].lots.indexWhere((l) => l.id == lot.id);
                  setState(() => _buildings[buildingIndex].lots[lotIndex] = updatedLot);
                  _saveBuildings();
                  if (mounted) Navigator.pop(context);
                  _showSnackBar('Lot modifié avec succès');
                },
                child: const Text('Modifier'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteLot(Immeuble building, Lot lot) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le lot'),
        content: Text('Voulez-vous vraiment supprimer le lot ${lot.name} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              final buildingIndex = _buildings.indexWhere((b) => b.id == building.id);
              setState(() => _buildings[buildingIndex].lots.removeWhere((l) => l.id == lot.id));
              _saveBuildings();
              if (mounted) Navigator.pop(context);
              _showSnackBar('Lot supprimé');
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'libre': return 'Libre';
      case 'occupé': return 'Occupé';
      case 'travaux': return 'En travaux';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'libre': return Colors.green;
      case 'occupé': return Colors.red;
      case 'travaux': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'libre': return Icons.check_circle;
      case 'occupé': return Icons.person;
      case 'travaux': return Icons.build;
      default: return Icons.help;
    }
  }

  String? _getTenantNameForLot(String? tenantId) {
    if (tenantId == null) return null;
    final tenant = _tenants.firstWhere(
      (t) => t.id == tenantId,
      orElse: () => Tenant(id: '', fullName: '', startDate: DateTime.now()),
    );
    return tenant.fullName.isNotEmpty ? tenant.fullName : null;
  }

  Widget _buildLotCard(Lot lot, Immeuble building) {
    final tenantName = _getTenantNameForLot(lot.tenantId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _getStatusColor(lot.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getStatusIcon(lot.status), color: _getStatusColor(lot.status), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot.name, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.square_foot, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('${lot.area} m²', style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey[500])),
                          const SizedBox(width: 12),
                          Icon(Icons.meeting_room, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('${lot.rooms} pièces', style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey[500])),
                          const SizedBox(width: 12),
                          Icon(Icons.arrow_upward, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('Étage ${lot.floor}', style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusColor(lot.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(_getStatusIcon(lot.status), size: 12, color: _getStatusColor(lot.status)),
                      const SizedBox(width: 4),
                      Text(_getStatusText(lot.status), style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w500, color: _getStatusColor(lot.status))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lot.type, style: GoogleFonts.urbanist(fontSize: 13, color: Colors.grey[600])),
                Text('${lot.rent.toStringAsFixed(2)} €/mois', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E88E5))),
              ],
            ),
            if (lot.status == 'occupé' && tenantName != null && tenantName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Locataire : $tenantName', style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _editLot(building, lot), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteLot(building, lot), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Immeubles', style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: () {
              _nameController.clear();
              _addressController.clear();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Ajouter un immeuble'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder())),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                    ElevatedButton(onPressed: _addBuilding, child: const Text('Ajouter')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Aucun immeuble', style: GoogleFonts.urbanist(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Appuyez sur le bouton + pour ajouter', style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _buildings.length,
                  itemBuilder: (context, index) {
                    final building = _buildings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(color: const Color(0xFF1E88E5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.apartment, color: Color(0xFF1E88E5), size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(building.name, style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(building.address, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[600])),
                                      const SizedBox(height: 4),
                                      Text('${building.lots.length} lots', style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editBuilding(building)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteBuilding(building)),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Lots', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                                    IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF1E88E5)), onPressed: () => _addLot(building.id), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (building.lots.isEmpty)
                                  Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Aucun lot', style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[500])))),
                                ...building.lots.map((lot) => _buildLotCard(lot, building)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}