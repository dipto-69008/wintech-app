'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  Menu, ChevronDown, LogOut, User, Bell, BellOff,
  Search, Palette, Check, X, Building2,
} from 'lucide-react';
import { Avatar } from '@/components/ui/Avatar';
import toast from 'react-hot-toast';
import Link from 'next/link';
import { useTheme } from '@/components/providers/ThemeProvider';
import { cn } from '@/lib/utils';
import { NotificationBell } from '@/components/layout/NotificationBell';
import { QuickAdd } from '@/components/layout/QuickAdd';
import { useAuthStore, useBranchStore } from '@/lib/store';
import { useMobileMenu } from '@/components/layout/MobileMenuContext';

// ── Branch Selector ──────────────────────────────────────────────
interface Branch { _id: string; name: string; legacyId?: number; }

function BranchSelector() {
  const [branches, setBranches] = useState<Branch[]>([]);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const { selectedBranchId, selectedBranchName, setSelectedBranch } = useBranchStore();

  useEffect(() => {
    fetch('/api/branches').then(r => r.json()).then(d => {
      setBranches(d.data || d || []);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  const label = selectedBranchId ? selectedBranchName : 'All Branches';

  return (
    <div className="relative hidden sm:block" ref={ref}>
      <button
        onClick={() => setOpen(v => !v)}
        className="flex items-center gap-1.5 h-9 px-3 rounded-lg bg-slate-100/70 dark:bg-gray-700/50 hover:bg-white dark:hover:bg-gray-700 hover:shadow-sm border border-transparent hover:border-slate-200 dark:hover:border-gray-600 transition text-sm text-slate-700 dark:text-gray-200 max-w-[180px]"
        title="Filter by branch"
      >
        <Building2 className="w-4 h-4 text-slate-400 flex-shrink-0" />
        <span className="truncate">{label}</span>
        <ChevronDown className="w-3.5 h-3.5 text-slate-400 flex-shrink-0" />
      </button>

      {open && (
        <div className="absolute left-0 mt-2 w-52 bg-white dark:bg-gray-800 border border-slate-200 dark:border-gray-700 rounded-xl shadow-xl py-1 z-50 animate-slide-down">
          <p className="px-3 pt-1 pb-1.5 text-[10px] font-bold tracking-widest uppercase text-slate-400">Branch Filter</p>
          <button
            onClick={() => { setSelectedBranch('', '', null); setOpen(false); }}
            className="w-full flex items-center justify-between px-3 py-2 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-50 dark:hover:bg-gray-700 transition"
          >
            <span>All Branches</span>
            {!selectedBranchId && <Check className="w-4 h-4 text-blue-600" />}
          </button>
          {branches.map(b => (
            <button
              key={b._id}
              onClick={() => { setSelectedBranch(b._id, b.name, b.legacyId ?? null); setOpen(false); }}
              className="w-full flex items-center justify-between px-3 py-2 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-50 dark:hover:bg-gray-700 transition"
            >
              <span className="truncate">{b.name}</span>
              {selectedBranchId === b._id && <Check className="w-4 h-4 text-blue-600" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

const NOTIF_KEY = 'erp_notif_enabled';

interface TopbarProps {
  title?: string;
  subtitle?: string;
  actions?: React.ReactNode;
}

export function Topbar({ title, subtitle, actions }: TopbarProps) {
  const router = useRouter();
  const { user } = useAuthStore();
  const onMenu = useMobileMenu();

  const [open, setOpen] = useState(false);
  const [themeOpen, setThemeOpen] = useState(false);
  const [notifEnabled, setNotifEnabled] = useState(false);
  const [notifSupported, setNotifSupported] = useState(true);
  const [searchQ, setSearchQ] = useState('');
  const [searchFocus, setSearchFocus] = useState(false);

  const ref = useRef<HTMLDivElement>(null);
  const themeRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const { theme, setTheme, themes } = useTheme();

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
      if (themeRef.current && !themeRef.current.contains(e.target as Node)) setThemeOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  // Cmd/Ctrl + K focuses search
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
      if (
        e.key === '/' &&
        !['INPUT', 'TEXTAREA'].includes((e.target as HTMLElement)?.tagName) &&
        !(e.target as HTMLElement)?.isContentEditable
      ) {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (!('Notification' in window)) { setNotifSupported(false); return; }
    const stored = localStorage.getItem(NOTIF_KEY) === '1';
    setNotifEnabled(stored && Notification.permission === 'granted');
  }, []);

  const toggleNotifications = async () => {
    if (!notifSupported || typeof window === 'undefined' || !('Notification' in window)) {
      toast.error('Apnar browser notification support kore na');
      return;
    }
    if (notifEnabled) {
      setNotifEnabled(false);
      localStorage.setItem(NOTIF_KEY, '0');
      toast.success('Notifications off');
      return;
    }
    if (Notification.permission === 'denied') {
      toast.error('Browser settings theke notification allow korun');
      return;
    }
    let perm: NotificationPermission = Notification.permission;
    if (perm === 'default') perm = await Notification.requestPermission();
    if (perm === 'granted') {
      setNotifEnabled(true);
      localStorage.setItem(NOTIF_KEY, '1');
      try {
        new Notification('Wintech Agro BD', {
          body: 'Notifications enabled — notun update gulo paben',
          icon: '/favicon.ico',
        });
      } catch {}
      toast.success('Notifications on');
    } else {
      toast.error('Notification permission deoa hoy nai');
    }
  };

  const logout = () => {
    useAuthStore.getState().logout();
    toast.success('Signed out');
    router.push('/login');
  };

  return (
    <header className="sticky top-0 z-30 bg-white border-b border-slate-200 dark:bg-gray-800 dark:border-gray-700 h-16 flex items-center px-4 lg:px-6 gap-3 shadow-[0_1px_3px_rgba(0,0,0,0.05)]">
      {/* Hamburger — mobile only */}
      <button
        onClick={onMenu}
        className="lg:hidden p-2 -ml-2 rounded-md hover:bg-slate-100 dark:hover:bg-gray-700 text-slate-600 dark:text-gray-300"
        aria-label="Open menu"
      >
        <Menu className="w-5 h-5" />
      </button>

      {/* Page title */}
      {title && (
        <div className="hidden md:block min-w-0 shrink-0">
          <h1 className="text-[15px] font-bold text-gray-900 dark:text-gray-100 leading-tight truncate">{title}</h1>
          {subtitle && <p className="text-xs text-gray-400 dark:text-gray-500 font-medium truncate">{subtitle}</p>}
        </div>
      )}

      {/* Search */}
      <div
        className={cn(
          'hidden md:flex items-center gap-3 h-10 px-3.5 rounded-lg transition-all',
          title ? 'ml-3 w-64 lg:w-80' : 'w-full max-w-md',
          searchFocus
            ? 'bg-white dark:bg-gray-700 shadow-md ring-1 ring-slate-200 dark:ring-gray-600'
            : 'bg-slate-100/70 dark:bg-gray-700/50 hover:bg-white dark:hover:bg-gray-700 hover:shadow-sm',
        )}
      >
        <Search className="w-4 h-4 text-slate-400 flex-shrink-0" />
        <input
          ref={searchInputRef}
          value={searchQ}
          onChange={(e) => setSearchQ(e.target.value)}
          onFocus={() => setSearchFocus(true)}
          onBlur={() => setSearchFocus(false)}
          placeholder="Search sales, products, parties…"
          className="flex-1 bg-transparent border-0 outline-none focus:outline-none focus:ring-0 text-sm placeholder:text-slate-400 dark:placeholder:text-gray-500 dark:text-gray-100 p-0"
          aria-label="Search"
        />
        {searchQ ? (
          <button
            onClick={() => { setSearchQ(''); searchInputRef.current?.focus(); }}
            className="p-0.5 rounded text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:bg-gray-600"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        ) : (
          <kbd className="hidden lg:inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-white dark:bg-gray-600 border border-slate-200 dark:border-gray-500 text-[10px] text-slate-500 dark:text-gray-400 font-mono">
            ⌘K
          </kbd>
        )}
      </div>

      {/* Mobile search icon */}
      <button
        onClick={() => searchInputRef.current?.focus()}
        className="md:hidden p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-gray-700 text-slate-600 dark:text-gray-300"
        aria-label="Search"
      >
        <Search className="w-5 h-5" />
      </button>

      {/* Branch selector */}
      <BranchSelector />

      <div className="flex-1" />

      {/* Actions slot (from pages) */}
      {actions && <div className="flex items-center gap-2">{actions}</div>}

      <div className="flex items-center gap-1 sm:gap-2">
        <QuickAdd />

        {/* Theme picker */}
        <div className="relative" ref={themeRef}>
          <button
            onClick={() => setThemeOpen((v) => !v)}
            className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-gray-700 text-slate-600 dark:text-gray-300 transition"
            aria-label="Theme"
            title="Sidebar theme"
          >
            <Palette className="w-5 h-5" />
          </button>
          {themeOpen && (
            <div className="absolute right-0 mt-2 w-56 bg-white dark:bg-gray-800 border border-slate-200 dark:border-gray-700 rounded-xl shadow-xl py-2 animate-slide-down z-40">
              <p className="px-4 pb-1.5 text-[10px] font-bold tracking-widest uppercase text-slate-400">Sidebar Theme</p>
              {themes.map((t) => (
                <button
                  key={t.value}
                  onClick={() => { setTheme(t.value); setThemeOpen(false); }}
                  className="w-full flex items-center gap-3 px-4 py-2 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-50 dark:hover:bg-gray-700 transition"
                >
                  <span className={cn('w-5 h-5 rounded-md flex-shrink-0 shadow-sm', t.swatch)} />
                  <span className="flex-1 text-left">{t.label}</span>
                  {theme === t.value && <Check className="w-4 h-4 text-blue-600" />}
                </button>
              ))}
            </div>
          )}
        </div>

        <NotificationBell />

        <button
          onClick={toggleNotifications}
          className={cn(
            'p-2 rounded-lg relative transition',
            notifEnabled
              ? 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 hover:bg-blue-100'
              : 'hover:bg-slate-100 dark:hover:bg-gray-700 text-slate-600 dark:text-gray-300',
          )}
          aria-label={notifEnabled ? 'Disable browser notifications' : 'Enable browser notifications'}
          title={notifEnabled ? 'Browser pop-ups on — click to turn off' : 'Click to enable browser pop-ups'}
        >
          {notifEnabled ? <Bell className="w-5 h-5" /> : <BellOff className="w-5 h-5" />}
        </button>

        {/* User menu */}
        <div className="relative" ref={ref}>
          <button
            onClick={() => setOpen((v) => !v)}
            className="flex items-center gap-2 pl-1.5 pr-2 py-1.5 rounded-full hover:bg-slate-100 dark:hover:bg-gray-700 transition"
          >
            <Avatar name={user?.name ?? 'A'} src={user?.avatar} size={32} />
            <div className="hidden sm:block text-left">
              <p className="text-sm font-semibold text-slate-900 dark:text-gray-100 leading-tight">{user?.name}</p>
              <p className="text-xs text-slate-500 dark:text-gray-400 capitalize leading-tight">{user?.role}</p>
            </div>
            <ChevronDown className="w-4 h-4 text-slate-400 hidden sm:block" />
          </button>

          {open && (
            <div className="absolute right-0 mt-2 w-56 bg-white dark:bg-gray-800 border border-slate-200 dark:border-gray-700 rounded-xl shadow-xl py-1 animate-slide-down z-40">
              <div className="px-4 py-3 border-b border-slate-100 dark:border-gray-700">
                <p className="text-sm font-semibold text-slate-900 dark:text-gray-100 truncate">{user?.name}</p>
                <p className="text-xs text-slate-500 dark:text-gray-400 truncate">{user?.email}</p>
              </div>
              <Link
                href="/settings"
                onClick={() => setOpen(false)}
                className="flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-50 dark:hover:bg-gray-700 transition"
              >
                <User className="w-4 h-4 text-slate-400" /> Profile & Settings
              </Link>
              <button
                onClick={logout}
                className="w-full flex items-center gap-2 px-4 py-2 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition"
              >
                <LogOut className="w-4 h-4" /> Sign Out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

// Default export alias so pages can use either import style
export default Topbar;
