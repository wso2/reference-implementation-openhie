import { Grid, Card, CardContent, Typography } from '@wso2/oxygen-ui';

interface Stat {
  label: string;
  value: string | number;
  color?: string;
}

interface Props {
  stats: Stat[];
}

export default function StatsGrid({ stats }: Props) {
  return (
    <Grid container spacing={2}>
      {stats.map((stat) => (
        <Grid key={stat.label} size={{ xs: 6, sm: 3 }}>
          <Card>
            <CardContent sx={{ textAlign: 'center', py: 2.5 }}>
              <Typography
                variant="h4"
                sx={{
                  fontWeight: 700,
                  color: stat.color || 'text.primary',
                }}
              >
                {stat.value}
              </Typography>
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{ mt: 0.5 }}
              >
                {stat.label}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      ))}
    </Grid>
  );
}
