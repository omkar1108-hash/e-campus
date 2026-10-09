/// Small data classes for the campus features: notices, emergency alerts,
/// timetable, assignments, attendance, complaints and the activity log.
library;

DateTime _time(Object? ms) =>
    DateTime.fromMillisecondsSinceEpoch(((ms ?? 0) as num).toInt());

// ---- Notices ------------------------------------------------------------
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.authorName,
    required this.createdAt,
    this.image,
    this.public = false,
  });

  final String id;
  final String title;
  final String body;
  final String authorName;
  final DateTime createdAt;
  final String? image;

  /// Public notices also appear on the opening page, before sign-in.
  final bool public;

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'authorName': authorName,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'public': public,
    if (image != null) 'image': image,
  };

  factory Notice.fromMap(String id, Map<String, dynamic> m) => Notice(
    id: id,
    title: (m['title'] ?? '') as String,
    body: (m['body'] ?? '') as String,
    authorName: (m['authorName'] ?? '') as String,
    createdAt: _time(m['createdAt']),
    image: m['image'] as String?,
    public: (m['public'] ?? false) as bool,
  );
}

// ---- Emergency alerts ---------------------------------------------------
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.message,
    required this.authorName,
    required this.createdAt,
    this.active = true,
  });

  final String id;
  final String message;
  final String authorName;
  final DateTime createdAt;
  final bool active;

  Map<String, dynamic> toMap() => {
    'message': message,
    'authorName': authorName,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'active': active,
  };

  factory EmergencyAlert.fromMap(String id, Map<String, dynamic> m) =>
      EmergencyAlert(
        id: id,
        message: (m['message'] ?? '') as String,
        authorName: (m['authorName'] ?? '') as String,
        createdAt: _time(m['createdAt']),
        active: (m['active'] ?? false) as bool,
      );
}

// ---- Timetable ----------------------------------------------------------
const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// "Mon".."Sat" for [d], or null on Sunday.
String? weekDayName(DateTime d) =>
    d.weekday <= 6 ? weekDays[d.weekday - 1] : null;

class TimetableSlot {
  const TimetableSlot({
    required this.day,
    required this.start,
    required this.end,
    required this.subject,
    this.teacherUid = '',
    this.teacherName = '',
    this.room = '',
  });

  final String day; // Mon..Sat
  final String start; // HH:mm
  final String end;
  final String subject;
  final String teacherUid;
  final String teacherName;
  final String room;

  Map<String, dynamic> toMap() => {
    'day': day,
    'start': start,
    'end': end,
    'subject': subject,
    'teacherUid': teacherUid,
    'teacherName': teacherName,
    'room': room,
  };

  factory TimetableSlot.fromMap(Map<String, dynamic> m) => TimetableSlot(
    day: (m['day'] ?? 'Mon') as String,
    start: (m['start'] ?? '') as String,
    end: (m['end'] ?? '') as String,
    subject: (m['subject'] ?? '') as String,
    teacherUid: (m['teacherUid'] ?? '') as String,
    teacherName: (m['teacherName'] ?? '') as String,
    room: (m['room'] ?? '') as String,
  );

  /// Sorting key: day then start time.
  int get order => weekDays.indexOf(day) * 10000 + _minutes(start);

  static int _minutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  static bool validTime(String s) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s);
}

/// A slot together with the department whose timetable it belongs to.
class DeptSlot {
  const DeptSlot(this.department, this.slot);
  final String department;
  final TimetableSlot slot;
}

// ---- Assignments & notes --------------------------------------------------
enum WorkKind {
  assignment('Assignment'),
  note('Notes');

  const WorkKind(this.label);
  final String label;

  static WorkKind fromName(String? n) => WorkKind.values.firstWhere(
    (k) => k.name == n,
    orElse: () => WorkKind.note,
  );
}

class Assignment {
  const Assignment({
    required this.id,
    required this.kind,
    required this.department,
    required this.subject,
    required this.title,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.description = '',
    this.link = '',
    this.dueDate,
  });

