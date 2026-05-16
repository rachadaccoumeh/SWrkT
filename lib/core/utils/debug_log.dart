import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Debug logger that writes to a rolling file and only outputs in debug mode.
/// Disabled entirely in release builds via `kDebugMode` checks.
class DebugLog {
  DebugLog._();
  static final DebugLog _instance = DebugLog._();
  factory DebugLog() => _instance;

  static DebugLog get instance => _instance;

  File? _logFile;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) await logDir.create(recursive: true);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      _logFile = File('${logDir.path}/swrkt_$timestamp.log');
      await _write('=== SWRkT App Started ===');
      await _write('Version: ${DateTime.now().toIso8601String()}');
    } catch (_) {}
    _initialized = true;
  }

  Future<void> _write(String line) async {
    if (!kDebugMode) return;
    final timestamp = _dateFormat.format(DateTime.now());
    final entry = '[$timestamp] $line';
    debugPrint(entry);
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString('$entry\n', mode: FileMode.append);
      }
    } catch (_) {}
  }

  void log(String tag, String message, {dynamic data}) {
    if (!kDebugMode) return;
    var line = '[$tag] $message';
    if (data != null) line += ' | data: $data';
    _write(line);
  }

  // Convenience methods for common tags
  void auth(String msg, {dynamic data}) => log('AUTH', msg, data: data);
  void sync(String msg, {dynamic data}) => log('SYNC', msg, data: data);
  void db(String msg, {dynamic data}) => log('DB', msg, data: data);
  void ui(String msg, {dynamic data}) => log('UI', msg, data: data);
  void api(String msg, {dynamic data}) => log('API', msg, data: data);
  void error(String msg, {dynamic data}) => log('ERROR', msg, data: data);
  void subs(String msg, {dynamic data}) => log('SUBS', msg, data: data);
  void admin(String msg, {dynamic data}) => log('ADMIN', msg, data: data);
  void info(String msg, {dynamic data}) => log('INFO', msg, data: data);

  /// Returns all log files and their sizes for sharing in settings
  Future<List<Map<String, dynamic>>> getLogFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) return [];
      final files = await logDir.list().toList();
      final logs = <Map<String, dynamic>>[];
      for (final f in files) {
        if (f is File && f.path.endsWith('.log')) {
          final stat = await f.stat();
          logs.add({
            'name': f.path.split('/').last,
            'path': f.path,
            'size': stat.size,
            'modified': stat.modified,
          });
        }
      }
      logs.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
      return logs;
    } catch (_) {
      return [];
    }
  }

  /// Returns the content of the most recent log file
  Future<String> readLatestLog() async {
    try {
      final logs = await getLogFiles();
      if (logs.isEmpty) return 'No logs found';
      final file = File(logs.first['path'] as String);
      final content = await file.readAsString();
      // Return last 100 lines if too long
      final lines = content.split('\n');
      if (lines.length > 100) {
        return '... (showing last 100 of ${lines.length} lines)\n\n' +
            lines.sublist(lines.length - 100).join('\n');
      }
      return content;
    } catch (_) {
      return 'Failed to read logs';
    }
  }

  /// Returns total log size in bytes
  Future<int> totalLogSize() async {
    try {
      final logs = await getLogFiles();
      int total = 0;
      for (final l in logs) total += l['size'] as int;
      return total;
    } catch (_) {
      return 0;
    }
  }
}