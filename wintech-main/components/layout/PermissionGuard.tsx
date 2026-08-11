'use client';

import { useEffect, useRef } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import { getPermissionForPath } from '@/lib/permissions';

export function PermissionGuard({
  permissions,
  children,
}: {
  permissions: string[];
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const blockedRef = useRef<string | null>(null);

  useEffect(() => {
    const required = getPermissionForPath(pathname);
    if (!required) return;
    if (permissions.includes(required)) return;
    if (blockedRef.current === pathname) return;
    blockedRef.current = pathname;
    toast.error('You do not have access to this page');
    if (permissions.includes('view.dashboard')) {
      router.replace('/dashboard');
    } else if (permissions[0]) {
      const fallback = permissions[0].split('.')[1] || 'dashboard';
      router.replace('/' + fallback.replace(/\./g, '/'));
    } else {
      router.replace('/login');
    }
  }, [pathname, permissions, router]);

  return <>{children}</>;
}