  final String id;
  final WorkKind kind;
  final String department;
  final String subject;
  final String title;
  final String description;
  final String link;
  final DateTime? dueDate;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'department': department,
    'subject': subject,
    'title': title,
    'description': description,
    'link': link,
    if (dueDate != null) 'dueDate': dueDate!.millisecondsSinceEpoch,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Assignment.fromMap(String id, Map<String, dynamic> m) => Assignment(
    id: id,
    kind: WorkKind.fromName(m['kind'] as String?),
    department: (m['department'] ?? '') as String,
    subject: (m['subject'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    link: (m['link'] ?? '') as String,
    dueDate: m['dueDate'] == null ? null : _time(m['dueDate']),
    createdBy: (m['createdBy'] ?? '') as String,
    createdByName: (m['createdByName'] ?? '') as String,
    createdAt: _time(m['createdAt']),
  );
}

// ---- Attendance ---------------------------------------------------------
class AttendanceRecord {
  const AttendanceRecord({
    required this.studentUid,
    required this.studentName,
    required this.department,
    required this.subject,
    required this.date,
    required this.present,
    required this.teacherUid,
  });

  final String studentUid;
  final String studentName;
  final String department;
  final String subject;

  /// yyyy-MM-dd
  final String date;
  final bool present;
  final String teacherUid;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Document id: one record per student, subject and day, so marking the
  /// same lecture twice corrects it instead of duplicating it.
  String get docId => '${department}_${subject}_${date}_$studentUid'.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '-',
  );

  Map<String, dynamic> toMap() => {
    'studentUid': studentUid,
    'studentName': studentName,
    'department': department,
    'subject': subject,
    'date': date,
    'present': present,
    'teacherUid': teacherUid,
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> m) => AttendanceRecord(
    studentUid: (m['studentUid'] ?? '') as String,
    studentName: (m['studentName'] ?? '') as String,
    department: (m['department'] ?? '') as String,
    subject: (m['subject'] ?? '') as String,
    date: (m['date'] ?? '') as String,
    present: (m['present'] ?? false) as bool,
    teacherUid: (m['teacherUid'] ?? '') as String,
  );
}

class SubjectAttendance {
  const SubjectAttendance(this.subject, this.present, this.total);
  final String subject;
  final int present;
  final int total;
  double get percent => total == 0 ? 0 : present * 100 / total;
}

/// Minimum attendance before a warning is shown.
const attendanceTarget = 75.0;

List<SubjectAttendance> summarizeAttendance(Iterable<AttendanceRecord> rs) {
  final present = <String, int>{};
  final total = <String, int>{};
  for (final r in rs) {
    total[r.subject] = (total[r.subject] ?? 0) + 1;
    if (r.present) present[r.subject] = (present[r.subject] ?? 0) + 1;
  }
  return [
    for (final s in total.keys.toList()..sort())
      SubjectAttendance(s, present[s] ?? 0, total[s]!),
  ];
}

double overallAttendance(Iterable<AttendanceRecord> rs) {
  var p = 0, t = 0;
  for (final r in rs) {
    t++;
    if (r.present) p++;
  }
  return t == 0 ? 0 : p * 100 / t;
}

// ---- Complaints ---------------------------------------------------------
enum ComplaintCategory {
  academic('Academic'),
  library('Library'),
  transport('Transport'),
  facilities('Hostel / facilities'),
  harassment('Harassment / ragging'),
  other('Other');

  const ComplaintCategory(this.label);
  final String label;

  static ComplaintCategory fromName(String? n) => ComplaintCategory.values
      .firstWhere((c) => c.name == n, orElse: () => ComplaintCategory.other);
}

enum ComplaintStatus {
  submitted('Submitted'),
  inReview('In review'),
  resolved('Resolved'),
  rejected('Rejected');

  const ComplaintStatus(this.label);
  final String label;

  bool get isFinal => this == resolved || this == rejected;

  static ComplaintStatus fromName(String? n) => ComplaintStatus.values
      .firstWhere((c) => c.name == n, orElse: () => ComplaintStatus.submitted);

  /// Statuses the committee may move a complaint to from this one.
  List<ComplaintStatus> get next => switch (this) {
    submitted => const [inReview, resolved, rejected],
    inReview => const [resolved, rejected],
    _ => const [],
  };
}

class Complaint {
  const Complaint({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.anonymous,
    required this.displayName,
    required this.displayDepartment,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.filedBy = '',
  });

  final String id;
  final ComplaintCategory category;
  final String subject;
  final String description;
  final bool anonymous;

  /// "Anonymous" or the filer's real name - this is all the committee sees.
  final String displayName;
  final String displayDepartment;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Only known to the filer and the administrator (from the identity doc).
  final String filedBy;

