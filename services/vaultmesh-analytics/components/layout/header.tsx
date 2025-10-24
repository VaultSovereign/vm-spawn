'use client';

import { Bell, Moon, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';

export function Header() {
  const { theme, setTheme } = useTheme();

  return (
    <header className="h-16 border-b bg-card">
      <div className="flex h-full items-center justify-between px-6">
        {/* Breadcrumbs or page title would go here */}
        <div className="text-lg font-semibold">Dashboard</div>

        {/* Actions */}
        <div className="flex items-center gap-4">
          {/* Theme toggle */}
          <button
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="p-2 rounded-lg hover:bg-secondary transition-colors"
          >
            {theme === 'dark' ? (
              <Sun className="h-5 w-5" />
            ) : (
              <Moon className="h-5 w-5" />
            )}
          </button>

          {/* Notifications */}
          <button className="relative p-2 rounded-lg hover:bg-secondary transition-colors">
            <Bell className="h-5 w-5" />
            <span className="absolute top-1 right-1 h-2 w-2 rounded-full bg-destructive" />
          </button>

          {/* User menu would go here */}
          <div className="h-8 w-8 rounded-full bg-gradient-to-r from-vault-gold to-vault-cyan" />
        </div>
      </div>
    </header>
  );
}
