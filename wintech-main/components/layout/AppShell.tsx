'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Sidebar from '@/components/layout/Sidebar';
import { useAuthStore } from '@/lib/store';
import { MobileMenuContext } from '@/components/layout/MobileMenuContext';

const PAYMENT_CHECK_KEY = 'payment_reminder_last_check';

export default function AppShell({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, _hasHydrated } = useAuthStore();
  const router = useRouter();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    if (_hasHydrated && !isAuthenticated) router.push('/login');
  }, [_hasHydrated, isAuthenticated, router]);

  // Run payment reminder check once per day on app load
  useEffect(() => {
    if (!isAuthenticated) return;
    const today = new Date().toISOString().split('T')[0];
    const lastCheck = localStorage.getItem(PAYMENT_CHECK_KEY);
    if (lastCheck === today) return;
    Promise.all([
      fetch('/api/payment-reminder-check'),
      fetch('/api/credit-limit-check'),
    ]).then(() => {
      localStorage.setItem(PAYMENT_CHECK_KEY, today);
    }).catch(() => {});
  }, [isAuthenticated]);

  // Wait for zustand to rehydrate from localStorage before deciding
  if (!_hasHydrated) return null;
  if (!isAuthenticated) return null;

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50 dark:bg-gray-900">
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <main className="flex-1 overflow-auto min-w-0">
        <MobileMenuContext.Provider value={() => setSidebarOpen(v => !v)}>
          {children}
        </MobileMenuContext.Provider>
      </main>
    </div>
  );
}
