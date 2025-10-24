'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import { Sparkles, Activity, Network, Bell, Settings, Home } from 'lucide-react';

const navigation = [
  { name: 'Home', href: '/', icon: Home },
  { name: 'Consciousness', href: '/dashboards/consciousness', icon: Sparkles },
  { name: 'Routing', href: '/dashboards/routing', icon: Activity },
  { name: 'Resonance', href: '/dashboards/resonance', icon: Network },
  { name: 'Alerts', href: '/alerts', icon: Bell },
  { name: 'Settings', href: '/settings', icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <div className="flex h-full w-64 flex-col border-r bg-card">
      {/* Logo */}
      <div className="flex h-16 items-center border-b px-6">
        <h1 className="text-xl font-bold bg-gradient-to-r from-vault-gold to-vault-cyan bg-clip-text text-transparent">
          VaultMesh
        </h1>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 p-4">
        {navigation.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(item.href + '/');
          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                'flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition-all',
                isActive
                  ? 'bg-gradient-to-r from-vault-gold/20 to-vault-cyan/20 text-vault-gold border border-vault-gold/30'
                  : 'text-muted-foreground hover:bg-secondary hover:text-foreground'
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.name}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="border-t p-4">
        <div className="text-xs text-muted-foreground">
          <p className="font-semibold">VaultMesh Analytics v1.0.0</p>
          <p className="mt-1">🜂 Solve et Coagula</p>
        </div>
      </div>
    </div>
  );
}
