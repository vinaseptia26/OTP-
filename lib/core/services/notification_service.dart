// lib/core/services/notification_service.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'overtime_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // FONNTE WHATSAPP CONFIG
  // ============================================================================
  static const String fonnteApiKey = 'Eo4VfZvp2mv9Fg6A3DRE6Uq7ydVrbRs';
  static const String fonnteApiUrl = 'https://api.fonnte.com/send';

  final OvertimeService _overtimeService = OvertimeService();

  // ============================================================================
  // SECTION 1: NOTIFIKASI PENGAJUAN BARU KE MANAGER
  // ============================================================================

  Future<void> sendManagerNotification({
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required DateTime tanggal,
    required double totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required List<String> lemburIds,
    required Map<String, dynamic> overtimeRates,
  }) async {
    try {
      final managers = await _getManagersByFungsi(fungsi);
      if (managers.isEmpty) {
        debugPrint('⚠️ No active managers found for fungsi: $fungsi');
        return;
      }

      final tanggalFormat = DateFormat('dd/MM/yyyy').format(tanggal);
      final tanggalLengkap =
          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal);
      final biayaFormat = _overtimeService.formatRupiah(totalBiaya);
      final ratePerHour = _overtimeService.formatRupiahCompact(
        (overtimeRates['rate_per_hour'] as num?)?.toDouble() ?? 0,
      );

      final groupId = lemburIds.isNotEmpty ? lemburIds.first : '';
      final shortGroupId =
          groupId.length >= 8 ? groupId.substring(0, 8) : groupId;

      final priority = urgensi == 'kritis'
          ? 1
          : urgensi == 'tinggi'
              ? 2
              : urgensi == 'normal'
                  ? 3
                  : 4;

      int sentCount = 0;

      for (final manager in managers) {
        try {
          final managerId = manager['id'] as String;
          final managerEmail = manager['email'] as String;
          final managerNoHp = manager['no_hp'] as String;
          final managerName = manager['nama_lengkap'] as String;

          // 1. Simpan notifikasi di Firestore
          await _createFirestoreNotification(
            userId: managerId,
            type: 'lembur_submitted',
            title: '📋 Pengajuan Lembur Baru',
            message: _buildSubmissionMessage(
              pengawasNama: pengawasNama,
              fungsi: fungsi,
              jumlahMitra: jumlahMitra,
              tanggal: tanggalLengkap,
              totalBiaya: biayaFormat,
              ratePerHour: ratePerHour,
              urgensi: urgensi,
              isOutsideRadius: isOutsideRadius,
            ),
            data: {
              'group_id': groupId,
              'pengawas_id': _auth.currentUser?.uid ?? '',
              'pengawas_nama': pengawasNama,
              'fungsi': fungsi,
              'jumlah_mitra': jumlahMitra,
              'tanggal': tanggalFormat,
              'total_biaya': biayaFormat,
              'urgensi': urgensi,
              'is_outside_radius': isOutsideRadius,
              'rate_per_hour': ratePerHour,
              'action': 'approval_needed',
            },
            priority: priority,
          );

          // 2. Kirim Email
          if (managerEmail.isNotEmpty) {
            _sendEmail(
              subject: '🔔 Pengajuan Lembur Baru - $pengawasNama',
              body: _buildApprovalRequestEmail({
                'to_name': managerName,
                'pengawas_nama': pengawasNama,
                'fungsi': fungsi.toUpperCase(),
                'jumlah_mitra': jumlahMitra.toString(),
                'tanggal': tanggalLengkap,
                'total_biaya': biayaFormat,
                'rate_per_hour': ratePerHour,
                'urgensi': urgensi.toUpperCase(),
                'lokasi_status': isOutsideRadius
                    ? '⚠️ LUAR RADIUS'
                    : '✅ DALAM RADIUS',
                'group_id': shortGroupId,
                'link_approval': 'https://otp-pge.web.app/approval/$groupId',
              }),
              toEmail: managerEmail,
            );
          }

          // 3. Kirim WhatsApp
          if (managerNoHp.isNotEmpty) {
            _sendWhatsApp(
              phoneNumber: managerNoHp,
              message: _buildSubmissionWaMessage(
                managerName: managerName,
                pengawasNama: pengawasNama,
                fungsi: fungsi,
                jumlahMitra: jumlahMitra,
                tanggal: tanggalLengkap,
                totalBiaya: biayaFormat,
                ratePerHour: ratePerHour,
                urgensi: urgensi,
                isOutsideRadius: isOutsideRadius,
                shortGroupId: shortGroupId,
                groupId: groupId,
              ),
            );
          }

          sentCount++;
        } catch (e) {
          debugPrint(
              '❌ Error sending to manager ${manager['nama_lengkap']}: $e');
        }
      }

      debugPrint(
          '✅ Manager notification sent to $sentCount/${managers.length} managers');
    } catch (e) {
      debugPrint('❌ Error sendManagerNotification: $e');
    }
  }

  // ============================================================================
  // SECTION 2: NOTIFIKASI HASIL APPROVAL KE PENGAWAS
  // ============================================================================

  Future<void> sendApprovalResultNotification({
    required String pengawasId,
    required String pengawasNama,
    required String pengawasEmail,
    required String pengawasNoHp,
    required bool isApproved,
    required String approverName,
    required String approverRole,
    String? spklNomor,
    required String groupId,
    required String notes,
    required String tanggal,
    required String waktu,
    required String fungsi,
  }) async {
    try {
      final shortGroupId =
          groupId.length >= 8 ? groupId.substring(0, 8) : groupId;

      final title = isApproved
          ? '✅ Pengajuan Lembur Disetujui'
          : '❌ Pengajuan Lembur Ditolak';

      final message = isApproved
          ? '''
📋 *Status:* DISETUJUI
━━━━━━━━━━━━━━━━━━━

Pengajuan lembur kamu telah disetujui!

📄 *No SPKL:* ${spklNomor ?? '-'}
👤 *Approver:* $approverName ($approverRole)
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu

${notes.isNotEmpty ? '📝 *Catatan:* $notes' : ''}

Silakan cek aplikasi untuk melihat SPKL dan detail lainnya.
'''
          : '''
📋 *Status:* DITOLAK
━━━━━━━━━━━━━━━━━━━

Pengajuan lembur kamu ditolak.

👤 *Oleh:* $approverName ($approverRole)
📝 *Alasan:* $notes

Silakan revisi dan ajukan kembali.
''';

      // 1. Firestore
      await _createFirestoreNotification(
        userId: pengawasId,
        type: isApproved ? 'approval_approved' : 'approval_rejected',
        title: title,
        message: message,
        data: {
          'group_id': groupId,
          'spkl_nomor': spklNomor,
          'status': isApproved ? 'disetujui' : 'ditolak',
          'approver_name': approverName,
          'approver_role': approverRole,
          'notes': notes,
          'tanggal': tanggal,
          'waktu': waktu,
          'fungsi': fungsi,
        },
        priority: isApproved ? 1 : 2,
      );

      // 2. Email
      if (pengawasEmail.isNotEmpty) {
        _sendEmail(
          subject: '${isApproved ? '✅' : '❌'} Pengajuan Lembur - Status',
          body: _buildApprovalResultEmail({
            'to_name': pengawasNama,
            'status': isApproved ? 'DISETUJUI ✅' : 'DITOLAK ❌',
            'approver_name': approverName,
            'approver_role': approverRole,
            'spkl_nomor': spklNomor ?? '-',
            'group_id': shortGroupId,
            'tanggal': tanggal,
            'waktu': waktu,
            'fungsi': fungsi.toUpperCase(),
            'notes': notes,
            'link_spkl': isApproved
                ? 'https://otp-pge.web.app/spkl/$groupId'
                : '',
            'current_year': DateTime.now().year.toString(),
          }),
          toEmail: pengawasEmail,
        );
      }

      // 3. WhatsApp
      if (pengawasNoHp.isNotEmpty) {
        _sendWhatsApp(
          phoneNumber: pengawasNoHp,
          message: _buildApprovalResultWaMessage(
            recipientName: pengawasNama,
            isApproved: isApproved,
            approverName: approverName,
            approverRole: approverRole,
            spklNomor: spklNomor,
            groupId: groupId,
            notes: notes,
            tanggal: tanggal,
            waktu: waktu,
          ),
        );
      }

      debugPrint(
          '✅ Approval result notification sent to pengawas: $pengawasNama');
    } catch (e) {
      debugPrint('❌ Error sendApprovalResultNotification: $e');
    }
  }

  // ============================================================================
  // SECTION 3: NOTIFIKASI PENUGASAN MITRA
  // ============================================================================

  Future<void> sendMitraAssignmentNotification({
    required String mitraId,
    required String mitraNama,
    required String mitraEmail,
    required String mitraNoHp,
    String? spklNomor,
    required String groupId,
    required String pengawasNama,
    required String tanggal,
    required String waktu,
    required String lokasi,
    required String fungsi,
  }) async {
    try {
      final shortGroupId =
          groupId.length >= 8 ? groupId.substring(0, 8) : groupId;

      final message = '''
📋 *JADWAL LEMBUR BARU*
━━━━━━━━━━━━━━━━━━━

Kamu ditugaskan untuk lembur!

📄 *No SPKL:* ${spklNomor ?? '-'}
👤 *Pengawas:* $pengawasNama
🏢 *Fungsi:* ${fungsi.toUpperCase()}
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

━━━━━━━━━━━━━━━━━━━
⚠️ *Wajib:* Lakukan absensi sebelum dan sesudah lembur
━━━━━━━━━━━━━━━━━━━

Silakan cek aplikasi untuk detail SPKL dan persiapan lembur.

Terima kasih.
''';

      // 1. Firestore
      await _createFirestoreNotification(
        userId: mitraId,
        type: 'lembur_assignment',
        title: '📋 Jadwal Lembur Baru',
        message: message,
        data: {
          'group_id': groupId,
          'spkl_nomor': spklNomor,
          'pengawas_nama': pengawasNama,
          'tanggal': tanggal,
          'waktu': waktu,
          'lokasi': lokasi,
          'fungsi': fungsi,
          'action': 'view_spkl',
          'need_absen': true,
        },
        priority: 1,
      );

      // 2. Email
      if (mitraEmail.isNotEmpty) {
        _sendEmail(
          subject: '📋 Jadwal Lembur - $pengawasNama',
          body: _buildMitraAssignmentEmail({
            'to_name': mitraNama,
            'spkl_nomor': spklNomor ?? '-',
            'pengawas_nama': pengawasNama,
            'fungsi': fungsi.toUpperCase(),
            'tanggal': tanggal,
            'waktu': waktu,
            'lokasi': lokasi,
            'group_id': shortGroupId,
            'link_spkl': 'https://otp-pge.web.app/spkl/$groupId',
            'current_year': DateTime.now().year.toString(),
          }),
          toEmail: mitraEmail,
        );
      }

      // 3. WhatsApp
      if (mitraNoHp.isNotEmpty) {
        _sendWhatsApp(
          phoneNumber: mitraNoHp,
          message: _buildMitraAssignmentWaMessage(
            recipientName: mitraNama,
            spklNomor: spklNomor,
            pengawasNama: pengawasNama,
            fungsi: fungsi,
            tanggal: tanggal,
            waktu: waktu,
            lokasi: lokasi,
            groupId: groupId,
          ),
        );
      }

      debugPrint('✅ Mitra assignment notification sent to: $mitraNama');
    } catch (e) {
      debugPrint('❌ Error sendMitraAssignmentNotification: $e');
    }
  }

  // ============================================================================
  // SECTION 4: NOTIFIKASI SPKL READY
  // ============================================================================

  Future<void> sendSpklReadyNotification({
    required String pengawasId,
    required String pengawasNama,
    required String pengawasEmail,
    required List<Map<String, String>> mitraContacts,
    required String spklNomor,
    required String groupId,
    required String tanggal,
    required String waktu,
    required String lokasi,
  }) async {
    try {
      final shortGroupId =
          groupId.length >= 8 ? groupId.substring(0, 8) : groupId;

      // 1. Notifikasi ke Pengawas
      await _createFirestoreNotification(
        userId: pengawasId,
        type: 'spkl_ready',
        title: '📄 SPKL Telah Digenerate',
        message: '''
SPKL untuk pengajuan lembur telah siap!

📄 *No SPKL:* $spklNomor
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

Klik untuk melihat dan mengunduh SPKL.
''',
        data: {
          'group_id': groupId,
          'spkl_nomor': spklNomor,
          'action': 'view_spkl',
        },
        priority: 1,
      );

      if (pengawasEmail.isNotEmpty) {
        _sendEmail(
          subject: '📄 SPKL Lembur Siap - $spklNomor',
          body: _buildSpklReadyEmail({
            'to_name': pengawasNama,
            'spkl_nomor': spklNomor,
            'group_id': shortGroupId,
            'tanggal': tanggal,
            'waktu': waktu,
            'lokasi': lokasi,
            'link_spkl': 'https://otp-pge.web.app/spkl/$groupId',
            'current_year': DateTime.now().year.toString(),
          }),
          toEmail: pengawasEmail,
        );
      }

      // 2. Notifikasi ke Mitra
      for (final mitra in mitraContacts) {
        final mitraId = mitra['id'] ?? '';
        final mitraNama = mitra['nama'] ?? 'Mitra';
        final mitraEmail = mitra['email'] ?? '';
        final mitraNoHp = mitra['no_hp'] ?? '';

        if (mitraId.isEmpty) continue;

        await _createFirestoreNotification(
          userId: mitraId,
          type: 'spkl_ready',
          title: '📄 SPKL Lembur Siap',
          message: '''
SPKL untuk jadwal lembur kamu telah siap!

📄 *No SPKL:* $spklNomor
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

Silakan cek aplikasi untuk melihat SPKL.
''',
          data: {
            'group_id': groupId,
            'spkl_nomor': spklNomor,
            'action': 'view_spkl',
          },
          priority: 1,
        );

        if (mitraNoHp.isNotEmpty) {
          _sendWhatsApp(
            phoneNumber: mitraNoHp,
            message: '''
📄 *SPKL LEMBUR SIAP*
━━━━━━━━━━━━━━━━━━━

Halo *$mitraNama*,

SPKL untuk jadwal lembur kamu sudah siap!

📄 *No SPKL:* $spklNomor
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

🔗 Lihat SPKL di aplikasi:
https://otp-pge.web.app/spkl/$groupId

Terima kasih.
''',
          );
        }
      }

      debugPrint('✅ SPKL ready notification sent to all parties');
    } catch (e) {
      debugPrint('❌ Error sendSpklReadyNotification: $e');
    }
  }

  // ============================================================================
  // SECTION 5: NOTIFIKASI ABSENSI REMINDER
  // ============================================================================

  Future<void> sendAbsensiReminder({
    required String mitraId,
    required String mitraNama,
    required String mitraNoHp,
    required String groupId,
    required String tanggal,
    required String waktu,
    required bool isCheckIn,
  }) async {
    try {
      final type = isCheckIn ? 'absen_masuk' : 'absen_pulang';
      final title =
          isCheckIn ? '📸 Waktunya Absen Masuk!' : '📸 Waktunya Absen Pulang!';
      final action = isCheckIn
          ? 'Jam mulai lembur, lakukan absen masuk'
          : 'Jam selesai lembur, lakukan absen pulang';

      await _createFirestoreNotification(
        userId: mitraId,
        type: type,
        title: title,
        message: '''
$action sekarang!

📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu

Jangan lupa upload foto sebagai bukti absensi.
''',
        data: {
          'group_id': groupId,
          'action': isCheckIn ? 'absen_masuk' : 'absen_pulang',
          'tanggal': tanggal,
          'waktu': waktu,
        },
        priority: 1,
      );

      if (mitraNoHp.isNotEmpty) {
        _sendWhatsApp(
          phoneNumber: mitraNoHp,
          message: '''
${isCheckIn ? '📸' : '📸'} *${isCheckIn ? 'ABSEN MASUK' : 'ABSEN PULANG'}*
━━━━━━━━━━━━━━━━━━━

Halo *$mitraNama*,

${isCheckIn ? 'Waktunya absen masuk lembur!' : 'Waktunya absen pulang lembur!'}

📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu

Jangan lupa upload foto sebagai bukti absensi ya!

🔗 Buka aplikasi:
https://otp-pge.web.app/absen/$groupId

Terima kasih.
''',
        );
      }

      debugPrint('✅ Absensi reminder sent to: $mitraNama');
    } catch (e) {
      debugPrint('❌ Error sendAbsensiReminder: $e');
    }
  }

  // ============================================================================
  // SECTION 6: GENERAL NOTIFICATION
  // ============================================================================

  Future<void> sendGeneralNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String? userEmail,
    String? userNoHp,
    String? userName,
  }) async {
    try {
      await _createFirestoreNotification(
        userId: userId,
        type: 'general',
        title: title,
        message: message,
        data: data ?? {},
        priority: 5,
      );

      if (userEmail != null && userEmail.isNotEmpty) {
        _sendEmail(
          subject: title,
          body: message,
          toEmail: userEmail,
        );
      }

      if (userNoHp != null && userNoHp.isNotEmpty) {
        _sendWhatsApp(
          phoneNumber: userNoHp,
          message: '''
📢 *$title*
━━━━━━━━━━━━━━━━━━━

$message

━━━━━━━━━━━━━━━━━━━
*Sistem Lembur PGE Kamojang*
''',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sendGeneralNotification: $e');
    }
  }

  // ============================================================================
  // SECTION 7: NOTIFIKASI KHUSUS MITRA (Check-in, Check-out, Tolak, dll)
  // ============================================================================

  Future<void> sendMitraCheckInNotification({
    required String mitraName,
    required String lemburId,
    required String pengawasId,
  }) async {
    try {
      await _createFirestoreNotification(
        userId: pengawasId,
        type: 'lembur_checkin',
        title: 'Absensi Lembur',
        message: '$mitraName telah check-in lembur',
        data: {
          'lemburId': lemburId,
          'mitra_name': mitraName,
          'action': 'view_lembur',
        },
        priority: 2,
      );
      debugPrint('✅ Check-in notification sent to pengawas $pengawasId');
    } catch (e) {
      debugPrint('❌ Error sendMitraCheckInNotification: $e');
    }
  }

  Future<void> sendMitraCheckOutNotification({
    required String mitraName,
    required String lemburId,
    required String pengawasId,
    required double actualHours,
    required double income,
  }) async {
    try {
      final incomeFormatted = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(income);

      await _createFirestoreNotification(
        userId: pengawasId,
        type: 'lembur_completed',
        title: 'Lembur Selesai',
        message:
            '$mitraName telah menyelesaikan lembur (${actualHours.toStringAsFixed(1)} jam) - $incomeFormatted',
        data: {
          'lemburId': lemburId,
          'mitra_name': mitraName,
          'duration': actualHours,
          'income': income,
          'income_formatted': incomeFormatted,
          'action': 'view_lembur',
        },
        priority: 2,
      );
      debugPrint('✅ Check-out notification sent to pengawas $pengawasId');
    } catch (e) {
      debugPrint('❌ Error sendMitraCheckOutNotification: $e');
    }
  }

  Future<void> sendMitraRejectionNotification({
    required String mitraId,
    required String overtimeId,
    String? reason,
  }) async {
    try {
      final reasonText = reason ?? 'Tidak ada alasan';
      await _createFirestoreNotification(
        userId: mitraId,
        type: 'lembur_rejected',
        title: 'Lembur Ditolak',
        message: 'Anda menolak jadwal lembur. Alasan: $reasonText',
        data: {
          'lemburId': overtimeId,
          'reason': reasonText,
          'action': 'none',
        },
        priority: 3,
      );
      debugPrint('✅ Rejection notification sent to mitra $mitraId');
    } catch (e) {
      debugPrint('❌ Error sendMitraRejectionNotification: $e');
    }
  }

  Future<void> sendMitraConfirmationNotification({
    required String mitraId,
    required String overtimeId,
  }) async {
    try {
      await _createFirestoreNotification(
        userId: mitraId,
        type: 'lembur_confirmed',
        title: 'Lembur Dikonfirmasi',
        message: 'Anda telah mengonfirmasi jadwal lembur',
        data: {
          'lemburId': overtimeId,
          'action': 'none',
        },
        priority: 3,
      );
      debugPrint('✅ Confirmation notification sent to mitra $mitraId');
    } catch (e) {
      debugPrint('❌ Error sendMitraConfirmationNotification: $e');
    }
  }

  // ============================================================================
  // SECTION 8: GET NOTIFICATIONS & MANAGE
  // ============================================================================

  /// Stream daftar notifikasi user (flat collection)
  Stream<List<Map<String, dynamic>>> getUserNotificationsFlat(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  /// Ambil daftar notifikasi sekali pakai (Future, bukan stream)
  Future<List<Map<String, dynamic>>> getNotificationsOnce(
      String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getNotificationsOnce: $e');
      return [];
    }
  }

  /// Tandai satu notifikasi sudah dibaca (flat structure)
  Future<void> markNotificationAsReadFlat(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error markNotificationAsReadFlat: $e');
    }
  }

  /// Tandai semua notifikasi user sudah dibaca (flat)
  Future<void> markAllNotificationsAsReadFlat(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error markAllNotificationsAsReadFlat: $e');
    }
  }

  /// Hitung notifikasi belum dibaca
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getUnreadCount: $e');
      return 0;
    }
  }

  // ============================================================================
  // HELPER: FIRESTORE NOTIFICATION
  // ============================================================================

  Future<void> _createFirestoreNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    int priority = 5,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': message,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'priority': priority,
      });
    } catch (e) {
      debugPrint('❌ Error create notification: $e');
    }
  }

  // ============================================================================
  // HELPER: GET MANAGERS
  // ============================================================================

  Future<List<Map<String, dynamic>>> _getManagersByFungsi(String fungsi) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .where('fungsi', isEqualTo: fungsi.toLowerCase())
          .where('status_akun', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'nama_lengkap': data['nama_lengkap'] ?? 'Manager',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error get managers: $e');
      return [];
    }
  }

  // ============================================================================
  // HELPER: SEND EMAIL (via url_launcher - mailto:)
  // ============================================================================

  /// Membuka aplikasi email dengan subject dan body yang sudah diisi.
  /// Metode ini tidak mengirim otomatis, user perlu menekan tombol kirim.
  Future<void> _sendEmail({
    required String subject,
    required String body,
    required String toEmail,
  }) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: toEmail,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        debugPrint('✅ Email client opened for $toEmail');
      } else {
        debugPrint('⚠️ Could not launch email client');
      }
    } catch (e) {
      debugPrint('❌ Error opening email client: $e');
    }
  }

  // ============================================================================
  // EMAIL TEMPLATES
  // ============================================================================

  String _buildApprovalRequestEmail(Map<String, dynamic> params) {
    return '''
Halo ${params['to_name']},

Ada pengajuan lembur baru yang membutuhkan persetujuan Anda.

━━━━━━━━━━━━━━━━━━━━━━
📋 DETAIL PENGAJUAN
━━━━━━━━━━━━━━━━━━━━━━
👤 Pengawas    : ${params['pengawas_nama']}
🏢 Fungsi       : ${params['fungsi']}
👥 Mitra        : ${params['jumlah_mitra']} orang
📅 Tanggal      : ${params['tanggal']}
💰 Estimasi     : ${params['total_biaya']}
💵 Rate/Jam     : ${params['rate_per_hour']}
⚡ Urgensi      : ${params['urgensi']}
📍 Lokasi       : ${params['lokasi_status']}

━━━━━━━━━━━━━━━━━━━━━━
📌 ID Pengajuan : ${params['group_id']}...
━━━━━━━━━━━━━━━━━━━━━━

🔗 Buka aplikasi untuk melakukan persetujuan:
${params['link_approval']}

Terima kasih,
Sistem Lembur PGE Kamojang
''';
  }

  String _buildApprovalResultEmail(Map<String, dynamic> params) {
    return '''
Halo ${params['to_name']},

Status pengajuan lembur Anda telah diperbarui.

━━━━━━━━━━━━━━━━━━━━━━
📋 STATUS: ${params['status']}
━━━━━━━━━━━━━━━━━━━━━━
👤 Approver     : ${params['approver_name']} (${params['approver_role']})
📄 No SPKL      : ${params['spkl_nomor']}
📌 ID           : ${params['group_id']}
📅 Tanggal      : ${params['tanggal']}
⏰ Waktu        : ${params['waktu']}
🏢 Fungsi       : ${params['fungsi']}
📝 Catatan      : ${params['notes']}

${params['link_spkl'] != null && params['link_spkl'].toString().isNotEmpty ? '🔗 Lihat SPKL: ${params['link_spkl']}' : ''}

━━━━━━━━━━━━━━━━━━━━━━

Terima kasih,
Sistem Lembur PGE Kamojang
© ${params['current_year']} Overtime PGE Kamojang
''';
  }

  String _buildMitraAssignmentEmail(Map<String, dynamic> params) {
    return '''
Halo ${params['to_name']},

Anda telah ditugaskan untuk lembur.

━━━━━━━━━━━━━━━━━━━━━━
📋 DETAIL PENUGASAN
━━━━━━━━━━━━━━━━━━━━━━
📄 No SPKL      : ${params['spkl_nomor']}
👤 Pengawas     : ${params['pengawas_nama']}
🏢 Fungsi       : ${params['fungsi']}
📅 Tanggal      : ${params['tanggal']}
⏰ Waktu        : ${params['waktu']}
📍 Lokasi       : ${params['lokasi']}
📌 ID           : ${params['group_id']}

━━━━━━━━━━━━━━━━━━━━━━
⚠️ PENTING: Lakukan absensi sebelum dan sesudah lembur
━━━━━━━━━━━━━━━━━━━━━━

🔗 Lihat SPKL di aplikasi:
${params['link_spkl']}

Terima kasih,
Sistem Lembur PGE Kamojang
© ${params['current_year']} Overtime PGE Kamojang
''';
  }

  String _buildSpklReadyEmail(Map<String, dynamic> params) {
    return '''
Halo ${params['to_name']},

SPKL untuk pengajuan lembur telah siap.

━━━━━━━━━━━━━━━━━━━━━━
📄 DETAIL SPKL
━━━━━━━━━━━━━━━━━━━━━━
📄 No SPKL      : ${params['spkl_nomor']}
📅 Tanggal      : ${params['tanggal']}
⏰ Waktu        : ${params['waktu']}
📍 Lokasi       : ${params['lokasi']}
📌 ID           : ${params['group_id']}

━━━━━━━━━━━━━━━━━━━━━━

🔗 Lihat SPKL di aplikasi:
${params['link_spkl']}

Terima kasih,
Sistem Lembur PGE Kamojang
© ${params['current_year']} Overtime PGE Kamojang
''';
  }

  // ============================================================================
  // HELPER: SEND WHATSAPP (FONNTE)
  // ============================================================================

  void _sendWhatsApp({
    required String phoneNumber,
    required String message,
  }) {
    try {
      String formattedNumber = _formatPhoneNumber(phoneNumber);

      http
          .post(
        Uri.parse(fonnteApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': fonnteApiKey,
        },
        body: json.encode({
          'target': formattedNumber,
          'message': message,
          'countryCode': '62',
        }),
      )
          .timeout(const Duration(seconds: 15))
          .then((response) {
        if (response.statusCode == 200) {
          debugPrint('✅ WhatsApp sent successfully');
        } else {
          debugPrint(
              '⚠️ WhatsApp send failed: ${response.statusCode} - ${response.body}');
        }
      }).catchError((e) {
        debugPrint('❌ WhatsApp send error: $e');
      });
    } catch (e) {
      debugPrint('❌ WhatsApp prepare error: $e');
    }
  }

  // ============================================================================
  // HELPER: FORMAT PHONE NUMBER
  // ============================================================================

  String _formatPhoneNumber(String phoneNumber) {
    String formatted = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (formatted.startsWith('0')) {
      formatted = '62${formatted.substring(1)}';
    }
    if (!formatted.startsWith('62')) {
      formatted = '62$formatted';
    }

    return formatted;
  }

  // ============================================================================
  // HELPER: BUILD MESSAGES
  // ============================================================================

  String _buildSubmissionMessage({
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String ratePerHour,
    required String urgensi,
    required bool isOutsideRadius,
  }) {
    return '''
👤 Pengawas: $pengawasNama ($fungsi)
👥 Mitra: $jumlahMitra orang
📅 Tanggal: $tanggal
💰 Biaya: $totalBiaya
💵 Rate/Jam: $ratePerHour
⚡ Urgensi: ${urgensi.toUpperCase()}
${isOutsideRadius ? '⚠️ LOKASI LUAR RADIUS' : ''}
''';
  }

  String _buildSubmissionWaMessage({
    required String managerName,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String ratePerHour,
    required String urgensi,
    required bool isOutsideRadius,
    required String shortGroupId,
    required String groupId,
  }) {
    return '''
🔔 *PENGAJUAN LEMBUR BARU*
━━━━━━━━━━━━━━━━━━━

Yth. Bapak/Ibu *$managerName*

Ada pengajuan lembur baru yang membutuhkan persetujuan:

👤 *Pengawas:* $pengawasNama
🏢 *Fungsi:* ${fungsi.toUpperCase()}
👥 *Mitra:* $jumlahMitra orang
📅 *Tanggal:* $tanggal
💰 *Estimasi Biaya:* $totalBiaya
💵 *Rate/Jam:* $ratePerHour
⚡ *Urgensi:* ${urgensi.toUpperCase()}
📍 *Status:* ${isOutsideRadius ? '⚠️ LUAR RADIUS' : '✅ DALAM RADIUS'}

━━━━━━━━━━━━━━━━━━━
*ID Pengajuan:* $shortGroupId...
*Status:* Menunggu Persetujuan
━━━━━━━━━━━━━━━━━━━

🔗 *Link Approve:*
https://otp-pge.web.app/approval/$groupId

Silakan login ke aplikasi untuk melakukan persetujuan.

Terima kasih.
''';
  }

  String _buildApprovalResultWaMessage({
    required String recipientName,
    required bool isApproved,
    required String approverName,
    required String approverRole,
    String? spklNomor,
    required String groupId,
    required String notes,
    required String tanggal,
    required String waktu,
  }) {
    if (isApproved) {
      return '''
✅ *PENGAJUAN LEMBUR DISETUJUI*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

Pengajuan lembur kamu telah *DISETUJUI*!

📄 *No SPKL:* ${spklNomor ?? '-'}
👤 *Approver:* $approverName ($approverRole)
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu

${notes.isNotEmpty ? '📝 *Catatan:* $notes' : ''}

🔗 Lihat SPKL di aplikasi:
https://otp-pge.web.app/spkl/$groupId

Terima kasih.
''';
    } else {
      return '''
❌ *PENGAJUAN LEMBUR DITOLAK*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

Pengajuan lembur kamu *DITOLAK*.

👤 *Approver:* $approverName ($approverRole)
📝 *Alasan:* $notes

Silakan revisi dan ajukan kembali.

🔗 Buka aplikasi:
https://otp-pge.web.app/ajukan-lembur
''';
    }
  }

  String _buildMitraAssignmentWaMessage({
    required String recipientName,
    String? spklNomor,
    required String pengawasNama,
    required String fungsi,
    required String tanggal,
    required String waktu,
    required String lokasi,
    required String groupId,
  }) {
    return '''
📋 *JADWAL LEMBUR BARU*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

Kamu ditugaskan untuk lembur!

📄 *No SPKL:* ${spklNomor ?? '-'}
👤 *Pengawas:* $pengawasNama
🏢 *Fungsi:* ${fungsi.toUpperCase()}
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

━━━━━━━━━━━━━━━━━━━
⚠️ *Wajib:* Lakukan absensi sebelum dan sesudah lembur
━━━━━━━━━━━━━━━━━━━

🔗 Lihat SPKL di aplikasi:
https://otp-pge.web.app/spkl/$groupId

Terima kasih.
''';
  }
}