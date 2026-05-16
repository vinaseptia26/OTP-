// lib/widgets/system_health.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemHealthWidget extends StatefulWidget {
  final Color? accentColor;
  final String Function(dynamic)? getTimeAgo;

  const SystemHealthWidget({
    super.key,
    this.accentColor,
    this.getTimeAgo,
  });

  @override
  State<SystemHealthWidget> createState() => _SystemHealthWidgetState();
}

class _SystemHealthWidgetState extends State<SystemHealthWidget> {
  Map<String, dynamic> _healthData = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  // 🔥 AMBIL DATA REAL DARI FIRESTORE
  Future<void> _loadHealthData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Coba dari health_check/current (prioritas)
      final healthDoc = await firestore
          .collection('health_check')
          .doc('current')
          .get();

      if (healthDoc.exists && healthDoc.data() != null) {
        final data = healthDoc.data()!;
        if (mounted) {
          setState(() {
            _healthData = {
              'database': data['database'] ?? _getDefaultValue('database'),
              'api': data['api'] ?? _getDefaultValue('api'),
              'storage': data['storage'] ?? _getDefaultValue('storage'),
              'memory': data['memory'] ?? _getDefaultValue('memory'),
              'cpu': data['cpu'] ?? _getDefaultValue('cpu'),
              'network': data['network'] ?? _getDefaultValue('network'),
              'uptime': data['uptime'] ?? _getDefaultValue('uptime'),
              'lastBackup': data['last_backup'] ?? FieldValue.serverTimestamp(),
            };
            _isLoading = false;
          });
        }
        return;
      }

      // 2️⃣ Fallback: system_settings/health
      final settingsDoc = await firestore
          .collection('system_settings')
          .doc('health')
          .get();

      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        if (mounted) {
          setState(() {
            _healthData = {
              'database': data['database'] ?? _getDefaultValue('database'),
              'api': data['api'] ?? _getDefaultValue('api'),
              'storage': data['storage'] ?? _getDefaultValue('storage'),
              'memory': data['memory'] ?? _getDefaultValue('memory'),
              'cpu': data['cpu'] ?? _getDefaultValue('cpu'),
              'network': data['network'] ?? _getDefaultValue('network'),
              'uptime': data['uptime'] ?? _getDefaultValue('uptime'),
              'lastBackup': data['lastBackup'] ?? FieldValue.serverTimestamp(),
            };
            _isLoading = false;
          });
        }
        return;
      }

      // 3️⃣ Fallback terakhir: default values (Firestore kosong)
      if (mounted) {
        setState(() {
          _healthData = {
            'database': 100,
            'api': 100,
            'storage': 100,
            'memory': 100,
            'cpu': 0,
            'network': 0,
            'uptime': 0,
            'lastBackup': null,
          };
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('❌ Error loading system health: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data kesehatan sistem';
          _isLoading = false;
        });
      }
    }
  }

  // Default values per key (kalau field ga ada di Firestore)
  int _getDefaultValue(String key) {
    switch (key) {
      case 'database': return 100;
      case 'api': return 100;
      case 'storage': return 100;
      case 'memory': return 100;
      case 'cpu': return 0;
      case 'network': return 0;
      case 'uptime': return 0;
      default: return 100;
    }
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (widget.getTimeAgo != null) {
      return widget.getTimeAgo!(timestamp);
    }

    if (timestamp == null) return 'Belum ada backup';

    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return 'Belum ada backup';
    }

    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bulan lalu';
    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? const Color(0xFF1E3C72);

    // 🔥 LOADING
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.health_and_safety, color: color, size: 20),
              const SizedBox(width: 8),
              Text('Kesehatan Sistem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            ]),
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // 🔥 ERROR
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.health_and_safety, color: color, size: 20),
              const SizedBox(width: 8),
              Text('Kesehatan Sistem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            ]),
            const SizedBox(height: 16),
            Center(
              child: Column(children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
                const SizedBox(height: 8),
                Text(_errorMessage!, style: TextStyle(color: Colors.red[400], fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loadHealthData,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Coba Lagi'),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    // 🔥 DATA REAL
    final database = (_healthData['database'] as num?)?.toInt() ?? 100;
    final api = (_healthData['api'] as num?)?.toInt() ?? 100;
    final storage = (_healthData['storage'] as num?)?.toInt() ?? 100;
    final memory = (_healthData['memory'] as num?)?.toInt() ?? 100;
    final cpu = (_healthData['cpu'] as num?)?.toInt() ?? 0;
    final network = (_healthData['network'] as num?)?.toInt() ?? 0;
    final uptime = (_healthData['uptime'] as num?)?.toInt() ?? 0;
    final lastBackup = _healthData['lastBackup'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 HEADER + REFRESH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.health_and_safety, color: color, size: 20),
                const SizedBox(width: 8),
                Text('Kesehatan Sistem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
              ]),
              InkWell(
                onTap: _loadHealthData,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.refresh_rounded, size: 16, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🔥 HEALTH INDICATORS
          Row(children: [
            _buildHealthGauge('Database', database, color),
            const SizedBox(width: 12),
            _buildHealthGauge('API', api, color),
            const SizedBox(width: 12),
            _buildHealthGauge('Storage', storage, color),
            const SizedBox(width: 12),
            _buildHealthGauge('Memory', memory, color),
          ]),
          const SizedBox(height: 16),

          // 🔥 SYSTEM INFO
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildInfoItem('CPU', '$cpu%', Icons.speed),
            _buildInfoItem('Network', '$network Mbps', Icons.network_check),
            _buildInfoItem('Uptime', '$uptime jam', Icons.timer),
          ]),

          // 🔥 LAST BACKUP (kalau ada)
          if (lastBackup != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.backup, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                'Last Backup: ${_formatTimeAgo(lastBackup)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ]),
          ],

          // 🔥 STATUS OVERALL
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getOverallColor(database, api, storage, memory).withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getOverallColor(database, api, storage, memory).withAlpha(50)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _getOverallColor(database, api, storage, memory),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _getOverallStatus(database, api, storage, memory),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getOverallColor(database, api, storage, memory),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================

  Widget _buildHealthGauge(String label, int value, Color accentColor) {
    final color = value >= 90 ? Colors.green : value >= 70 ? Colors.orange : Colors.red;

    return Expanded(
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 50, height: 50,
            child: CircularProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeWidth: 4,
            ),
          ),
          Text('$value%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      ]),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ]);
  }

  Color _getOverallColor(int db, int api, int storage, int memory) {
    final avg = (db + api + storage + memory) / 4;
    if (avg >= 90) return Colors.green;
    if (avg >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getOverallStatus(int db, int api, int storage, int memory) {
    final avg = (db + api + storage + memory) / 4;
    if (avg >= 95) return '🟢 Sistem Sehat';
    if (avg >= 80) return '🟡 Sistem Normal';
    if (avg >= 60) return '🟠 Perlu Perhatian';
    return '🔴 Sistem Kritis';
  }
}