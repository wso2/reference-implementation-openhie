import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router';
import { OxygenUIThemeProvider } from '@wso2/oxygen-ui';
import { AuthProvider as OidcProvider } from 'react-oidc-context';
import theme from './theme';
import { oidcConfig, authMode, authConfigError } from './config/auth';
import { AuthProvider } from './auth/AuthContext';
import App from './App';

// Force light mode
document.documentElement.setAttribute('data-color-scheme', 'light');
document.documentElement.setAttribute('data-mui-color-scheme', 'light');
document.documentElement.style.colorScheme = 'light';
localStorage.setItem('mui-mode', 'light');

function AuthConfigError() {
  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: 'monospace',
        background: '#fafafa',
      }}
    >
      <div
        style={{
          maxWidth: 520,
          padding: '2rem',
          border: '1px solid #e0e0e0',
          borderRadius: 8,
          background: '#fff',
        }}
      >
        <p style={{ fontWeight: 700, color: '#c62828', marginTop: 0 }}>
          Auth configuration error
        </p>
        <p style={{ color: '#333', marginBottom: '1.5rem' }}>{authConfigError}</p>
        <p style={{ color: '#666', fontSize: '0.85rem', margin: 0 }}>
          Check your <code>.env</code> file and restart the dev server.
        </p>
      </div>
    </div>
  );
}

function AppWithAuth() {
  if (authConfigError) {
    return <AuthConfigError />;
  }

  if (authMode === 'oidc') {
    return (
      <OidcProvider {...oidcConfig}>
        <AuthProvider>
          <App />
        </AuthProvider>
      </OidcProvider>
    );
  }

  return (
    <AuthProvider>
      <App />
    </AuthProvider>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
      <OxygenUIThemeProvider theme={theme as any}>
        <AppWithAuth />
      </OxygenUIThemeProvider>
    </BrowserRouter>
  </StrictMode>
);
