import { authMode } from '../config/auth';

const API_BASE = '/api/fhir/r4';

export class ApiError extends Error {
  status: number;
  statusText: string;
  body: unknown;

  constructor(status: number, statusText: string, body: unknown) {
    super(`API Error ${status}: ${statusText}`);
    this.status = status;
    this.statusText = statusText;
    this.body = body;
  }
}

export async function fetchApi(path: string, options: RequestInit = {}): Promise<unknown> {
  const token = localStorage.getItem('auth_token');
  const user = localStorage.getItem('auth_user');
  const userEmail = user ? JSON.parse(user).email : null;

  const headers: Record<string, string> = {
    'Content-Type': 'application/fhir+json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(userEmail ? { 'X-User-Id': userEmail } : {}),
    ...(options.headers as Record<string, string> | undefined),
  };

  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    // In Asgardeo mode, redirect to origin so the SDK can handle re-auth.
    // In simulated mode, go to the login page directly.
    window.location.href = authMode === 'oidc' ? '/' : '/login';
    throw new ApiError(401, 'Unauthorized', null);
  }

  if (response.status === 204) {
    return null;
  }

  const body = await response.json().catch(() => null);

  if (!response.ok) {
    throw new ApiError(response.status, response.statusText, body);
  }

  return body;
}

// Returns the raw fetch Response so the caller can read status, headers, and body.
// Used for FHIR async endpoints (dedupstart, dedupstatus) that return 202 + Content-Location.
export async function fetchApiResponse(path: string, options: RequestInit = {}): Promise<Response> {
  const token = localStorage.getItem('auth_token');
  const user = localStorage.getItem('auth_user');
  const userEmail = user ? JSON.parse(user).email : null;

  const headers: Record<string, string> = {
    'Content-Type': 'application/fhir+json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(userEmail ? { 'X-User-Id': userEmail } : {}),
    ...(options.headers as Record<string, string> | undefined),
  };

  const response = await fetch(`${API_BASE}${path}`, { ...options, headers });

  if (response.status === 401) {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    window.location.href = authMode === 'oidc' ? '/' : '/login';
    throw new ApiError(401, 'Unauthorized', null);
  }

  return response;
}
