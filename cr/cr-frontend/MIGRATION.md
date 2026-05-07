# JSX/JS → TSX/TS Migration Plan

## Overview

Incremental migration ordered by dependency (least dependent → most dependent).
Each step ends with `npm run typecheck` passing before moving to the next.

**Total files: 37**

---

## Step 1 — Config & TypeScript setup ✅ DONE

- Installed `typescript` devDependency
- Created `tsconfig.json` (`allowJs: true`, `strict: false` for incremental migration)
- Created `tsconfig.node.json`
- Renamed `vite.config.js` → `vite.config.ts`
- Added `typecheck` script to `package.json`

---

## Step 2 — Create shared types

Create `src/types/index.ts` with all domain interfaces before touching any source files.

**Types to define:**
- `FhirPatient`, `FhirName`, `FhirIdentifier`, `FhirTelecom`, `FhirAddress`
- `MatchGroup`, `MatchGrade`, `MatchStatus`
- `AuditLogEntry`
- `Notification`, `NotificationSeverity`
- `UserPreferences`
- `AuthUser`, `AuthContextType`

---

## Step 3 — Utilities (`.js` → `.ts`)

No JSX, no deps on other local files. Pure rename + type annotations.

1. `src/utils/formatters.js` → `.ts`
2. `src/utils/matchUtils.js` → `.ts`
3. `src/utils/fhirHelpers.js` → `.ts`
4. `src/theme.js` → `.ts`
5. `src/config/auth.js` → `.ts`

---

## Step 4 — API layer (`.js` → `.ts`)

Depends on types from Step 2. Add typed request/response shapes.

1. `src/api/client.js` → `.ts`
2. `src/api/patientService.js` → `.ts`
3. `src/api/matchService.js` → `.ts`
4. `src/api/auditService.js` → `.ts`

---

## Step 5 — Hooks (`.js` → `.ts`)

Depends on types + API layer.

1. `src/hooks/useNotification.js` → `.ts`
2. `src/hooks/useUserPreferences.js` → `.ts`
3. `src/hooks/usePatients.js` → `.ts`
4. `src/hooks/useMatchGroups.js` → `.ts`
5. `src/hooks/useAuditLog.js` → `.ts`

---

## Step 6 — Auth (`.jsx` → `.tsx`)

Depends on types + hooks.

1. `src/auth/AuthContext.jsx` → `.tsx`
2. `src/auth/ProtectedRoute.jsx` → `.tsx`

---

## Step 7 — Simple/leaf components (`.jsx` → `.tsx`)

No child component imports, straightforward props.

1. `src/components/ScoreCircle.jsx` → `.tsx`
2. `src/components/StatsGrid.jsx` → `.tsx`
3. `src/components/SearchToolbar.jsx` → `.tsx`
4. `src/components/NotificationSnackbar.jsx` → `.tsx`
5. `src/components/PatientDetailsList.jsx` → `.tsx`
6. `src/components/PatientCard.jsx` → `.tsx`

---

## Step 8 — Complex components (`.jsx` → `.tsx`)

Depend on leaf components + hooks.

1. `src/components/PatientViewDialog.jsx` → `.tsx`
2. `src/components/PatientMatchDialog.jsx` → `.tsx`
3. `src/components/PatientFormModal.jsx` → `.tsx`
4. `src/components/PatientInlineEditForm.jsx` → `.tsx`
5. `src/components/PatientSearchPanel.jsx` → `.tsx`
6. `src/components/MergeModal.jsx` → `.tsx`
7. `src/components/MatchGroupCard.jsx` → `.tsx`

---

## Step 9 — Layout & Pages (`.jsx` → `.tsx`)

1. `src/layouts/AppLayout.jsx` → `.tsx`
2. `src/pages/LoginPage.jsx` → `.tsx`
3. `src/pages/ProfileSettingsPage.jsx` → `.tsx`
4. `src/pages/AuditPage.jsx` → `.tsx`
5. `src/pages/PatientsPage.jsx` → `.tsx`
6. `src/pages/DashboardPage.jsx` → `.tsx`

---

## Step 10 — Entry points (`.jsx` → `.tsx`)

1. `src/App.jsx` → `.tsx`
2. `src/main.jsx` → `.tsx`

---

## Step 11 — Tighten TypeScript

Once all files are migrated and `npm run typecheck` is clean:

- Enable `"strict": true` in `tsconfig.json`
- Fix any newly surfaced errors
- Remove `allowJs` and `checkJs` options from `tsconfig.json`
