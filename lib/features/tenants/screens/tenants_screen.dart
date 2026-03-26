import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/pref_keys.dart';
import '../../buildings/models/property.dart';
import '../models/tenant.dart';
import 'tenant_payments_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  List<Tenant> _tenants = [];
  List<Immeuble> _buildings = [];
  bool _isLoading = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime _startDate = DateTime.now();
  String? _selectedBuildingId;
  String? _selectedLotId;
  List<Lot> _availableLots = [];

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

  Future<void> _saveTenants() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_tenants.map((e) => e.toJson()).toList());
    await prefs.setString(PrefKeys.tenants, jsonString);
  }

  List<Lot> _getAvailableLots(String? buildingId) {
    if (buildingId == null) return [];
    final building = _buildings.firstWhere(
      (b) => b.id == buildingId,
      orElse: () => Immeuble(id: '', name: '', address: '', lots: []),
    );
    return building.lots.where((lot) => lot.status.toLowerCase() == 'libre').toList();
  }

  void _updateLots(String? buildingId) {
    setState(() {
      _selectedBuildingId = buildingId;
      _selectedLotId = null;
      _availableLots = _getAvailableLots(buildingId);
    });
  }

  Future<void> _updateLotStatus(String? buildingId, String? lotId, String status, {String? tenantId}) async {
    if (buildingId == null || lotId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String? buildingsJson = prefs.getString(PrefKeys.buildings);
    if (buildingsJson == null) return;

    List<Immeuble> buildings = (jsonDecode(buildingsJson) as List).map((e) => Immeuble.fromJson(e)).toList();
    for (var i = 0; i < buildings.length; i++) {
      if (buildings[i].id == buildingId) {
        final lots = buildings[i].lots;
        for (var j = 0; j < lots.length; j++) {
          if (lots[j].id == lotId) {
            lots[j] = Lot(
              id: lots[j].id,
              name: lots[j].name,
              type: lots[j].type,
              area: lots[j].area,
              rent: lots[j].rent,
              rooms: lots[j].rooms,
              status: status,
              floor: lots[j].floor,
              tenantId: tenantId,
            );
            break;
          }
        }
        break;
      }
    }
    await prefs.setString(PrefKeys.buildings, jsonEncode(buildings.map((e) => e.toJson()).toList()));
    await _loadBuildings(); // recharger localement
  }

  void _addTenant() async {
    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    if (fullName.isEmpty) {
      _showSnackBar('Veuillez entrer le nom du locataire');
      return;
    }
    if (_selectedBuildingId == null || _selectedLotId == null) {
      _showSnackBar('Veuillez sélectionner un bien');
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newTenant = Tenant(
      id: id,
      fullName: fullName,
      buildingId: _selectedBuildingId,
      lotId: _selectedLotId,
      startDate: _startDate,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    setState(() => _tenants.add(newTenant));
    await _saveTenants();
    await _updateLotStatus(_selectedBuildingId, _selectedLotId, 'occupé', tenantId: newTenant.id);

    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _startDate = DateTime.now();
    _selectedBuildingId = null;
    _selectedLotId = null;
    _availableLots = [];

    if (mounted) Navigator.pop(context);
    
    _showSnackBar('Locataire ajouté avec succès');
    _loadData();
  }

  void _editTenant(Tenant tenant) {
    final nameParts = tenant.fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _firstNameController.text = firstName;
    _lastNameController.text = lastName;
    _emailController.text = tenant.email ?? '';
    _phoneController.text = tenant.phone ?? '';
    _startDate = tenant.startDate;
    _selectedBuildingId = tenant.buildingId;
    _selectedLotId = tenant.lotId;

    if (tenant.buildingId != null) _updateLots(tenant.buildingId);

    showDialog(
      context: context,
      builder: (context) => _buildTenantDialog(isEdit: true, tenant: tenant),
    );
  }

  Future<void> _updateTenant(Tenant oldTenant) async {
    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    if (fullName.isEmpty) {
      _showSnackBar('Veuillez entrer le nom du locataire');
      return;
    }

    final updatedTenant = Tenant(
      id: oldTenant.id,
      fullName: fullName,
      buildingId: _selectedBuildingId,
      lotId: _selectedLotId,
      startDate: _startDate,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    final index = _tenants.indexWhere((t) => t.id == oldTenant.id);
    setState(() => _tenants[index] = updatedTenant);
    await _saveTenants();

    if (oldTenant.lotId != _selectedLotId) {
      if (oldTenant.lotId != null && oldTenant.buildingId != null) {
        await _updateLotStatus(oldTenant.buildingId, oldTenant.lotId, 'libre');
      }
      await _updateLotStatus(_selectedBuildingId, _selectedLotId, 'occupé', tenantId: updatedTenant.id);
    }

    if (mounted) Navigator.pop(context);
    _showSnackBar('Locataire modifié avec succès');
    _loadData();
  }

  void _deleteTenant(Tenant tenant) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le locataire'),
        content: Text('Voulez-vous vraiment supprimer ${tenant.fullName} ?\nLe lot redeviendra libre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              await _updateLotStatus(tenant.buildingId, tenant.lotId, 'libre');
              setState(() => _tenants.removeWhere((t) => t.id == tenant.id));
              await _saveTenants();
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                _showSnackBar('Locataire supprimé, lot libéré');
                _loadData();
              }
          
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantDialog({bool isEdit = false, Tenant? tenant}) {
    String? localBuildingId = _selectedBuildingId;
    String? localLotId = _selectedLotId;
    List<Lot> localAvailableLots = List.from(_availableLots);
    DateTime localStartDate = _startDate;
    final localFirstName = TextEditingController(text: _firstNameController.text);
    final localLastName = TextEditingController(text: _lastNameController.text);
    final localEmail = TextEditingController(text: _emailController.text);
    final localPhone = TextEditingController(text: _phoneController.text);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEdit ? 'Modifier le locataire' : 'Ajouter un locataire'),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: localFirstName, decoration: const InputDecoration(labelText: 'Prénom', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: localLastName, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: localEmail, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(controller: localPhone, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: localBuildingId,
                    hint: const Text('Sélectionner un immeuble'),
                    decoration: const InputDecoration(labelText: 'Immeuble', border: OutlineInputBorder()),
                    items: _buildings.map((building) => DropdownMenuItem(value: building.id, child: Text(building.name))).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        localBuildingId = value;
                        localLotId = null;
                        if (value == null) {
                          localAvailableLots = [];
                        } else {
                          final building = _buildings.firstWhere((b) => b.id == value, orElse: () => Immeuble(id: '', name: '', address: '', lots: []));
                          localAvailableLots = building.lots.where((lot) => lot.status.toLowerCase() == 'libre').toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: localLotId,
                    hint: const Text('Sélectionner un lot'),
                    decoration: const InputDecoration(labelText: 'Lot', border: OutlineInputBorder()),
                    items: localAvailableLots.map((lot) {
                      return DropdownMenuItem(
                        value: lot.id,
                        child: Row(
                          children: [
                            Icon(_getStatusIcon(lot.status), size: 16, color: _getStatusColor(lot.status)),
                            const SizedBox(width: 8),
                            Text('${lot.name} - ${lot.rent.toStringAsFixed(2)} €'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _getStatusColor(lot.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text(_getStatusText(lot.status), style: TextStyle(fontSize: 10, color: _getStatusColor(lot.status))),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setDialogState(() => localLotId = value),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Date d\'entrée'),
                    subtitle: Text('${localStartDate.day}/${localStartDate.month}/${localStartDate.year}'),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: localStartDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setDialogState(() => localStartDate = date);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            _firstNameController.text = localFirstName.text;
            _lastNameController.text = localLastName.text;
            _emailController.text = localEmail.text;
            _phoneController.text = localPhone.text;
            _startDate = localStartDate;
            _selectedBuildingId = localBuildingId;
            _selectedLotId = localLotId;

            if (isEdit && tenant != null) {
              _updateTenant(tenant);
            } else {
              _addTenant();
            }
          },
          child: Text(isEdit ? 'Modifier' : 'Ajouter'),
        ),
      ],
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Locataires', style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: () {
              _firstNameController.clear();
              _lastNameController.clear();
              _emailController.clear();
              _phoneController.clear();
              _startDate = DateTime.now();
              _selectedBuildingId = null;
              _selectedLotId = null;
              _availableLots = [];
              showDialog(context: context, builder: (context) => _buildTenantDialog());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tenants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Aucun locataire', style: GoogleFonts.urbanist(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Appuyez sur le bouton + pour ajouter', style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tenants.length,
                  itemBuilder: (context, index) {
                    final tenant = _tenants[index];
                    final lotInfo = _getLotInfo(tenant.buildingId, tenant.lotId);
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
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenantPaymentsScreen(tenant: tenant))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                                      child: Text(
                                        tenant.fullName.isNotEmpty ? tenant.fullName[0].toUpperCase() : '?',
                                        style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E88E5)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(tenant.fullName, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(lotInfo['name'], style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editTenant(tenant)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteTenant(tenant)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(color: Colors.grey[200]),
                                const SizedBox(height: 8),
                                if (tenant.email != null && tenant.email!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.email, size: 14, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(tenant.email!, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[600]))),
                                      ],
                                    ),
                                  ),
                                if (tenant.phone != null && tenant.phone!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(tenant.phone!, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[600]))),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.apartment, size: 14, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${lotInfo['type']} - ${lotInfo['area']}m² - ${lotInfo['rooms']} pièces',
                                          style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Entrée : ${tenant.startDate.day}/${tenant.startDate.month}/${tenant.startDate.year}',
                                          style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Loyer mensuel', style: GoogleFonts.urbanist(fontSize: 13, color: const Color(0xFF1E88E5))),
                                      Text('${lotInfo['rent'].toStringAsFixed(2)} €', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E88E5))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Map<String, dynamic> _getLotInfo(String? buildingId, String? lotId) {
    if (buildingId == null || lotId == null) {
      return {'name': 'Non défini', 'rent': 0.0, 'type': '', 'area': 0, 'rooms': 0};
    }
    final building = _buildings.firstWhere(
      (b) => b.id == buildingId,
      orElse: () => Immeuble(id: '', name: '', address: '', lots: []),
    );
    final lot = building.lots.firstWhere(
      (l) => l.id == lotId,
      orElse: () => Lot(id: '', name: '', type: '', area: 0, rent: 0, rooms: 0, status: '', floor: ''),
    );
    return {
      'name': lot.name,
      'rent': lot.rent,
      'type': lot.type,
      'area': lot.area,
      'rooms': lot.rooms,
    };
  }
}