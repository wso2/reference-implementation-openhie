import { useState, useCallback, useRef } from 'react';
import type { Notification, NotificationSeverity } from '../types';

export function useNotification() {
  const [notification, setNotification] = useState<Notification | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showNotification = useCallback((message: string, severity: NotificationSeverity = 'success') => {
    if (timerRef.current) clearTimeout(timerRef.current);
    setNotification({ message, severity });
    timerRef.current = setTimeout(() => setNotification(null), 4000);
  }, []);

  const dismissNotification = useCallback(() => {
    if (timerRef.current) clearTimeout(timerRef.current);
    setNotification(null);
  }, []);

  return { notification, showNotification, dismissNotification };
}
