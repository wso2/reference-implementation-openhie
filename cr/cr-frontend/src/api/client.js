import { isAsgardeoEnabled } from '../config/auth';

const API_BASE = '/api/fhir/r4';

export class ApiError extends Error {
  constructor(status, statusText, body) {
    super(`API Error ${status}: ${statusText}`);
    this.status = status;
    this.statusText = statusText;
    this.body = body;
  }
}

export async function fetchApi(path, options = {}) {
  const token = localStorage.getItem('auth_token');
  const user = localStorage.getItem('auth_user');
  const userEmail = user ? JSON.parse(user).email : null;

  const headers = {
    'Content-Type': 'application/fhir+json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(userEmail ? { 'X-User-Id': userEmail } : {}),
    ...options.headers,
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
    window.location.href = isAsgardeoEnabled ? '/' : '/login';
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