  Map<String, dynamic> toMap() => {
    'category': category.name,
    'subject': subject,
    'description': description,
    'anonymous': anonymous,
    'displayName': displayName,
    'displayDepartment': displayDepartment,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory Complaint.fromMap(String id, Map<String, dynamic> m) => Complaint(
    id: id,
    category: ComplaintCategory.fromName(m['category'] as String?),
    subject: (m['subject'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    anonymous: (m['anonymous'] ?? false) as bool,
    displayName: (m['displayName'] ?? '') as String,
    displayDepartment: (m['displayDepartment'] ?? '') as String,
    status: ComplaintStatus.fromName(m['status'] as String?),
    createdAt: _time(m['createdAt']),
    updatedAt: _time(m['updatedAt']),
    filedBy: (m['filedBy'] ?? '') as String,
  );
}

/// Who really filed a complaint. Readable by the filer and the
/// administrator only - never by the committee for anonymous complaints.
class ComplaintIdentity {
  const ComplaintIdentity({
    required this.id,
    required this.filedBy,
    required this.filedByName,
    required this.filedByDepartment,
    required this.anonymous,
    required this.category,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String filedBy;
  final String filedByName;
  final String filedByDepartment;
  final bool anonymous;
  final ComplaintCategory category;
  final String subject;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'filedBy': filedBy,
    'filedByName': filedByName,
    'filedByDepartment': filedByDepartment,
    'anonymous': anonymous,
    'category': category.name,
    'subject': subject,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory ComplaintIdentity.fromMap(String id, Map<String, dynamic> m) =>
      ComplaintIdentity(
        id: id,
        filedBy: (m['filedBy'] ?? '') as String,
        filedByName: (m['filedByName'] ?? '') as String,
        filedByDepartment: (m['filedByDepartment'] ?? '') as String,
        anonymous: (m['anonymous'] ?? false) as bool,
        category: ComplaintCategory.fromName(m['category'] as String?),
        subject: (m['subject'] ?? '') as String,
        status: ComplaintStatus.fromName(m['status'] as String?),
        createdAt: _time(m['createdAt']),
        updatedAt: _time(m['updatedAt']),
      );
}

class ComplaintReply {
  const ComplaintReply({
    required this.id,
    required this.kind,
    required this.byCommittee,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;

  /// 'reply' or 'status' (an automatic note when the status changes).
  final String kind;
  final bool byCommittee;
  final String authorName;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'kind': kind,
    'byCommittee': byCommittee,
    'authorName': authorName,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ComplaintReply.fromMap(String id, Map<String, dynamic> m) =>
      ComplaintReply(
        id: id,
        kind: (m['kind'] ?? 'reply') as String,
        byCommittee: (m['byCommittee'] ?? false) as bool,
        authorName: (m['authorName'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        createdAt: _time(m['createdAt']),
      );
}

// ---- Activity log -------------------------------------------------------
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.actorName,
    required this.actorRole,
    required this.targetType,
    required this.targetLabel,
    required this.createdAt,
    this.details = '',
  });

  final String id;

  /// e.g. account.created, book.deleted
  final String action;
  final String actorUid;
  final String actorName;
  final String actorRole;
  final String
  targetType; // account | book | news | notice | bus | complaint | alert
  final String targetLabel;
  final String details;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'action': action,
    'actorUid': actorUid,
    'actorName': actorName,
    'actorRole': actorRole,
    'targetType': targetType,
    'targetLabel': targetLabel,
    'details': details,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ActivityEntry.fromMap(String id, Map<String, dynamic> m) =>
      ActivityEntry(
        id: id,
        action: (m['action'] ?? '') as String,
        actorUid: (m['actorUid'] ?? '') as String,
        actorName: (m['actorName'] ?? '') as String,
        actorRole: (m['actorRole'] ?? '') as String,
        targetType: (m['targetType'] ?? '') as String,
        targetLabel: (m['targetLabel'] ?? '') as String,
        details: (m['details'] ?? '') as String,
        createdAt: _time(m['createdAt']),
      );

  /// Plain-English sentence for the admin list.
  String get sentence {
    final who = actorName.isEmpty ? 'Someone' : actorName;
    final what = switch (action) {
      'account.created' => 'created the account of',
      'account.updated' => 'edited the account of',
      'account.disabled' => 'disabled the account of',
      'account.enabled' => 're-enabled the account of',
      'book.deleted' => 'deleted the book',
      'book.approved' => 'approved the book',
      'book.rejected' => 'rejected the book',
      'news.deleted' => 'deleted the news post',
      'notice.deleted' => 'deleted the notice',
      'bus.deleted' => 'deleted the bus',
      'complaint.status' => 'changed the status of complaint',
      'alert.sent' => 'sent an emergency alert:',
      'alert.cleared' => 'cleared the emergency alert:',
      _ => action,
    };
    return '$who $what "$targetLabel"${details.isEmpty ? '' : ' ($details)'}';
  }
}
