import type { MatchGrade } from '../types';

interface GradeBadgeStyle {
  bg: string;
  color: string;
  border: string;
}

interface ActionColor {
  bg: string;
  text: string;
}

export const getScoreColor = (score: number): string => {
  if (score >= 0.95) return '#059669';
  if (score >= 0.80) return '#d97706';
  if (score >= 0.60) return '#dc2626';
  return '#6b7280';
};

export const getGradeBadge = (grade: MatchGrade | string): GradeBadgeStyle => {
  const styles: Record<string, GradeBadgeStyle> = {
    certain: { bg: '#dcfce7', color: '#166534', border: '#86efac' },
    probable: { bg: '#fef3c7', color: '#92400e', border: '#fcd34d' },
    possible: { bg: '#fee2e2', color: '#991b1b', border: '#fca5a5' },
  };
  return styles[grade] || styles.possible;
};

export const getActionColor = (action: string): ActionColor => {
  const colors: Record<string, ActionColor> = {
    READ: { bg: '#dbeafe', text: '#1e40af' },
    SEARCH: { bg: '#e0e7ff', text: '#3730a3' },
    CREATE: { bg: '#dcfce7', text: '#166534' },
    UPDATE: { bg: '#fef3c7', text: '#92400e' },
    DELETE: { bg: '#fee2e2', text: '#991b1b' },
    MATCH_APPROVED: { bg: '#dcfce7', text: '#166534' },
    MATCH_REJECTED: { bg: '#fee2e2', text: '#991b1b' },
    MATCH_CREATED: { bg: '#dbeafe', text: '#1e40af' },
    PATIENT_UPDATED: { bg: '#fef3c7', text: '#92400e' },
    PATIENT_CREATED: { bg: '#e0e7ff', text: '#3730a3' },
    DEDUP_RUN: { bg: '#f3e8ff', text: '#6b21a8' },
  };
  return colors[action] || { bg: '#f3f4f6', text: '#374151' };
};
