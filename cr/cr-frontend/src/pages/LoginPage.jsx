import { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router';
import {
  Box,
  Paper,
  TextField,
  Button,
  Typography,
  Alert,
  CircularProgress,
} from '@wso2/oxygen-ui';
import { Database, LogIn } from 'lucide-react';
import { useAuth } from '../auth/AuthContext';
import { authMode } from '../config/auth';

export default function LoginPage() {
  const { login, isAuthenticated, isLoading, error } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const from = location.state?.from?.pathname || '/dashboard';

  // If already authenticated, redirect immediately
  useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true });
    }
  }, [isAuthenticated, from, navigate]);

  if (authMode === 'oidc') {
    return <AsgardeoLoginPage login={login} isLoading={isLoading} error={error} />;
  }
  return <SimulatedLoginPage login={login} from={from} />;
}

// ---------------------------------------------------------------------------
// Asgardeo login — single button that redirects to Asgardeo hosted login
// ---------------------------------------------------------------------------
function AsgardeoLoginPage({ login, isLoading, error }) {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'background.default',
      }}
    >
      <Paper
        elevation={0}
        sx={{
          p: 4,
          width: '100%',
          maxWidth: 400,
          border: '1px solid',
          borderColor: 'divider',
          textAlign: 'center',
        }}
      >
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            gap: 1.5,
            mb: 3,
            justifyContent: 'center',
          }}
        >
          <Database size={32} style={{ color: 'var(--mui-palette-primary-main)' }} />
          <Typography variant="h5" sx={{ fontWeight: 700 }}>
            Client Registry
          </Typography>
        </Box>

        <Typography
          variant="body2"
          color="text.secondary"
          sx={{ mb: error ? 2 : 4 }}
        >
          Sign in to access the MPI Administration Dashboard
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 2, textAlign: 'left' }}>
            {error}
          </Alert>
        )}

        <Button
          variant="contained"
          fullWidth
          disabled={isLoading}
          onClick={() => login()}
          startIcon={isLoading ? <CircularProgress size={20} color="inherit" /> : <LogIn size={20} />}
          sx={{ py: 1.5 }}
        >
          {isLoading ? 'Redirecting...' : 'Sign in with Asgardeo'}
        </Button>
      </Paper>
    </Box>
  );
}

// ---------------------------------------------------------------------------
// Simulated login — email/password form (dev mode)
// ---------------------------------------------------------------------------
function SimulatedLoginPage({ login, from }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Please enter both email and password');
      return;
    }

    setLoading(true);
    setError('');
    try {
      await login(email, password);
      navigate(from, { replace: true });
    } catch (err) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'background.default',
      }}
    >
      <Paper
        elevation={0}
        sx={{
          p: 4,
          width: '100%',
          maxWidth: 400,
          border: '1px solid',
          borderColor: 'divider',
        }}
      >
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            gap: 1.5,
            mb: 3,
            justifyContent: 'center',
          }}
        >
          <Database size={32} style={{ color: 'var(--mui-palette-primary-main)' }} />
          <Typography variant="h5" sx={{ fontWeight: 700 }}>
            Client Registry
          </Typography>
        </Box>

        <Typography
          variant="body2"
          color="text.secondary"
          sx={{ textAlign: 'center', mb: 3 }}
        >
          Sign in to access the MPI Administration Dashboard
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        <Box component="form" onSubmit={handleSubmit}>
          <TextField
            label="Email"
            type="email"
            fullWidth
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            sx={{ mb: 2 }}
            autoFocus
          />
          <TextField
            label="Password"
            type="password"
            fullWidth
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            sx={{ mb: 3 }}
          />
          <Button
            type="submit"
            variant="contained"
            fullWidth
            disabled={loading}
            sx={{ py: 1.5 }}
          >
            {loading ? <CircularProgress size={24} color="inherit" /> : 'Sign In'}
          </Button>
        </Box>

        <Typography
          variant="caption"
          color="text.disabled"
          sx={{ display: 'block', textAlign: 'center', mt: 2 }}
        >
          Development mode — any credentials accepted
        </Typography>
      </Paper>
    </Box>
  );
}
