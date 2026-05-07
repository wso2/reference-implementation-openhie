import { extendTheme } from '@mui/material/styles';
import { OxygenTheme } from '@wso2/oxygen-ui';

const lightPalette = {
  primary: {
    main: '#3b82f6',
    light: '#60a5fa',
    dark: '#2563eb',
    contrastText: '#ffffff',
  },
  secondary: {
    main: '#1e293b',
    light: '#334155',
    dark: '#0f172a',
    contrastText: '#ffffff',
  },
  success: {
    main: '#059669',
    light: '#dcfce7',
    dark: '#166534',
    contrastText: '#ffffff',
  },
  error: {
    main: '#dc2626',
    light: '#fee2e2',
    dark: '#991b1b',
    contrastText: '#ffffff',
  },
  warning: {
    main: '#d97706',
    light: '#fef3c7',
    dark: '#92400e',
    contrastText: '#ffffff',
  },
  info: {
    main: '#3b82f6',
    light: '#dbeafe',
    dark: '#1e40af',
  },
  background: {
    default: '#f8fafc',
    paper: '#ffffff',
  },
  text: {
    primary: '#1e293b',
    secondary: '#64748b',
    disabled: '#94a3b8',
  },
  divider: '#e2e8f0',
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const theme = extendTheme(OxygenTheme as any, {
  defaultColorScheme: 'light',
  colorSchemes: {
    light: { palette: lightPalette },
    dark: { palette: lightPalette }, // Force light colors even in dark mode
  },
  shape: {
    borderRadius: 10,
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          padding: '10px 20px',
          fontSize: '14px',
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          border: '1px solid #e2e8f0',
          boxShadow: 'none',
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          borderRadius: 12,
        },
      },
    },
    MuiTextField: {
      defaultProps: {
        size: 'small',
        variant: 'outlined',
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          fontWeight: 600,
          fontSize: '11px',
          borderRadius: 6,
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          boxShadow: 'none',
        },
      },
    },
  },
});

export default theme;
