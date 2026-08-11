'use client';

import { createContext, useContext, useEffect, useState } from 'react';

export type SidebarTheme = 'light' | 'dark' | 'midnight' | 'ocean' | 'emerald';

const THEMES: { value: SidebarTheme; label: string; swatch: string }[] = [
  { value: 'light', label: 'Light', swatch: 'bg-white border border-slate-300' },
  { value: 'dark', label: 'Dark', swatch: 'bg-slate-900' },
  { value: 'midnight', label: 'Midnight', swatch: 'bg-indigo-950' },
  { value: 'ocean', label: 'Ocean', swatch: 'bg-sky-950' },
  { value: 'emerald', label: 'Emerald', swatch: 'bg-emerald-950' },
];

interface Ctx {
  theme: SidebarTheme;
  setTheme: (t: SidebarTheme) => void;
  themes: typeof THEMES;
}

const ThemeCtx = createContext<Ctx | null>(null);

function applyTheme(t: SidebarTheme) {
  if (typeof document === 'undefined') return;
  document.documentElement.setAttribute('data-sidebar-theme', t);
  if (t === 'light') {
    document.documentElement.classList.remove('dark');
  } else {
    document.documentElement.classList.add('dark');
  }
}

function readSavedTheme(): SidebarTheme {
  if (typeof window === 'undefined') return 'light';
  const v = localStorage.getItem('sb-theme') as SidebarTheme | null;
  return v && ['light', 'dark', 'midnight', 'ocean', 'emerald'].includes(v) ? v : 'light';
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<SidebarTheme>(() => readSavedTheme());

  useEffect(() => {
    applyTheme(theme);
  }, [theme]);

  const setTheme = (t: SidebarTheme) => {
    setThemeState(t);
    if (typeof window !== 'undefined') localStorage.setItem('sb-theme', t);
    applyTheme(t);
  };

  return <ThemeCtx.Provider value={{ theme, setTheme, themes: THEMES }}>{children}</ThemeCtx.Provider>;
}

export function useTheme() {
  const v = useContext(ThemeCtx);
  if (!v) throw new Error('useTheme must be used within ThemeProvider');
  return v;
}
