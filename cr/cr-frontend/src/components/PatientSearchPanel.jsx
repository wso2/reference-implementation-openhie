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

const EMPTY = {
  given: '',
  family: '',
  gender: '',
  birthdate: '',
  city: '',
  active: 'true',
};

export default function PatientSearchPanel({ onSearch }) {
  const [open, setOpen] = useState(true);
  const [fields, setFields] = useState(EMPTY);

  const set = (key) => (e) => setFields((f) => ({ ...f, [key]: e.target.value }));

  const handleSearch = () => {
    const filters = {};
    if (fields.given) filters.given = fields.given;
    if (fields.family) filters.family = fields.family;
    if (fields.gender) filters.gender = fields.gender;
    if (fields.birthdate) filters.birthdate = fields.birthdate;
    if (fields.city) filters.city = fields.city;
    // active: 'true' → true, 'false' → false
    filters.active = fields.active === 'true';
    onSearch(filters);
  };

  const handleClear = () => {
    setFields(EMPTY);
    onSearch({ active: true });
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') handleSearch();
  };

  return (
    <Paper variant="outlined" sx={{ borderRadius: 2 }}>
      {/* Header toggle */}
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
            {/* Row 1 */}
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
                <Select label="Gender" value={fields.gender} onChange={set('gender')}>
                  <MenuItem value="">All</MenuItem>
                  <MenuItem value="male">Male</MenuItem>
                  <MenuItem value="female">Female</MenuItem>
                  <MenuItem value="other">Other</MenuItem>
                  <MenuItem value="unknown">Unknown</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            {/* Row 2 */}
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
              <FormControl fullWidth size="small">
                <InputLabel>Status</InputLabel>
                <Select label="Status" value={fields.active} onChange={set('active')}>
                  <MenuItem value="true">Active</MenuItem>
                  <MenuItem value="false">Inactive</MenuItem>
                </Select>
              </FormControl>
            </Grid>
          </Grid>

          {/* Actions */}
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
