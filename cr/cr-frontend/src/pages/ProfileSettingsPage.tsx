import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Tabs,
  Tab,
  Avatar,
  Chip,
  Button,
  Divider,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Switch,
  FormControlLabel,
  Alert,
  TextField,
} from '@wso2/oxygen-ui';
import { User, Settings, Shield, LogOut, RotateCcw } from 'lucide-react';
import { useAuth } from '../auth/AuthContext';
import { useUserPreferences } from '../hooks/useUserPreferences';
import type { UserPreferences } from '../types';

export default function ProfileSettingsPage() {
  const { user, logout } = useAuth();
  const { preferences, updatePreference, resetPreferences } = useUserPreferences();
  const [activeTab, setActiveTab] = useState(0);
  const [savedVisible, setSavedVisible] = useState(false);
  const [sessionExpiry, setSessionExpiry] = useState<Date | null>(null);

  useEffect(() => {
    try {
      const token = localStorage.getItem('auth_token');
      if (token) {
        const payload = JSON.parse(atob(token)) as { exp: number };
        setSessionExpiry(new Date(payload.exp));
      }
    } catch {
      // ignore invalid token
    }
  }, []);

  function handlePreferenceChange<K extends keyof UserPreferences>(key: K, value: UserPreferences[K]) {
    updatePreference(key, value);
    setSavedVisible(true);
    setTimeout(() => setSavedVisible(false), 2500);
  }

  function handleReset() {
    resetPreferences();
    setSavedVisible(true);
    setTimeout(() => setSavedVisible(false), 2500);
  }

  return (
    <Box sx={{ maxWidth: 720, mx: 'auto' }}>
      <Box sx={{ mb: 3 }}>
        <Typography variant="h5" sx={{ fontWeight: 700, color: 'text.primary', letterSpacing: '-0.02em' }}>
          Profile &amp; Settings
        </Typography>
        <Typography variant="body2" sx={{ color: 'text.secondary', mt: 0.5 }}>
          Manage your account information and application preferences
        </Typography>
      </Box>

      <Tabs
        value={activeTab}
        onChange={(_, v) => setActiveTab(v as number)}
        sx={{ borderBottom: '1px solid', borderColor: 'divider', mb: 3 }}
      >
        <Tab icon={<User size={15} />} iconPosition="start" label="Profile" />
        <Tab icon={<Settings size={15} />} iconPosition="start" label="Preferences" />
        <Tab icon={<Shield size={15} />} iconPosition="start" label="Session" />
      </Tabs>

      {activeTab === 0 && (
        <Card>
          <CardContent sx={{ p: 3 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 3, mb: 3 }}>
              <Avatar sx={{ width: 64, height: 64, bgcolor: 'primary.main', fontSize: 24, fontWeight: 700 }}>
                {user?.initials || 'U'}
              </Avatar>
              <Box>
                <Typography variant="h6" sx={{ fontWeight: 600 }}>
                  {user?.name || 'Unknown User'}
                </Typography>
                <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                  {user?.email}
                </Typography>
                <Chip
                  label={user?.role === 'admin' ? 'MPI Admin' : 'MPI Viewer'}
                  size="small"
                  sx={{
                    mt: 0.75,
                    bgcolor: 'primary.main',
                    color: 'white',
                    fontSize: '11px',
                    fontWeight: 600,
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                    height: 22,
                  }}
                />
              </Box>
            </Box>

            <Divider sx={{ mb: 2.5 }} />

            <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mb: 2.5 }}>
              Account details are managed by your identity provider and cannot be changed here.
            </Typography>

            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2.5 }}>
              <Box>
                <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block' }}>
                  Email
                </Typography>
                <Typography variant="body2" sx={{ mt: 0.25 }}>{user?.email || '—'}</Typography>
              </Box>
              <Box>
                <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block' }}>
                  Display Name
                </Typography>
                <Typography variant="body2" sx={{ mt: 0.25 }}>{user?.name || '—'}</Typography>
              </Box>
              <Box>
                <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block' }}>
                  Role
                </Typography>
                <Typography variant="body2" sx={{ mt: 0.25, textTransform: 'capitalize' }}>{user?.role || '—'}</Typography>
              </Box>
              {(user?.groups?.length ?? 0) > 0 && (
                <Box>
                  <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block', mb: 0.5 }}>
                    Groups
                  </Typography>
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                    {user!.groups!.map((g) => (
                      <Chip key={g} label={g} size="small" variant="outlined" />
                    ))}
                  </Box>
                </Box>
              )}
            </Box>
          </CardContent>
        </Card>
      )}

      {activeTab === 1 && (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
          {savedVisible && (
            <Alert severity="success" sx={{ borderRadius: 2 }}>
              Preferences saved
            </Alert>
          )}

          <Card>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2 }}>
                Patient List
              </Typography>
              <FormControl size="small" sx={{ minWidth: 220 }}>
                <InputLabel>Default Rows per Page</InputLabel>
                <Select
                  label="Default Rows per Page"
                  value={preferences.defaultPageSize}
                  onChange={(e) => handlePreferenceChange('defaultPageSize', e.target.value as number)}
                >
                  <MenuItem value={5}>5 rows</MenuItem>
                  <MenuItem value={10}>10 rows</MenuItem>
                  <MenuItem value={25}>25 rows</MenuItem>
                  <MenuItem value={50}>50 rows</MenuItem>
                </Select>
              </FormControl>
            </CardContent>
          </Card>

          <Card>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2 }}>
                Date Display
              </Typography>
              <FormControl size="small" sx={{ minWidth: 260 }}>
                <InputLabel>Date Format</InputLabel>
                <Select
                  label="Date Format"
                  value={preferences.dateFormat}
                  onChange={(e) => handlePreferenceChange('dateFormat', e.target.value as UserPreferences['dateFormat'])}
                >
                  <MenuItem value="relative">Relative (e.g. "2 hours ago")</MenuItem>
                  <MenuItem value="absolute">Absolute (e.g. "Mar 3, 2026 14:30")</MenuItem>
                </Select>
              </FormControl>
            </CardContent>
          </Card>

          <Card>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.5 }}>
                Patient Identifier
              </Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary', mb: 2 }}>
                System base URL prepended to ID searches in <code>system|ID</code> format
              </Typography>
              <TextField
                fullWidth
                size="small"
                label="System Base URL"
                placeholder="e.g. http://example.org/fhir/sid/mrn"
                value={preferences.identifierSystemBaseUrl ?? ''}
                onChange={(e) => handlePreferenceChange('identifierSystemBaseUrl', e.target.value)}
              />
            </CardContent>
          </Card>

          <Card>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2 }}>
                Audit Log
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={preferences.auditAutoRefresh}
                      onChange={(e) => handlePreferenceChange('auditAutoRefresh', e.target.checked)}
                    />
                  }
                  label="Auto-refresh audit log"
                />
                {preferences.auditAutoRefresh && (
                  <FormControl size="small" sx={{ minWidth: 220 }}>
                    <InputLabel>Refresh Interval</InputLabel>
                    <Select
                      label="Refresh Interval"
                      value={preferences.auditRefreshInterval}
                      onChange={(e) => handlePreferenceChange('auditRefreshInterval', e.target.value as number)}
                    >
                      <MenuItem value={15}>Every 15 seconds</MenuItem>
                      <MenuItem value={30}>Every 30 seconds</MenuItem>
                      <MenuItem value={60}>Every 60 seconds</MenuItem>
                    </Select>
                  </FormControl>
                )}
              </Box>
            </CardContent>
          </Card>

          <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
            <Button variant="outlined" startIcon={<RotateCcw size={16} />} onClick={handleReset}>
              Reset to Defaults
            </Button>
          </Box>
        </Box>
      )}

      {activeTab === 2 && (
        <Card>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2.5 }}>
              Current Session
            </Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2.5, mb: 3 }}>
              <Box>
                <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block' }}>
                  Signed in as
                </Typography>
                <Typography variant="body2" sx={{ mt: 0.25 }}>{user?.email || '—'}</Typography>
              </Box>
              <Box>
                <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block' }}>
                  Session expires
                </Typography>
                <Typography variant="body2" sx={{ mt: 0.25 }}>
                  {sessionExpiry ? sessionExpiry.toLocaleString() : '—'}
                </Typography>
              </Box>
            </Box>
            <Divider sx={{ mb: 2.5 }} />
            <Button variant="outlined" color="error" startIcon={<LogOut size={16} />} onClick={logout}>
              Sign Out
            </Button>
          </CardContent>
        </Card>
      )}
    </Box>
  );
}
