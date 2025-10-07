// Firestore data schema for Institution Payment System
// This file defines the structure of documents stored in Firestore

// Institution Registration Schema
class InstitutionRegistrationSchema {
  static const String collectionName = 'institutions';
  static const String studentsSubcollection = 'students';
  static const String paymentsSubcollection = 'payments';
  static const String roomsSubcollection = 'rooms';
  
  // Document fields
  static const String id = 'id';
  static const String institutionName = 'institution_name';
  static const String personName = 'person_name';
  static const String phoneNumber = 'phone_number';
  static const String email = 'email';
  static const String status = 'status'; // 'pending', 'approved', 'rejected'
  static const String enabled = 'enabled'; // institution_admin-level enable/disable
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String approvedAt = 'approved_at';
  static const String rejectedAt = 'rejected_at';
  static const String adminNotes = 'admin_notes';
  
  // Generated fields for approved institutions
  static const String uniqueInstitutionId = 'unique_institution_id';
  static const String loginCredentials = 'login_credentials';
  
  // Possible status values
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
}

// Student Schema (stored in subcollection under each institution)
class StudentSchema {
  static const String id = 'id';
  static const String instId = 'inst_id';
  static const String firstName = 'first_name';
  static const String lastName = 'last_name';
  static const String phoneNumber = 'phone_number';
  static const String email = 'email';
  static const String aadhaar = 'aadhaar';
  static const String photoUrl = 'photo_url'; // optional
  static const String parentName = 'parent_name';
  static const String parentPhone = 'parent_phone';
  static const String address = 'address';
  static const String occupation = 'occupation';
  static const String collegeCourseClass = 'college_course_class';
  static const String termsAccepted = 'terms_accepted';
  static const String status = 'status'; // 'pending', 'approved', 'disabled'
  static const String enabled = 'enabled';
  static const String loginCredentials = 'login_credentials'; // {username: phone, password: temp}
  static const String feeAmount = 'fee_amount'; // amount set by institution_admin for the student
  static const String feeType = 'fee_type'; // 'recurring' | 'one_time'
  static const String feeDueDate = 'fee_due_date'; // Timestamp (next due or one-time due)
  static const String roomNumber = 'room_number'; // optional
  static const String bedNumber = 'bed_number'; // optional
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  // Disable/enable metadata
  static const String disabledReason = 'disabled_reason';
  static const String disabledAt = 'disabled_at';
  static const String reenabledAt = 'reenabled_at';

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusDisabled = 'disabled';

  // Fee type values
  static const String feeTypeRecurring = 'recurring';
  static const String feeTypeOneTime = 'one_time';

  // Accommodation preferences
  static const String foodPlan = 'food_plan'; // 'with' | 'without'
  static const String roomCategory = 'room_category'; // 'single' | 'two_sharing' | 'three_sharing' | 'four_sharing'
}

// Payments Schema (subcollection under institution)
class PaymentSchema {
  static const String id = 'id';
  static const String studentId = 'student_id';
  static const String instId = 'inst_id';
  static const String amount = 'amount';
  static const String status = 'status'; // 'paid', 'pending'
  static const String method = 'method'; // 'cash' | 'upi' | 'netbanking' | 'online'
  static const String receiptNo = 'receipt_no';
  static const String paidAt = 'paid_at';
  static const String createdAt = 'created_at';
  static const String roomNumber = 'room_number';
  // Linkage to a specific fee/charge item
  static const String feeItemId = 'fee_item_id';
  static const String feeLabel = 'fee_label'; // e.g., 'Monthly Fee Aug 2025' or custom reason
  // Optional submission fields (when submitted by student for confirmation)
  static const String note = 'note';
  static const String proofUrl = 'proof_url';
  static const String submittedBy = 'submitted_by'; // 'student' | 'institution_admin'
}

// Student fee/charges schema (subcollection under each student)
class FeeItemSchema {
  static const String subcollectionName = 'fees';
  static const String id = 'id';
  static const String instId = 'inst_id';
  static const String studentId = 'student_id';
  static const String type = 'type'; // 'monthly' | 'other'
  static const String label = 'label'; // Reason or generated label
  static const String amount = 'amount';
  static const String month = 'month'; // 1-12 for monthly
  static const String year = 'year'; // e.g., 2025
  static const String dueDate = 'due_date';
  static const String status = 'status'; // 'pending' | 'to_confirm' | 'paid'
  static const String paymentId = 'payment_id'; // when paid
  static const String recurring = 'recurring'; // true for recurring monthly
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  // Payment submission meta (when student submits for confirmation)
  static const String submissionNote = 'submission_note';
  static const String submissionProofUrl = 'submission_proof_url';
  static const String submissionMethod = 'submission_method'; // 'cash' | 'upi' | 'netbanking'
  static const String submittedBy = 'submitted_by'; // 'student' | 'institution_admin'
  static const String submittedAt = 'submitted_at';
  // Soft delete metadata (keep entry visible but excluded from totals)
  static const String deleted = 'deleted';
  static const String deletedReason = 'deleted_reason';
  static const String deletedAt = 'deleted_at';

