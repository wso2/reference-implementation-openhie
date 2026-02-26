import { Box, TextField, InputAdornment, Select, MenuItem } from '@wso2/oxygen-ui';
import { Search } from 'lucide-react';

export default function SearchToolbar({
  searchQuery,
  onSearchChange,
  placeholder = 'Search...',
  filterValue,
  onFilterChange,
  filterOptions,
  children,
}) {
  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: 2,
        flexWrap: 'wrap',
      }}
    >
      <TextField
        value={searchQuery}
        onChange={(e) => onSearchChange(e.target.value)}
        placeholder={placeholder}
        sx={{ minWidth: 320, bgcolor: 'background.paper' }}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <Search size={18} style={{ color: 'var(--mui-palette-text-secondary)' }} />
            </InputAdornment>
          ),
        }}
      />
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
        {filterOptions && (
          <Select
            value={filterValue}
            onChange={(e) => onFilterChange(e.target.value)}
            size="small"
            sx={{
              minWidth: 180,
              bgcolor: 'background.paper',
              fontSize: '14px',
            }}
          >
            {filterOptions.map((opt) => (
              <MenuItem key={opt.value} value={opt.value}>
                {opt.label}
              </MenuItem>
            ))}
          </Select>
        )}
        {children}
      </Box>
    </Box>
  );
}
