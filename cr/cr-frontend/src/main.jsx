import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router';
import { OxygenUIThemeProvider } from '@wso2/oxygen-ui';
import { AsgardeoProvider } from '@asgardeo/react';
import theme from './theme';
import { asgardeoConfig, isAsgardeoEnabled } from './config/auth';
import { AuthProvider } from './auth/AuthContext';
import App from './App.jsx';

// Force light mode
document.documentElement.setAttribute('data-color-scheme', 'light');
document.documentElement.setAttribute('data-mui-color-scheme', 'light');
document.documentElement.style.colorScheme = 'light';
localStorage.setItem('mui-mode', 'light');

function AppWithAuth() {
  if (isAsgardeoEnabled) {
    return (
      <AsgardeoProvider {...asgardeoConfig}>
        <AuthProvider>
          <App />
        </AuthProvider>
      </AsgardeoProvider>
    );
  }

  return (
    <AuthProvider>
      <App />
    </AuthProvider>
  );
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter>
      <OxygenUIThemeProvider theme={theme} defaultMode="light" modeStorageKey={null}>
        <AppWithAuth />
      </OxygenUIThemeProvider>
    </BrowserRouter>
  </StrictMode>
);