  static const String typeMonthly = 'monthly';
  static const String typeOther = 'other';
}

// Accommodation: Rooms and Beds
class RoomSchema {
  static const String collectionName = 'rooms'; // institutions/{instId}/rooms
  static const String id = 'id';
  static const String roomNumber = 'room_number';
  static const String category = 'category'; // legacy optional: 'single' | 'two_sharing' | 'three_sharing' | 'four_sharing'
  static const String capacity = 'capacity';
  static const String floorNumber = 'floor_number';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class BedSchema {
  static const String subcollectionName = 'beds'; // institutions/{instId}/rooms/{roomId}/beds
  static const String id = 'id';
  static const String bedNumber = 'bed_number'; // 1..capacity
  static const String occupied = 'occupied';
  static const String studentId = 'student_id'; // when occupied
  static const String assignedAt = 'assigned_at';
}

// Food pricing configuration per institution
class AccommodationPricingSchema {
  static const String collectionName = 'accommodation_config'; // institutions/{instId}/accommodation_config
  static const String pricingDocId = 'pricing';
  static const String withFood = 'with_food'; // Map of category -> amount
  static const String withoutFood = 'without_food'; // Map of category -> amount
  static const String updatedAt = 'updated_at';
}

// Complaints Schema (subcollection under institution)
class ComplaintSchema {
  static const String collectionName = 'complaints'; // institutions/{instId}/complaints
  static const String id = 'id';
  static const String studentId = 'student_id';
  static const String studentName = 'student_name'; // denormalized for quick listing
  static const String roomNumber = 'room_number'; // denormalized
  static const String subject = 'subject';
  static const String message = 'message';
  static const String status = 'status'; // 'no_action' | 'acknowledged' | 'in_progress' | 'resolved'
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

// Admin Configuration Schema
class AdminConfigSchema {
  static const String collectionName = 'admin_config';
  
  // Document fields
  static const String institutionIdCounter = 'institution_id_counter';
  static const String lastUpdated = 'last_updated';
}

// Support Tickets (top-level collection)
class SupportTicketSchema {
  static const String collectionName = 'support_tickets';
  static const String id = 'id';
  static const String instId = 'inst_id';
  static const String subject = 'subject';
  static const String description = 'description';
  static const String category = 'category'; // complaint | feedback | suggestion | technical | enhancement | feature | other
  static const String priority = 'priority'; // low | medium | high | urgent
  static const String status = 'status'; // new | acknowledged | in_progress | resolved | closed | reopened
  static const String assignee = 'assignee'; // admin identifier or email
  static const String createdByRole = 'created_by_role'; // institution_admin
  static const String createdByName = 'created_by_name';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String attachmentUrls = 'attachment_urls'; // List<String>

  static const String statusNew = 'new';
  static const String statusAcknowledged = 'acknowledged';
  static const String statusInProgress = 'in_progress';
  static const String statusResolved = 'resolved';
  static const String statusClosed = 'closed';
  static const String statusReopened = 'reopened';
}

class SupportUpdateSchema {
  static const String subcollectionName = 'updates';
  static const String id = 'id';
  static const String authorRole = 'author_role'; // admin | institution_admin
  static const String authorName = 'author_name';
  static const String message = 'message';
  static const String statusChange = 'status_change'; // optional
  static const String attachmentUrls = 'attachment_urls'; // List<String>
  static const String createdAt = 'created_at';
}

// Sample document structure for institutions collection:
/*
{
  "id": "INST-2025-001",
  "institution_name": "XYZ University",
  "person_name": "",
  "phone_number": "+1234567890",
  "email": "info@xyzuniversity.edu",
  "status": "approved",
  "enabled": true,
  "created_at": "TIMESTAMP",
  "updated_at": "TIMESTAMP",
  "approved_at": "TIMESTAMP",
  "rejected_at": null,
  "admin_notes": "",
  "unique_institution_id": "INST-2025-001",
  "login_credentials": {"username": "INST-2025-001", "password": "temp"}
}
*/

// Student example (subcollection: institutions/{instId}/students)
/*
{
  "id": "auto-id",
  "inst_id": "INST-2025-001",
  "first_name": "Alice",
  "last_name": "Lee",
  "phone_number": "+1555123456",
  "email": "alice@example.com",
  "aadhaar": "1234-5678-9012",
  "photo_url": null,
  "parent_name": "Parent",
  "parent_phone": "+15550999",
  "address": "Full address",
  "occupation": "Student",
  "college_course_class": "ABC College, CS, 2nd year",
  "terms_accepted": true,
  "status": "pending",
  "enabled": true,
  "login_credentials": null,
  "fee_amount": 0,
  "room_number": null,
  "bed_number": null,
  "created_at": "TIMESTAMP",
  "updated_at": "TIMESTAMP"
}
*/
