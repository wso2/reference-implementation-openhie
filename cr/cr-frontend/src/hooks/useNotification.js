import { useState, useCallback, useRef } from 'react';

export function useNotification() {
  const [notification, setNotification] = useState(null);
  const timerRef = useRef(null);

  const showNotification = useCallback((message, severity = 'success') => {
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
