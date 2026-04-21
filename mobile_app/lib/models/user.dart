/// Parses API / Firestore date fields (ISO string, map with `_seconds`, etc.).
DateTime? parseProjectApiDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d;
  }
  if (v is Map) {
    final sec = v['_seconds'] ?? v['seconds'];
    if (sec is num) {
      final ns = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
      final nsNum = ns is num ? ns : (num.tryParse(ns.toString()) ?? 0);
      return DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000 + (nsNum / 1000000).round());
    }
  }
  return null;
}

class User {
  final String id;
  final String name;
  /// Nom affiché lorsque la langue est l’arabe (API: `name_ar` / `nameAr`).
  final String? nameAr;
  final String email;
  final String role;
  final Project? project;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    this.nameAr,
    required this.email,
    required this.role,
    this.project,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      project: json['project'] != null ? Project.fromJson(json['project']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final ar = nameAr?.trim();
    return {
      'id': id,
      'name': name,
      if (ar != null && ar.isNotEmpty) 'nameAr': ar,
      'email': email,
      'role': role,
      'project': project?.toJson(),
      'isActive': isActive,
    };
  }
}

class Project {
  final String id;
  final String name;
  /// Nom affiché lorsque la langue est l’arabe (API: `name_ar` / `nameAr`).
  final String? nameAr;
  final String? description;
  final String? images1;
  final List<String>? users;
  final List<ProjectProduct>? products;
  final String status;
  final String? projectOwner;
  /// صاحب المشروع بالعربية (API: `project_owner_ar` / `projectOwnerAr`).
  final String? projectOwnerAr;
  /// ISO `yyyy-MM-dd` (API: `boqCreationDate` / `boq_creation_date`).
  final String? boqCreationDate;
  /// Default depot/store for distributions (API: `depotId` / `depot_id`).
  final String? depotId;
  /// API: `createdAt` / `created_at`
  final DateTime? createdAt;
  /// API: `updatedAt` / `updated_at`
  final DateTime? updatedAt;
  final List<ProjectHistory>? history;

  Project({
    required this.id,
    required this.name,
    this.nameAr,
    this.description,
    this.images1,
    this.users,
    this.products,
    required this.status,
    this.projectOwner,
    this.projectOwnerAr,
    this.boqCreationDate,
    this.depotId,
    this.createdAt,
    this.updatedAt,
    this.history,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      description: json['description'],
      images1: json['images1']?.toString(),
      users: json['users'] != null ? List<String>.from(json['users']) : null,
      products: json['products'] != null
          ? (json['products'] as List).map((p) => ProjectProduct.fromJson(p)).toList()
          : null,
      status: json['status'] ?? 'active',
      projectOwner: (json['projectOwner'] ?? json['project_owner'])?.toString(),
      projectOwnerAr: (json['projectOwnerAr'] ?? json['project_owner_ar'])?.toString(),
      boqCreationDate: (json['boqCreationDate'] ?? json['boq_creation_date'])?.toString(),
      depotId: json['depotId']?.toString() ?? json['depot_id']?.toString(),
      createdAt: parseProjectApiDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseProjectApiDate(json['updatedAt'] ?? json['updated_at']),
      history: json['history'] != null
          ? (json['history'] as List)
              .map((h) => ProjectHistory.fromJson(Map<String, dynamic>.from(h)))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (nameAr != null && nameAr!.isNotEmpty) 'nameAr': nameAr,
      'description': description,
      'images1': images1,
      'users': users,
      'products': products?.map((p) => p.toJson()).toList(),
      'status': status,
    };
  }
}

class ProjectHistory {
  final String action;
  final DateTime? at;
  final String? byName;
  final String? byEmail;
  final List<String> changes;
  /// Optional product state at this history point (API: `snapshot`).
  final Map<String, dynamic>? snapshot;

  ProjectHistory({
    required this.action,
    this.at,
    this.byName,
    this.byEmail,
    this.changes = const [],
    this.snapshot,
  });

  factory ProjectHistory.fromJson(Map<String, dynamic> json) {
    final by = json['by'];
    final snap = json['snapshot'];
    return ProjectHistory(
      action: (json['action'] ?? 'updated').toString(),
      at: parseProjectApiDate(json['at'] ?? json['createdAt']),
      byName: by is Map ? by['name']?.toString() : null,
      byEmail: by is Map ? by['email']?.toString() : null,
      changes: json['changes'] is List
          ? (json['changes'] as List).map((e) => e.toString()).toList()
          : const [],
      snapshot: snap is Map ? _normalizeHistorySnapshot(Map<String, dynamic>.from(snap)) : null,
    );
  }
}

/// Nested `products` / `products_requested` maps from JSON must be [Map<String, dynamic>]
/// or [snapshot.products] is skipped as non-Map in the UI.
Map<String, dynamic> _normalizeHistorySnapshot(Map<String, dynamic> snap) {
  final out = Map<String, dynamic>.from(snap);
  for (final key in ['products', 'products_requested']) {
    final v = out[key];
    if (v is Map) {
      out[key] = Map<String, dynamic>.from(v);
    }
  }
  return out;
}

class ProjectProduct {
  final String product;
  final String? productName;
  final int allowedQuantity;
  final int requestedQuantity;
  final int supplementaryQuantity;
  final int distributedQuantity;
  final String? color;
  /// ISO date `yyyy-MM-dd` (API: `boqDate` / `boq_date`).
  final String? boqDate;

  ProjectProduct({
    required this.product,
    this.productName,
    required this.allowedQuantity,
    required this.requestedQuantity,
    this.supplementaryQuantity = 0,
    this.distributedQuantity = 0,
    this.color,
    this.boqDate,
  });

  factory ProjectProduct.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    final id = p is Map ? (p['id'] ?? p['_id'] ?? '') : (p?.toString() ?? '');
    final name = p is Map ? p['name'] : null;
    final allowed = json['allowedQuantity'] ?? json['allowed_quantity'] ?? 0;
    return ProjectProduct(
      product: id,
      productName: name?.toString(),
      allowedQuantity: allowed,
      requestedQuantity: json['requestedQuantity'] ?? json['requested_quantity'] ?? allowed,
      supplementaryQuantity: json['supplementaryQuantity'] ?? json['supplementary_quantity'] ?? 0,
      distributedQuantity: json['distributedQuantity'] ?? json['distributed_quantity'] ?? 0,
      color: json['color']?.toString(),
      boqDate: json['boqDate']?.toString() ?? json['boq_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product,
      'allowedQuantity': allowedQuantity,
      if (color != null && color!.isNotEmpty) 'color': color,
      if (boqDate != null && boqDate!.trim().isNotEmpty) 'boqDate': boqDate,
    };
  }
}

