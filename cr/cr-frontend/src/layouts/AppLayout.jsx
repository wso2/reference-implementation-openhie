import { Outlet, NavLink } from 'react-router';
import {
  AppBar,
  Toolbar,
  Typography,
  Box,
  Avatar,
  IconButton,
  Button,
  Badge,
  Chip,
} from '@wso2/oxygen-ui';
import { Database, Settings, LogOut, Link, Users, History } from 'lucide-react';
import { useAuth } from '../auth/AuthContext';

const navItems = [
  { to: '/dashboard', label: 'Match Review', icon: Link, showBadge: true },
  { to: '/patients', label: 'Patient Search', icon: Users },
  { to: '/audit', label: 'Audit Log', icon: History },
];

export default function AppLayout() {
  const { user, logout } = useAuth();

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
      {/* Header */}
      <AppBar position="static" sx={{ bgcolor: 'secondary.dark', borderRadius: 0 }}>
        <Toolbar sx={{ px: { xs: 2, sm: 4 } }}>
          <Box sx={{ mr: 1.5, color: 'text.secondary', display: 'flex' }}>
            <Database size={20} />
          </Box>
          <Typography
            variant="h6"
            sx={{ fontSize: '18px', letterSpacing: '-0.02em', mr: 2, color: 'text.secondary' }}
          >
            Client Registry
          </Typography>
          <Chip
            label={user?.role === 'admin' ? 'MPI Admin' : 'MPI Viewer'}
            size="small"
            sx={{
              bgcolor: 'primary.main',
              color: 'white',
              fontSize: '11px',
              fontWeight: 600,
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              height: 24,
            }}
          />
          <Box sx={{ flex: 1 }} />
          <IconButton color="inherit" sx={{ color: 'text.disabled' }}>
            <Settings size={20} />
          </IconButton>
          <Avatar
            sx={{
              width: 36,
              height: 36,
              bgcolor: 'primary.main',
              fontSize: 14,
              fontWeight: 600,
              ml: 1,
            }}
          >
            {user?.initials || 'U'}
          </Avatar>
          <IconButton
            onClick={logout}
            sx={{ color: 'text.disabled', ml: 0.5 }}
            title="Sign out"
          >
            <LogOut size={18} />
          </IconButton>
        </Toolbar>
      </AppBar>

      {/* Navigation */}
      <Box
        component="nav"
        sx={{
          display: 'flex',
          gap: 0.5,
          px: { xs: 2, sm: 4 },
          py: 1.5,
          bgcolor: 'secondary.main',
          borderBottom: '1px solid',
          borderColor: 'secondary.light',
        }}
      >
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            style={{ textDecoration: 'none' }}
          >
            {({ isActive }) => (
              <Button
                startIcon={<item.icon size={18} />}
                sx={{
                  color: isActive ? 'white' : 'text.disabled',
                  bgcolor: isActive ? 'secondary.light' : 'transparent',
                  borderRadius: '8px',
                  px: 2.5,
                  py: 1.25,
                  fontSize: '14px',
                  fontWeight: 500,
                  '&:hover': {
                    bgcolor: isActive ? 'secondary.light' : 'rgba(255,255,255,0.05)',
                  },
                }}
              >
                {item.label}
              </Button>
            )}
          </NavLink>
        ))}
      </Box>

      {/* Main Content */}
      <Box component="main" sx={{ p: { xs: 2, sm: 3, md: 4 }, width: '100%' }}>
        <Outlet />
      </Box>
    </Box>
  );
}
