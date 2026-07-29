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
      final updated = _config.copyWith(
        version: _versionController.text.trim().isEmpty
            ? _config.version
            : _versionController.text.trim(),
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
      return const Center(child: CircularProgressIndicator());
    }

    final padding = context.isMobile
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Configuration',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Global feature flags and platform settings',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Maintenance',
            [
              SwitchListTile(
                value: _config.maintenanceMode,
                title: const Text('Maintenance mode'),
                subtitle: const Text(
                  'When enabled, non-owner users see a maintenance banner.',
                  style: TextStyle(fontSize: 12),
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
                title: const Text('Fingerprint scanning'),
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(fingerprintEnabled: v);
                }),
              ),
              SwitchListTile(
                value: _config.messagingEnabled,
                title: const Text('Parent messaging'),
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(messagingEnabled: v);
                }),
              ),
              SwitchListTile(
                value: _config.multiSchoolEnabled,
                title: const Text('Multi-school mode'),
                subtitle: const Text(
                  'Scopes every query by schoolId for non-owner users.',
                  style: TextStyle(fontSize: 12),
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
              _buildTextField('Default country', _defaultCountryController),
              const SizedBox(height: 12),
              _buildTextField('Support email', _supportEmailController,
                  keyboardType: TextInputType.emailAddress),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection('Data migration', [_buildDataMigrationControls()]),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: _fieldDecoration(label),
    );
  }

  Widget _buildSchoolDropdown() {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String?>(
      value: _backfillSchoolId,
      isExpanded: true,
      decoration: _fieldDecoration('Target school'),
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
      items: _schools
          .map(
            (s) => DropdownMenuItem<String?>(
              value: s.id,
              child: Text(
                s.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _backfillSchoolId = v),
    );
  }

  Widget _buildBackfillButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      onPressed: _isBackfilling ? null : _runBackfill,
      icon:
          _isBackfilling
              ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onPrimary,
                  ),
                ),
              )
              : const Icon(Icons.upgrade, size: 18),
      label: Text(_isBackfilling ? 'Running...' : 'Run backfill'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }

  Widget _buildDataMigrationControls() {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = context.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Assign every student that currently has no schoolId to the '
          'school selected below. Run this once after enabling multi-school mode.',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        SizedBox(height: isMobile ? 20 : 16),
        if (isMobile) ...[
          _buildSchoolDropdown(),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _buildBackfillButton()),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSchoolDropdown()),
              const SizedBox(width: 12),
              _buildBackfillButton(),
            ],
          ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final button = ElevatedButton.icon(
      onPressed: _isSaving ? null : _save,
      icon:
          _isSaving
              ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onPrimary,
                  ),
                ),
              )
              : const Icon(Icons.save, size: 18),
      label: Text(_isSaving ? 'Saving...' : 'Save changes'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    );

    if (context.isMobile) {
      return SizedBox(width: double.infinity, child: button);
    }
    return Align(alignment: Alignment.centerRight, child: button);
  }

  Widget _buildSection(String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
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
