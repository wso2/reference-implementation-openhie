import { Box, Typography } from '@wso2/oxygen-ui';
import { getScoreColor } from '../utils/matchUtils';

interface Props {
  score: number;
}

export default function ScoreCircle({ score }: Props) {
  const color = getScoreColor(score);
  const percent = Math.round(score * 100);
  const circumference = 2 * Math.PI * 26; // r=26

  return (
    <Box sx={{ position: 'relative', width: 60, height: 60 }}>
      <svg width="60" height="60" viewBox="0 0 60 60">
        <circle
          cx="30"
          cy="30"
          r="26"
          fill="none"
          stroke="#e5e7eb"
          strokeWidth="4"
        />
        <circle
          cx="30"
          cy="30"
          r="26"
          fill="none"
          stroke={color}
          strokeWidth="4"
          strokeDasharray={`${score * circumference} ${circumference}`}
          strokeLinecap="round"
          transform="rotate(-90 30 30)"
        />
      </svg>
      <Typography
        sx={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          fontSize: '14px',
          fontWeight: 700,
          color: 'text.primary',
        }}
      >
        {percent}%
      </Typography>
    </Box>
  );
}
