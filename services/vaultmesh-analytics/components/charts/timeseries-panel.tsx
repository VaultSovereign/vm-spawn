'use client';

import ReactECharts from 'echarts-for-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useTheme } from 'next-themes';

export interface TimeseriesDataPoint {
  t: number; // timestamp (ms or seconds)
  v: number; // value
}

export interface TimeseriesPanelProps {
  title: string;
  data: TimeseriesDataPoint[];
  color?: string;
  unit?: string;
  height?: number;
  loading?: boolean;
}

export function TimeseriesPanel({
  title,
  data,
  color = '#FFB800',
  unit = '',
  height = 360,
  loading,
}: TimeseriesPanelProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const option = {
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      backgroundColor: isDark ? '#1e293b' : '#ffffff',
      borderColor: isDark ? '#334155' : '#e2e8f0',
      textStyle: {
        color: isDark ? '#f1f5f9' : '#0f172a',
      },
      formatter: (params: any) => {
        const point = params[0];
        const date = new Date(point.axisValue);
        const value = point.value[1];
        return `
          <div style="padding: 4px;">
            <div style="margin-bottom: 4px; font-weight: 600;">${date.toLocaleTimeString()}</div>
            <div style="color: ${color}; font-weight: 700;">${value.toFixed(3)} ${unit}</div>
          </div>
        `;
      },
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '10%',
      top: '5%',
      containLabel: true,
    },
    xAxis: {
      type: 'time',
      boundaryGap: false,
      axisLine: {
        lineStyle: {
          color: isDark ? '#475569' : '#cbd5e1',
        },
      },
      axisLabel: {
        color: isDark ? '#94a3b8' : '#64748b',
        fontSize: 11,
      },
    },
    yAxis: {
      type: 'value',
      scale: true,
      axisLine: {
        show: false,
      },
      axisTick: {
        show: false,
      },
      axisLabel: {
        color: isDark ? '#94a3b8' : '#64748b',
        fontSize: 11,
        formatter: (value: number) => value.toFixed(2),
      },
      splitLine: {
        lineStyle: {
          color: isDark ? '#1e293b' : '#f1f5f9',
          type: 'dashed',
        },
      },
    },
    series: [
      {
        type: 'line',
        name: title,
        data: data.map((p) => [p.t, p.v]),
        smooth: true,
        showSymbol: false,
        lineStyle: {
          width: 2,
          color: color,
        },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              {
                offset: 0,
                color: `${color}40`,
              },
              {
                offset: 1,
                color: `${color}10`,
              },
            ],
          },
        },
      },
    ],
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {loading ? (
          <div className="flex items-center justify-center" style={{ height }}>
            <div className="text-muted-foreground">Loading...</div>
          </div>
        ) : (
          <ReactECharts option={option} style={{ height, width: '100%' }} />
        )}
      </CardContent>
    </Card>
  );
}
