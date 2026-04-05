import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../models/system_config.dart';
import '../../services/firebase_service.dart';
import '../../utils/responsive_builder.dart';

class SystemConfigScreen extends StatefulWidget {
  const SystemConfigScreen({super.key});

  @override
  State<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends State<SystemConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBackfilling = false;
  SystemConfig _config = const SystemConfig();
  List<School> _schools = const [];
  String? _backfillSchoolId;

  final _versionController = TextEditingController();
  final _defaultCountryController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _periodsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _versionController.dispose();
    _defaultCountryController.dispose();
    _supportEmailController.dispose();
    _periodsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getSystemConfig(),
        FirebaseService.getSchools(),
      ]);
      final config = results[0] as SystemConfig;
      final schools = results[1] as List<School>;
      if (!mounted) return;
      setState(() {
        _config = config;
        _schools = schools;
        _backfillSchoolId =
            schools.isNotEmpty ? schools.first.id : null;
        _versionController.text = config.version;
        _defaultCountryController.text = config.defaultCountry ?? '';
        _supportEmailController.text = config.supportEmail ?? '';
        _periodsController.text = config.attendancePeriods.join(', ');
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading config: $e')),
      );
    }
  }

  Future<void> _runBackfill() async {
    final schoolId = _backfillSchoolId;
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a school first')),
      );
      return;
    }
    setState(() => _isBackfilling = true);
    try {
      final updated =
          await FirebaseService.backfillStudentSchoolIds(schoolId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned $updated unassigned students to the selected school'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBackfilling = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final periods = _periodsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final updated = _config.copyWith(
        version: _versionController.text.trim().isEmpty
            ? _config.version
            : _versionController.text.trim(),
        attendancePeriods: periods.isEmpty ? _config.attendancePeriods : periods,
        defaultCountry: _defaultCountryController.text.trim().isEmpty
            ? null
            : _defaultCountryController.text.trim(),
        supportEmail: _supportEmailController.text.trim().isEmpty
            ? null
            : _supportEmailController.text.trim(),
      );
      await FirebaseService.setSystemConfig(updated);
      if (!mounted) return;
      setState(() {
        _config = updated;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System configuration saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A5F5F)),
        ),
      );
    }

    final padding = context.isMobile
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Configuration',
            style: TextStyle(
              color: Color(0xFF2C2C2C),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Global feature flags and platform settings',
            style: TextStyle(color: Color(0xFF666666), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Maintenance',
            [
              SwitchListTile(
                value: _config.maintenanceMode,
                activeColor: Colors.orange,
                title: const Text(
                  'Maintenance mode',
                  style: TextStyle(color: Color(0xFF2C2C2C)),
                ),
                subtitle: const Text(
                  'When enabled, non-owner users see a maintenance banner.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(maintenanceMode: v);
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            'Features',
            [
              SwitchListTile(
                value: _config.fingerprintEnabled,
                activeColor: const Color(0xFF1A5F5F),
                title: const Text('Fingerprint scanning',
                    style: TextStyle(color: Color(0xFF2C2C2C))),
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(fingerprintEnabled: v);
                }),
              ),
              SwitchListTile(
                value: _config.messagingEnabled,
                activeColor: const Color(0xFF1A5F5F),
                title: const Text('Parent messaging',
                    style: TextStyle(color: Color(0xFF2C2C2C))),
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(messagingEnabled: v);
                }),
              ),
              SwitchListTile(
                value: _config.multiSchoolEnabled,
                activeColor: const Color(0xFF1A5F5F),
                title: const Text('Multi-school mode',
                    style: TextStyle(color: Color(0xFF2C2C2C))),
                subtitle: const Text(
                  'Scopes every query by schoolId for non-owner users.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(multiSchoolEnabled: v);
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            'Settings',
            [
              _buildTextField('Version', _versionController),
              const SizedBox(height: 12),
              _buildTextField(
                'Attendance periods (comma-separated)',
                _periodsController,
              ),
              const SizedBox(height: 12),
              _buildTextField('Default country', _defaultCountryController),
              const SizedBox(height: 12),
              _buildTextField('Support email', _supportEmailController,
                  keyboardType: TextInputType.emailAddress),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            'Data migration',
            [
              const Text(
                'Assign every student that currently has no schoolId to the '
                'school selected below. Run this once after enabling '
                'multi-school mode.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _backfillSchoolId,
                      decoration: const InputDecoration(
                        labelText: 'Target school',
                        labelStyle: TextStyle(color: Color(0xFF666666)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF1A5F5F), width: 2),
                        ),
                      ),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      items: _schools
                          .map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _backfillSchoolId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isBackfilling ? null : _runBackfill,
                    icon: _isBackfilling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upgrade, size: 18),
                    label: Text(_isBackfilling ? 'Running...' : 'Run backfill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5F5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5F5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF2C2C2C)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF666666)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
