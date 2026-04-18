// =============================================================================
// AttachmentRecord — metadata for a file stored in Supabase Storage.
// Polymorphic: related_table + related_id point to any entity.
// The actual file lives in Supabase Storage at file_path.
// =============================================================================

class AttachmentRecord {
  final String id;
  final String teamId;
  final String relatedTable; // 'tasks' | 'suppliers' | 'itinerary_items' | 'cost_items'
  final String relatedId;
  final String fileName;
  final String filePath;    // Supabase Storage path
  final String? fileType;   // MIME type
  final String? uploadedBy; // profile id
  final DateTime createdAt;

  const AttachmentRecord({
    required this.id,
    required this.teamId,
    required this.relatedTable,
    required this.relatedId,
    required this.fileName,
    required this.filePath,
    this.fileType,
    this.uploadedBy,
    required this.createdAt,
  });

  factory AttachmentRecord.fromMap(Map<String, dynamic> m) => AttachmentRecord(
        id:           m['id'] as String,
        teamId:       m['team_id'] as String,
        relatedTable: m['related_table'] as String,
        relatedId:    m['related_id'] as String,
        fileName:     m['file_name'] as String,
        filePath:     m['file_path'] as String,
        fileType:     m['file_type'] as String?,
        uploadedBy:   m['uploaded_by'] as String?,
        createdAt:    DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'team_id':       teamId,
        'related_table': relatedTable,
        'related_id':    relatedId,
        'file_name':     fileName,
        'file_path':     filePath,
        'file_type':     fileType,
        'uploaded_by':   uploadedBy,
      };

  /// True for common image MIME types.
  bool get isImage {
    final t = fileType?.toLowerCase() ?? '';
    return t.startsWith('image/');
  }

  /// True for PDF files.
  bool get isPdf => fileType?.toLowerCase() == 'application/pdf';
}
