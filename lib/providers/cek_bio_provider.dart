import 'package:flutter/material.dart';
import '../models/cek_bio_models.dart';
import '../services/cek_bio_service.dart';

class CekBioProvider extends ChangeNotifier {
  CekBioInputMethod? _method;
  List<String> _rawNumbers = [];
  List<CekBioNumberResult> _results = [];
  CekBioStatistics? _statistics;
  CekBioStatus _status = CekBioStatus.idle;
  double _progress = 0;
  String? _errorMessage;
  String? _jobId;

  CekBioInputMethod? get method => _method;
  List<String> get rawNumbers => _rawNumbers;
  List<CekBioNumberResult> get results => _results;
  CekBioStatistics? get statistics => _statistics;
  CekBioStatus get status => _status;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String? get jobId => _jobId;

  int get totalInput => _rawNumbers.where((e) => e.trim().isNotEmpty).length;
  int get validCount => _results.where((r) => r.formatValid).length;
  int get invalidCount => _results.where((r) => !r.formatValid).length;

  void setMethod(CekBioInputMethod method) {
    _method = method;
    notifyListeners();
  }

  void setNumbersFromText(String text) {
    _rawNumbers = text.split(RegExp(r'[\r\n]+')).where((e) => e.trim().isNotEmpty).toList();
    notifyListeners();
  }

  void setNumbersFromFile(String content) {
    _rawNumbers = content.split(RegExp(r'[\r\n]+')).where((e) => e.trim().isNotEmpty).toList();
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_status == CekBioStatus.scanning) return;

    _status = CekBioStatus.scanning;
    _progress = 0;
    _results = [];
    _statistics = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobId = await CekBioService.startScan(_rawNumbers);
      final job = await CekBioService.pollUntilFinished(
        _jobId!,
        onProgress: (job) {
          _progress = job.progress;
          notifyListeners();
        },
      );

      if (job.status == 'error') {
        _status = CekBioStatus.error;
        _errorMessage = job.errorMessage ?? 'Scan gagal';
      } else {
        _results = job.result;
        _statistics = job.statistics;
        _status = CekBioStatus.done;
      }
    } catch (err) {
      _status = CekBioStatus.error;
      _errorMessage = err.toString();
    }

    notifyListeners();
  }

  String? get downloadUrl => _jobId != null ? CekBioService.downloadUrl(_jobId!) : null;

  void reset() {
    _method = null;
    _rawNumbers = [];
    _results = [];
    _statistics = null;
    _status = CekBioStatus.idle;
    _progress = 0;
    _errorMessage = null;
    _jobId = null;
    notifyListeners();
  }
}
