import { Snackbar, Alert } from '@wso2/oxygen-ui';

export default function NotificationSnackbar({
  notification,
  onDismiss,
}) {
  if (!notification) return null;

  return (
    <Snackbar
      open={!!notification}
      autoHideDuration={4000}
      onClose={onDismiss}
      anchorOrigin={{ vertical: 'top', horizontal: 'right' }}
    >
      <Alert
        onClose={onDismiss}
        severity={notification.severity}
        variant="filled"
        sx={{ width: '100%' }}
      >
        {notification.message}
      </Alert>
    </Snackbar>
  );
}
