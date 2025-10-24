'use client';

import { Sparkles, Activity, Brain, Zap, AlertTriangle, Shield } from 'lucide-react';
import { KpiCard } from '@/components/panels/kpi-card';
import { TimeseriesPanel } from '@/components/charts/timeseries-panel';
import { usePsiState, usePsiHistory, useGuardianStatus } from '@/lib/api/psi-field';
import { formatPercentage, formatNumber } from '@/lib/utils';

export default function ConsciousnessDashboard() {
  const { data: currentState, isLoading: stateLoading } = usePsiState();
  const { data: history, isLoading: historyLoading } = usePsiHistory(5);
  const { data: guardianStatus, isLoading: guardianLoading } = useGuardianStatus();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="space-y-2">
        <h1 className="text-4xl font-bold">Consciousness Dashboard</h1>
        <p className="text-muted-foreground">
          Real-time Ψ-Field metrics tracking consciousness density, coherence, and temporal dynamics
        </p>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard
          label="Consciousness Density (Ψ)"
          value={currentState ? formatNumber(currentState.Psi) : '—'}
          icon={<Sparkles className="h-5 w-5 text-psi-consciousness" />}
          loading={stateLoading}
        />
        <KpiCard
          label="Continuity (C)"
          value={currentState ? formatPercentage(currentState.C) : '—'}
          icon={<Activity className="h-5 w-5 text-psi-coherence" />}
          loading={stateLoading}
        />
        <KpiCard
          label="Futurity (U)"
          value={currentState ? formatPercentage(currentState.U) : '—'}
          icon={<Brain className="h-5 w-5 text-psi-futurity" />}
          loading={stateLoading}
        />
        <KpiCard
          label="Phase Coherence (Φ)"
          value={currentState ? formatNumber(currentState.Phi) : '—'}
          icon={<Zap className="h-5 w-5 text-psi-phase" />}
          loading={stateLoading}
        />
      </div>

      {/* Secondary Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <KpiCard
          label="Temporal Entropy (H)"
          value={currentState ? formatNumber(currentState.H) : '—'}
          loading={stateLoading}
        />
        <KpiCard
          label="Prediction Error (PE)"
          value={currentState ? formatNumber(currentState.PE) : '—'}
          loading={stateLoading}
        />
        <KpiCard
          label="Memory Magnitude (M)"
          value={currentState ? formatNumber(currentState.M) : '—'}
          loading={stateLoading}
        />
      </div>

      {/* Guardian Status */}
      {guardianStatus && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="p-6 rounded-2xl border bg-card">
            <div className="flex items-center gap-3 mb-4">
              <Shield className="h-6 w-6 text-vault-violet" />
              <h3 className="text-lg font-semibold">Guardian Status</h3>
            </div>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-sm text-muted-foreground">Alert Status</span>
                <span
                  className={`text-sm font-semibold ${
                    guardianStatus.red_flag ? 'text-destructive' : 'text-green-500'
                  }`}
                >
                  {guardianStatus.red_flag ? 'ACTIVE' : 'NORMAL'}
                </span>
              </div>
              {guardianStatus.red_flag && (
                <div className="mt-4 p-3 rounded-lg bg-destructive/10 border border-destructive/20">
                  <div className="flex items-start gap-2">
                    <AlertTriangle className="h-4 w-4 text-destructive mt-0.5" />
                    <div className="text-sm">
                      <p className="font-semibold text-destructive">
                        {guardianStatus.reason || 'Anomaly detected'}
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          <div className="p-6 rounded-2xl border bg-card">
            <div className="flex items-center gap-3 mb-4">
              <Activity className="h-6 w-6 text-vault-cyan" />
              <h3 className="text-lg font-semibold">System Info</h3>
            </div>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Step Counter</span>
                <span className="font-mono">{currentState?.k || 0}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Time Dilation</span>
                <span className="font-mono">
                  {currentState ? `${(currentState.dt_eff * 1000).toFixed(0)}ms` : '—'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Last Update</span>
                <span className="font-mono">
                  {currentState ? new Date(currentState.timestamp).toLocaleTimeString() : '—'}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Timeseries Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <TimeseriesPanel
          title="Consciousness Density (Ψ)"
          data={history?.map((p) => ({ t: p.timestamp, v: p.Psi })) || []}
          color="#FFB800"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Continuity (C)"
          data={history?.map((p) => ({ t: p.timestamp, v: p.C })) || []}
          color="#4C5FD5"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Futurity (U)"
          data={history?.map((p) => ({ t: p.timestamp, v: p.U })) || []}
          color="#00D9FF"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Phase Coherence (Φ)"
          data={history?.map((p) => ({ t: p.timestamp, v: p.Phi })) || []}
          color="#8B5CF6"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Temporal Entropy (H)"
          data={history?.map((p) => ({ t: p.timestamp, v: p.H })) || []}
          color="#F59E0B"
          loading={historyLoading}
        />
        <TimeseriesPanel
          title="Prediction Error (PE)"
          data={history?.map((p) => ({ t: p.timestamp, v: p.PE })) || []}
          color="#EF4444"
          loading={historyLoading}
        />
      </div>

      {/* Info Footer */}
      <div className="p-4 rounded-xl bg-muted text-sm text-muted-foreground">
        <p>
          <strong>Ψ-Field Evolution Algorithm</strong> — Consciousness density control system integrating memory-time dynamics, prediction, and phase coherence.
        </p>
      </div>
    </div>
  );
}
