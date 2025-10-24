import { Card, CardContent } from '@/components/ui/card';
import { TrendingUp, TrendingDown } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface KpiCardProps {
  label: string;
  value: string | number;
  delta?: number;
  unit?: string;
  icon?: React.ReactNode;
  loading?: boolean;
}

export function KpiCard({ label, value, delta, unit, icon, loading }: KpiCardProps) {
  const deltaPositive = delta !== undefined && delta > 0;
  const deltaNegative = delta !== undefined && delta < 0;

  return (
    <Card>
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div className="space-y-2">
            <p className="text-sm font-medium text-muted-foreground">{label}</p>
            <div className="flex items-baseline gap-2">
              {loading ? (
                <div className="h-8 w-24 animate-pulse rounded bg-muted" />
              ) : (
                <>
                  <h2 className="text-3xl font-bold">{value}</h2>
                  {unit && <span className="text-sm text-muted-foreground">{unit}</span>}
                </>
              )}
            </div>
            {delta !== undefined && !loading && (
              <div
                className={cn(
                  'flex items-center gap-1 text-xs font-medium',
                  deltaPositive && 'text-green-600 dark:text-green-400',
                  deltaNegative && 'text-red-600 dark:text-red-400',
                  delta === 0 && 'text-muted-foreground'
                )}
              >
                {deltaPositive && <TrendingUp className="h-3 w-3" />}
                {deltaNegative && <TrendingDown className="h-3 w-3" />}
                <span>
                  {deltaPositive && '+'}
                  {delta.toFixed(1)}%
                </span>
              </div>
            )}
          </div>
          {icon && (
            <div className="rounded-xl bg-secondary p-3 text-muted-foreground">{icon}</div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
