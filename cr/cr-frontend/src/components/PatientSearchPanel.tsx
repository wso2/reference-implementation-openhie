import { useState } from 'react';
import {
  Box,
  Paper,
  Grid,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Button,
  Typography,
  Collapse,
  IconButton,
} from '@wso2/oxygen-ui';
import { ChevronDown, ChevronUp, Search, X } from 'lucide-react';
import type { ListPatientsParams } from '../types';
import { getPreferences } from '../hooks/useUserPreferences';

interface SearchFields {
  given: string;
  family: string;
  gender: string;
  birthdate: string;
  city: string;
  active: string;
  identifier: string;
}

const EMPTY: SearchFields = {
  given: '',
  family: '',
  gender: '',
  birthdate: '',
  city: '',
  active: 'true',
  identifier: '',
};

interface Props {
  onSearch: (filters: ListPatientsParams) => void;
}

export default function PatientSearchPanel({ onSearch }: Props) {
  const [open, setOpen] = useState(true);
  const [fields, setFields] = useState<SearchFields>(EMPTY);

  const set = (key: keyof SearchFields) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setFields((f) => ({ ...f, [key]: e.target.value }));

  const handleSearch = () => {
    const filters: ListPatientsParams = {};
    if (fields.given.trim())    filters.given     = fields.given.trim();
    if (fields.family.trim())   filters.family    = fields.family.trim();
    if (fields.gender)          filters.gender    = fields.gender;
    if (fields.birthdate)       filters.birthdate = fields.birthdate;
    if (fields.city.trim())     filters.city      = fields.city.trim();
    if (fields.identifier.trim()) {
      const { identifierSystemBaseUrl } = getPreferences();
      const id = fields.identifier.trim();
      filters.identifier = identifierSystemBaseUrl ? `${identifierSystemBaseUrl}|${id}` : id;
    }
    filters.active = fields.active === 'true';
    onSearch(filters);
  };

  const handleClear = () => {
    setFields(EMPTY);
    onSearch({ active: true });
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSearch();
  };

  return (
    <Paper variant="outlined" sx={{ borderRadius: 2 }}>
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          px: 2,
          py: 1.5,
          cursor: 'pointer',
          userSelect: 'none',
        }}
        onClick={() => setOpen((v) => !v)}
      >
        <Typography variant="body2" sx={{ fontWeight: 600, color: 'text.secondary' }}>
          Search &amp; Filter Patients
        </Typography>
        <IconButton size="small">
          {open ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
        </IconButton>
      </Box>

      <Collapse in={open}>
        <Box sx={{ px: 2, pb: 2, pt: 0.5 }}>
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <TextField
                fullWidth
                size="small"
                label="Given Name"
                value={fields.given}
                onChange={set('given')}
                onKeyDown={handleKeyDown}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <TextField
                fullWidth
                size="small"
                label="Family Name"
                value={fields.family}
                onChange={set('family')}
                onKeyDown={handleKeyDown}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <FormControl fullWidth size="small">
                <InputLabel>Gender</InputLabel>
                <Select label="Gender" value={fields.gender} onChange={(e) => setFields((f) => ({ ...f, gender: e.target.value as string }))}>
                  <MenuItem value="">All</MenuItem>
                  <MenuItem value="male">Male</MenuItem>
                  <MenuItem value="female">Female</MenuItem>
                  <MenuItem value="other">Other</MenuItem>
                  <MenuItem value="unknown">Unknown</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <TextField
                fullWidth
                size="small"
                label="Date of Birth"
                type="date"
                value={fields.birthdate}
                onChange={set('birthdate')}
                InputLabelProps={{ shrink: true }}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <TextField
                fullWidth
                size="small"
                label="City"
                value={fields.city}
                onChange={set('city')}
                onKeyDown={handleKeyDown}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <TextField
                fullWidth
                size="small"
                label="Patient ID"
                value={fields.identifier}
                onChange={set('identifier')}
                onKeyDown={handleKeyDown}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
              <FormControl fullWidth size="small">
                <InputLabel>Status</InputLabel>
                <Select label="Status" value={fields.active} onChange={(e) => setFields((f) => ({ ...f, active: e.target.value as string }))}>
                  <MenuItem value="true">Active</MenuItem>
                  <MenuItem value="false">Inactive</MenuItem>
                </Select>
              </FormControl>
            </Grid>
          </Grid>

          <Box sx={{ display: 'flex', gap: 1, mt: 2, justifyContent: 'flex-end' }}>
            <Button
              variant="text"
              size="small"
              startIcon={<X size={16} />}
              onClick={handleClear}
            >
              Clear
            </Button>
            <Button
              variant="contained"
              size="small"
              startIcon={<Search size={16} />}
              onClick={handleSearch}
            >
              Search
            </Button>
          </Box>
        </Box>
      </Collapse>
    </Paper>
  );
}
