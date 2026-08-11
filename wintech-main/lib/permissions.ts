const PATH_PERMISSIONS: { pattern: RegExp; permission: string }[] = [
  { pattern: /^\/dashboard/, permission: 'view.dashboard' },
  { pattern: /^\/sales/, permission: 'view.sales' },
  { pattern: /^\/purchases/, permission: 'view.purchases' },
  { pattern: /^\/inventory/, permission: 'view.inventory' },
  { pattern: /^\/hr/, permission: 'view.hr' },
  { pattern: /^\/accounting/, permission: 'view.accounting' },
  { pattern: /^\/expenses/, permission: 'view.expenses' },
  { pattern: /^\/assets/, permission: 'view.assets' },
  { pattern: /^\/reports/, permission: 'view.reports' },
  { pattern: /^\/targets/, permission: 'view.targets' },
  { pattern: /^\/settings/, permission: 'view.settings' },
];

export function getPermissionForPath(pathname: string): string | null {
  for (const { pattern, permission } of PATH_PERMISSIONS) {
    if (pattern.test(pathname)) return permission;
  }
  return null;
}
