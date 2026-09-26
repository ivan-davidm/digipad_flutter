import 'dart:io';
import 'package:digipad_flutter/data/local/measurement_storage.dart';
import 'package:digipad_flutter/data/models/measurement_record.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:flutter/material.dart';

import 'optical_editor_screen.dart';

enum _SortOrder { dateDesc, dateAsc, nameAsc }

class MeasurementsListScreen extends StatefulWidget {
  const MeasurementsListScreen({super.key});

  @override
  State<MeasurementsListScreen> createState() => _MeasurementsListScreenState();
}

class _MeasurementsListScreenState extends State<MeasurementsListScreen> {
  List<MeasurementRecord> _records = [];
  bool _loading = true;
  _SortOrder _sortOrder = _SortOrder.dateDesc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await MeasurementStorage.instance.getAll();
    if (mounted) setState(() { _records = _sorted(all); _loading = false; });
  }

  List<MeasurementRecord> _sorted(List<MeasurementRecord> list) {
    final copy = [...list];
    switch (_sortOrder) {
      case _SortOrder.dateDesc:
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOrder.dateAsc:
        copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOrder.nameAsc:
        copy.sort((a, b) =>
            a.patientFullName.toLowerCase().compareTo(b.patientFullName.toLowerCase()));
    }
    return copy;
  }

  void _applySort(_SortOrder order) {
    setState(() {
      _sortOrder = order;
      _records = _sorted(_records);
    });
  }

  Future<void> _delete(MeasurementRecord record) async {
    await MeasurementStorage.instance.delete(record.id);
    if (mounted) setState(() => _records.removeWhere((r) => r.id == record.id));
  }

  void _confirmDelete(MeasurementRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(context.l10n.deleteMeasurementTitle,
            style: const TextStyle(color: Colors.white)),
        content: Text(context.l10n.deleteMeasurementContent,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(record);
            },
            child: Text(context.l10n.delete,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _openRecord(MeasurementRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OpticalEditorScreen(
          imagePath: record.imagePath,
          savedRecord: record,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(context.l10n.myMeasurements,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1C1C1E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.sort, color: Colors.white),
            color: const Color(0xFF2C2C2E),
            onSelected: _applySort,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortOrder.dateDesc,
                child: Row(children: [
                  if (_sortOrder == _SortOrder.dateDesc)
                    const Icon(Icons.check, color: Colors.deepPurpleAccent, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(context.l10n.sortByDate,
                      style: const TextStyle(color: Colors.white)),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.nameAsc,
                child: Row(children: [
                  if (_sortOrder == _SortOrder.nameAsc)
                    const Icon(Icons.check, color: Colors.deepPurpleAccent, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(context.l10n.sortByName,
                      style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : _records.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.noSavedMeasurements,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) => _buildCard(_records[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(MeasurementRecord record) {
    final name = record.patientFullName.isEmpty
        ? context.l10n.unknownPatient
        : record.patientFullName;
    final results = record.results;
    final dnpR = (results['dnpRight'] as num?)?.toStringAsFixed(1) ?? '--';
    final dnpL = (results['dnpLeft'] as num?)?.toStringAsFixed(1) ?? '--';
    final angle = record.pantoscopicAngle;

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        _confirmDelete(record);
        return false;
      },
      child: InkWell(
        onTap: () => _openRecord(record),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: File(record.imagePath).existsSync()
                      ? Image.file(File(record.imagePath),
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          key: ValueKey(record.imagePath))
                      : Container(
                          color: Colors.grey[850],
                          child: const Icon(Icons.broken_image,
                              color: Colors.white24, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(record.formattedDate,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _chip('DNP R: $dnpR mm', Colors.cyanAccent),
                        const SizedBox(width: 6),
                        _chip('DNP L: $dnpL mm', Colors.greenAccent),
                        if (angle != null) ...[
                          const SizedBox(width: 6),
                          _chip('${angle.toStringAsFixed(1)}°',
                              Colors.orangeAccent),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right, color: Colors.white24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
