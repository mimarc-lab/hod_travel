import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/enrichment_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/repositories/ai_suggestion_repository.dart';
import '../../data/repositories/run_sheet_repository.dart';
export '../../data/repositories/run_sheet_repository.dart'
    show RunSheetShareRepository;
import '../../data/repositories/signature_experience_repository.dart';
import '../../data/repositories/trip_template_repository.dart';
import '../../data/repositories/client_dossier_repository.dart';
import '../../data/repositories/ai_memory_repository.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/security/permission_service.dart';
import '../../services/audit_log_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// db — convenience shortcut for the Supabase client
// ─────────────────────────────────────────────────────────────────────────────

SupabaseClient get db => Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
// AppRepositories — singleton instantiated once in main() after Supabase.init.
// All providers and screens access repositories through this.
// Null until Supabase is configured — providers fall back to mock data.
// ─────────────────────────────────────────────────────────────────────────────

class AppRepositories {
  static AppRepositories? _instance;

  static AppRepositories? get instance => _instance;

  final SupabaseClient _client;

  /// The authenticated user's ID, or null if not signed in.
  String? get currentUserId => _client.auth.currentUser?.id;

  // ── Session context — set by AuthProvider after sign-in ───────────────────
  /// The active team ID for the current session. Set after team load.
  String? currentTeamId;

  /// The resolved AppUser for the current session (with role populated).
  AppUser? currentAppUser;

  // ── Core ───────────────────────────────────────────────────────────────────
  final AuthRepository auth;
  final ProfileRepository profiles;
  final TeamRepository teams;

  // ── Trips & board ─────────────────────────────────────────────────────────
  final TripRepository trips;
  final TaskRepository tasks;
  final ItineraryRepository itinerary;
  final TripTemplateRepository templates;

  // ── Suppliers ─────────────────────────────────────────────────────────────
  final SupplierRepository suppliers;
  final EnrichmentRepository enrichments;

  // ── Finance ────────────────────────────────────────────────────────────────
  final BudgetRepository budget;

  // ── Experience Library ────────────────────────────────────────────────────
  final SignatureExperienceRepository signatureExperiences;

  // ── AI Suggestions ────────────────────────────────────────────────────────
  final AiSuggestionRepository aiSuggestions;

  // ── Run Sheets ────────────────────────────────────────────────────────────
  final RunSheetRepository      runSheets;
  final RunSheetShareRepository runSheetShares;

  // ── Client Dossiers ───────────────────────────────────────────────────────
  final ClientDossierRepository clientDossiers;

  // ── AI Memory ─────────────────────────────────────────────────────────────
  final AiMemoryRepository aiMemory;

  // ── Security / permissions ────────────────────────────────────────────────
  final PermissionService permissions;
  final AuditLogService    auditLogs;

  // ── Cross-cutting ─────────────────────────────────────────────────────────
  final NotificationRepository notifications;
  final ApprovalRepository approvals;
  final AttachmentRepository attachments;

  AppRepositories._(
    SupabaseClient client, {
    required this.auth,
    required this.profiles,
    required this.teams,
    required this.trips,
    required this.tasks,
    required this.itinerary,
    required this.templates,
    required this.suppliers,
    required this.enrichments,
    required this.budget,
    required this.signatureExperiences,
    required this.aiSuggestions,
    required this.runSheets,
    required this.runSheetShares,
    required this.clientDossiers,
    required this.aiMemory,
    required this.permissions,
    required this.auditLogs,
    required this.notifications,
    required this.approvals,
    required this.attachments,
  }) : _client = client;

  /// Call once in main() after Supabase.initialize() completes.
  static AppRepositories init(SupabaseClient client) {
    final profileRepo = SupabaseProfileRepository(client);
    final teamRepo    = SupabaseTeamRepository(client);

    _instance = AppRepositories._(
      client,
      auth:         SupabaseAuthRepository(
                      client: client,
                      profiles: profileRepo,
                      teams: teamRepo,
                    ),
      profiles:     profileRepo,
      teams:        teamRepo,
      trips:        SupabaseTripRepository(client),
      tasks:        SupabaseTaskRepository(client),
      itinerary:    SupabaseItineraryRepository(client),
      templates:    SupabaseTripTemplateRepository(client),
      suppliers:    SupabaseSupplierRepository(client),
      enrichments:  SupabaseEnrichmentRepository(client),
      budget:               SupabaseBudgetRepository(client),
      signatureExperiences: SupabaseSignatureExperienceRepository(client),
      aiSuggestions:        SupabaseAiSuggestionRepository(client),
      runSheets:            SupabaseRunSheetRepository(client),
      runSheetShares:       SupabaseRunSheetShareRepository(client),
      clientDossiers:       SupabaseClientDossierRepository(client),
      aiMemory:             SupabaseAiMemoryRepository(client),
      permissions:          PermissionService(client),
      auditLogs:            AuditLogService(client),
      notifications:        SupabaseNotificationRepository(client),
      approvals:    SupabaseApprovalRepository(client),
      attachments:  SupabaseAttachmentRepository(client),
    );
    return _instance!;
  }
}
