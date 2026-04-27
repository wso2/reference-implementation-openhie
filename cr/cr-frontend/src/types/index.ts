// ---------------------------------------------------------------------------
// FHIR Patient resource (R4 subset used by this application)
// ---------------------------------------------------------------------------

export interface FhirName {
  family?: string;
  given?: string[];
}

export interface FhirIdentifier {
  system?: string;
  value: string;
}

export interface FhirTelecom {
  system: 'phone' | 'email' | 'fax' | 'pager' | 'url' | 'sms' | 'other';
  value: string;
}

export interface FhirAddress {
  line?: string[];
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
}

export interface FhirLink {
  type: string;
  other?: {
    identifier?: FhirIdentifier;
  };
}

export interface FhirPatient {
  resourceType: 'Patient';
  id?: string;
  active?: boolean;
  name?: FhirName[];
  identifier?: FhirIdentifier[];
  gender?: 'male' | 'female' | 'other' | 'unknown';
  birthDate?: string;
  telecom?: FhirTelecom[];
  address?: FhirAddress[];
  link?: FhirLink[];
  meta?: {
    lastUpdated?: string;
  };
}

// ---------------------------------------------------------------------------
// Patient search / list params
// ---------------------------------------------------------------------------

export interface PatientSearchParams {
  family?: string;
  given?: string;
  gender?: string;
  birthdate?: string;
  identifier?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
  phone?: string;
  email?: string;
}

export interface ListPatientsParams extends PatientSearchParams {
  page?: number;
  pageSize?: number;
  active?: boolean;
}

export interface ListPatientsResult {
  patients: FhirPatient[];
  total: number;
  page: number;
  pageSize: number;
}

// ---------------------------------------------------------------------------
// Match groups (deduplication)
// ---------------------------------------------------------------------------

export type MatchGrade = 'certain' | 'probable' | 'possible' | 'certainly-not';
export type MatchStatus = 'pending' | 'approved' | 'rejected' | 'resolved';

export interface MatchGroup {
  id: string;
  status: MatchStatus;
  score: number;
  matchGrade: MatchGrade;
  patients: FhirPatient[];
  matchedFields: string[];
  unmatchedFields?: string[];
  createdAt?: string;
  resolvedAt?: string;
  resolvedBy?: string;
  timestamp?: string;
}

export interface MatchResult {
  patient: FhirPatient;
  score: number;
  matchGrade: MatchGrade;
}

export interface DedupResult {
  groups: MatchGroup[];
  timestamp: string;
}

// ---------------------------------------------------------------------------
// Audit log
// ---------------------------------------------------------------------------

export interface AuditEntity {
  reference: string;
  role: string;
}

export interface AuditLogEntry {
  id: string;
  timestamp: string;
  user: string;
  clientIp?: string;
  action: string;
  actionCode?: string;
  details: string;
  entities?: AuditEntity[];
  outcome: 'success' | 'failure';
  reason?: string;
}

export interface AuditLogFilters {
  subtype?: string | null;
  since?: string | null;
  before?: string | null;
  limit?: number;
  offset?: number;
  sortOrder?: 'asc' | 'desc';
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

export type NotificationSeverity = 'success' | 'error' | 'warning' | 'info';

export interface Notification {
  message: string;
  severity: NotificationSeverity;
}

// ---------------------------------------------------------------------------
// User preferences
// ---------------------------------------------------------------------------

export type DateFormat = 'relative' | 'absolute';

export interface UserPreferences {
  defaultPageSize: number;
  dateFormat: DateFormat;
  auditAutoRefresh: boolean;
  auditRefreshInterval: number;
  identifierSystemBaseUrl?: string;
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

export type UserRole = 'admin' | 'viewer';

export interface AuthUser {
  email: string;
  name: string;
  initials: string;
  role: UserRole;
  groups?: string[];
}

export interface AuthContextType {
  user: AuthUser | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  login: (email?: string, password?: string) => Promise<void>;
  logout: () => void;
}
