'use client';

import { Activity, Zap, DollarSign, CheckCircle, AlertCircle } from 'lucide-react';
import { KpiCard } from '@/components/panels/kpi-card';
import { TimeseriesPanel } from '@/components/charts/timeseries-panel';
import { useRoutingMetrics, useProviders, useRoutingHistory } from '@/lib/api/aurora-router';
import { formatNumber, formatPercentage } from '@/lib/utils';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

export default function RoutingDashboard() {
  const { data: metrics, isLoading: metricsLoading } = useRoutingMetrics();
  const { data: providers, isLoading: providersLoading } = useProviders();
  const { data: history, isLoading: historyLoading } = useRoutingHistory(1);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="space-y-2">
        <h1 className="text-4xl font-bold">Routing Analytics</h1>
        <p className="text-muted-foreground">
          Multi-provider compute routing intelligence across DePIN networks
        </p>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard
          label="Total Requests"
          value={metrics ? metrics.total_requests.toLocaleString() : '—'}
          icon={<Activity className="h-5 w-5 text-vault-cyan" />}
          loading={metricsLoading}
        />
        <KpiCard
          label="Success Rate"
          value={metrics ? formatPercentage(metrics.success_rate) : '—'}
          icon={<CheckCircle className="h-5 w-5 text-green-500" />}
          loading={metricsLoading}
        />
        <KpiCard
          label="Avg Latency"
          value={metrics ? formatNumber(metrics.avg_latency_ms, 0) : '—'}
          unit="ms"
          icon={<Zap className="h-5 w-5 text-yellow-500" />}
          loading={metricsLoading}
        />
        <KpiCard
          label="Avg Cost"
          value={metrics ? formatNumber(metrics.avg_cost_usd) : '—'}
          unit="$/hr"
          icon={<DollarSign className="h-5 w-5 text-green-600" />}
          loading={metricsLoading}
        />
      </div>

      {/* Provider Status */}
      <Card>
        <CardHeader>
          <CardTitle>Provider Health</CardTitle>
        </CardHeader>
        <CardContent>
          {providersLoading ? (
            <div className="text-center text-muted-foreground">Loading providers...</div>
          ) : (
            <div className="space-y-4">
              {providers?.map((provider) => (
                <div
                  key={provider.id}
                  className="flex items-center justify-between p-4 rounded-xl border bg-secondary/30"
                >
                  <div className="flex items-center gap-4">
                    <div
                      className={`h-3 w-3 rounded-full ${
                        provider.status === 'active'
                          ? 'bg-green-500'
                          : provider.status === 'degraded'
                          ? 'bg-yellow-500'
                          : 'bg-red-500'
                      }`}
                    />
                    <div>
                      <p className="font-semibold">{provider.name}</p>
                      <p className="text-sm text-muted-foreground">
                        Health: {formatPercentage(provider.health_score)} • Load:{' '}
                        {formatPercentage(provider.current_load)}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-6 text-sm">
                    <div className="text-right">
                      <p className="text-muted-foreground">Latency</p>
                      <p className="font-mono font-semibold">{provider.avg_latency_ms}ms</p>
                    </div>
                    <div className="text-right">
                      <p className="text-muted-foreground">Price</p>
                      <p className="font-mono font-semibold">${provider.price_per_hour}/hr</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Distribution Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Provider Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            {metrics ? (
              <div className="space-y-3">
                {Object.entries(metrics.provider_distribution).map(([provider, percentage]) => (
                  <div key={provider}>
                    <div className="flex justify-between mb-1 text-sm">
                      <span className="font-medium capitalize">{provider}</span>
                      <span className="text-muted-foreground">{percentage}%</span>
                    </div>
                    <div className="h-2 bg-secondary rounded-full overflow-hidden">
                      <div
                        className="h-full bg-gradient-to-r from-vault-gold to-vault-cyan"
                        style={{ width: `${percentage}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center text-muted-foreground">Loading...</div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Workload Types</CardTitle>
          </CardHeader>
          <CardContent>
            {metrics ? (
              <div className="space-y-3">
                {Object.entries(metrics.requests_by_workload).map(([workload, percentage]) => (
                  <div key={workload}>
                    <div className="flex justify-between mb-1 text-sm">
                      <span className="font-medium">
                        {workload.replace('_', ' ').toUpperCase()}
                      </span>
                      <span className="text-muted-foreground">{percentage}%</span>
                    </div>
                    <div className="h-2 bg-secondary rounded-full overflow-hidden">
                      <div
                        className="h-full bg-gradient-to-r from-vault-indigo to-vault-violet"
                        style={{ width: `${percentage}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center text-muted-foreground">Loading...</div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Timeseries Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <TimeseriesPanel
          title="Requests per Minute"
          data={history?.map((p) => ({ t: p.timestamp, v: p.requests })) || []}
          color="#00D9FF"
          unit="req/min"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Success Rate"
          data={history?.map((p) => ({ t: p.timestamp, v: p.success_rate })) || []}
          color="#10B981"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Average Latency"
          data={history?.map((p) => ({ t: p.timestamp, v: p.avg_latency })) || []}
          color="#F59E0B"
          unit="ms"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Average Cost"
          data={history?.map((p) => ({ t: p.timestamp, v: p.avg_cost })) || []}
          color="#8B5CF6"
          unit="$/hr"
          loading={historyLoading}
        />
      </div>

      {/* Info Footer */}
      <div className="p-4 rounded-xl bg-muted text-sm text-muted-foreground">
        <p>
          <strong>Aurora Router</strong> — Multi-provider compute routing with AI-enhanced
          optimization across Akash, io.net, Render, Vast.ai, and more.
        </p>
      </div>
    </div>
  );
}
