import 'package:flutter/foundation.dart';
import '../../../data/models/signature_experience.dart';
import '../../../data/repositories/signature_experience_repository.dart';

class SignatureExperienceProvider extends ChangeNotifier {
  final SignatureExperienceRepository? _repo;
  final String _teamId;

  List<SignatureExperience> _experiences = [];
  bool _isLoading = false;
  String? _error;

  SignatureExperienceProvider({
    SignatureExperienceRepository? repository,
    required String teamId,
  })  : _repo = repository,
        _teamId = teamId {
    _loadInitial();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<SignatureExperience> get experiences => List.unmodifiable(_experiences);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    if (_repo == null || _teamId.isEmpty) return;
    await reload();
  }

  Future<void> reload() async {
    if (_repo == null || _teamId.isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _experiences = await _repo.fetchAll(_teamId);
    } catch (_) {
      _error = 'Could not load experiences. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<SignatureExperience?> add(SignatureExperience experience) async {
    if (_repo == null || _teamId.isEmpty) return null;
    try {
      final created = await _repo.create(experience, _teamId);
      _experiences.insert(0, created);
      notifyListeners();
      return created;
    } catch (e, st) {
      debugPrint('[SignatureExperienceProvider.add] ERROR: $e\n$st');
      _error = 'Could not save experience. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<SignatureExperience?> update(SignatureExperience experience) async {
    if (_repo == null || _teamId.isEmpty) return null;
    try {
      final updated = await _repo.update(experience);
      final idx = _experiences.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _experiences[idx] = updated;
      } else {
        _experiences.insert(0, updated);
      }
      notifyListeners();
      return updated;
    } catch (e, st) {
      debugPrint('[SignatureExperienceProvider.update] ERROR: $e\n$st');
      _error = 'Could not update experience. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(String id) async {
    if (_repo == null || _teamId.isEmpty) return false;
    try {
      await _repo.delete(id);
      _experiences.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('[SignatureExperienceProvider.delete] ERROR: $e\n$st');
      _error = 'Could not delete experience. Please try again.';
      notifyListeners();
      return false;
    }
  }

  SignatureExperience? findById(String id) {
    try {
      return _experiences.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Filtered views ─────────────────────────────────────────────────────────

  List<SignatureExperience> get flagshipExperiences =>
      _experiences.where((e) => e.status == ExperienceStatus.flagship).toList();

  List<SignatureExperience> get activeExperiences => _experiences
      .where((e) =>
          e.status == ExperienceStatus.approved ||
          e.status == ExperienceStatus.flagship)
      .toList();
}
