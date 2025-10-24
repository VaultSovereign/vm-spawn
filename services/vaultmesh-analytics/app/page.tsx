import Link from 'next/link';
import { ArrowRight, Sparkles, Activity, Network } from 'lucide-react';

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-secondary/20">
      {/* Hero Section */}
      <div className="container mx-auto px-4 py-16">
        <div className="flex flex-col items-center text-center space-y-8">
          {/* Logo/Title */}
          <div className="space-y-4">
            <h1 className="text-6xl font-bold bg-gradient-to-r from-vault-gold via-vault-cyan to-vault-violet bg-clip-text text-transparent">
              VaultMesh Analytics
            </h1>
            <p className="text-xl text-muted-foreground max-w-2xl">
              Custom analytics for consciousness tracking, routing optimization, and sovereign infrastructure
            </p>
          </div>

          {/* Quick Stats */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 w-full max-w-4xl mt-12">
            <StatCard
              icon={<Sparkles className="w-8 h-8 text-psi-consciousness" />}
              label="Consciousness Density"
              value="Ψ-Field"
              href="/dashboards/consciousness"
            />
            <StatCard
              icon={<Activity className="w-8 h-8 text-vault-cyan" />}
              label="Routing Analytics"
              value="Aurora"
              href="/dashboards/routing"
            />
            <StatCard
              icon={<Network className="w-8 h-8 text-vault-violet" />}
              label="Resonance Network"
              value="Federation"
              href="/dashboards/resonance"
            />
          </div>

          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row gap-4 mt-12">
            <Link
              href="/dashboards/consciousness"
              className="inline-flex items-center justify-center px-6 py-3 rounded-xl bg-gradient-to-r from-vault-gold to-vault-cyan text-black font-semibold hover:shadow-lg transition-all duration-200"
            >
              View Dashboards
              <ArrowRight className="ml-2 w-5 h-5" />
            </Link>
            <Link
              href="/docs"
              className="inline-flex items-center justify-center px-6 py-3 rounded-xl border-2 border-vault-gold text-vault-gold font-semibold hover:bg-vault-gold/10 transition-all duration-200"
            >
              Documentation
            </Link>
          </div>

          {/* Feature Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-4xl mt-16">
            <FeatureCard
              title="Real-Time Consciousness Tracking"
              description="Monitor Ψ-Field metrics: continuity, futurity, phase coherence, and temporal entropy"
            />
            <FeatureCard
              title="Routing Intelligence"
              description="Analyze multi-provider routing decisions with AI-enhanced optimization"
            />
            <FeatureCard
              title="Resonance Analysis"
              description="Track vault coherence, witness alignments, and harmonic frequencies"
            />
            <FeatureCard
              title="Guardian Interventions"
              description="View alchemical transmutations (Nigredo, Albedo, Citrinitas, Rubedo)"
            />
          </div>

          {/* Footer */}
          <div className="mt-16 text-sm text-muted-foreground">
            <p>🜂 VaultMesh Analytics v1.0.0 — Solve et Coagula</p>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  icon,
  label,
  value,
  href,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  href: string;
}) {
  return (
    <Link href={href}>
      <div className="p-6 rounded-2xl border bg-card hover:border-vault-gold transition-all duration-200 cursor-pointer group">
        <div className="flex flex-col items-center space-y-3">
          <div className="p-3 rounded-xl bg-secondary group-hover:scale-110 transition-transform">
            {icon}
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold">{value}</div>
            <div className="text-sm text-muted-foreground">{label}</div>
          </div>
        </div>
      </div>
    </Link>
  );
}

function FeatureCard({ title, description }: { title: string; description: string }) {
  return (
    <div className="p-6 rounded-2xl border bg-card/50 backdrop-blur">
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-sm text-muted-foreground">{description}</p>
    </div>
  );
}
