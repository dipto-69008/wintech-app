'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import Image from 'next/image';
import {
  LayoutDashboard, BarChart3, Package, Users, DollarSign, ShoppingCart,
  Truck, Target, Settings, LogOut, ChevronDown,
  UserCheck, Calendar, Clock, CalendarDays, Award, Megaphone, BadgeCheck,
  Layers, ClipboardList, FileText, PiggyBank, Wallet, Receipt, Banknote,
  Bell, FileBarChart, RotateCcw, Tag, ArrowLeftRight,
  Users2, ScrollText, PenLine,
  HardDrive, CreditCard, TrendingUp, Boxes, GripVertical, ChevronRight,
  Sun, Moon, PlusCircle, BarChart2, FlaskConical, MapPin, TrendingDown,
  ClipboardCheck, Leaf, Store
} from 'lucide-react';
import { useState, useEffect, useRef } from 'react';
import { useAuthStore } from '@/lib/store';
import { useRouter } from 'next/navigation';
import { useTheme } from 'next-themes';

interface NavChild {
  href: string;
  label: string;
  icon: React.ElementType;
}

interface Module {
  id: string;
  label: string;
  icon: React.ElementType;
  color: string;
  basePaths: string[];
  items: NavChild[];
}

const MODULES: Module[] = [
  {
    id: 'inventory',
    label: 'Inventory',
    icon: Package,
    color: 'text-emerald-400',
    basePaths: ['/inventory'],
    items: [
      { href: '/inventory', icon: Package, label: 'Products' },
      { href: '/inventory/categories', icon: Tag, label: 'Categories' },
      { href: '/inventory/adjustments', icon: ArrowLeftRight, label: 'Stock Adjustments' },
      { href: '/inventory/stock-reports', icon: BarChart2, label: 'Stock Reports' },
      { href: '/inventory/production', icon: FlaskConical, label: 'Production Unit' },
      { href: '/inventory/stock-transfer', icon: Truck, label: 'Stock Transfer' },
      { href: '/inventory/reports', icon: FileBarChart, label: 'Inventory Reports' },
    ],
  },
  {
    id: 'sales',
    label: 'Sales',
    icon: ShoppingCart,
    color: 'text-blue-400',
    basePaths: ['/sales'],
    items: [
      { href: '/sales/orders-entry', icon: PenLine, label: 'Orders Entry' },
      { href: '/sales', icon: ClipboardList, label: 'Sale Orders' },
      { href: '/sales/invoices', icon: FileText, label: 'Invoices' },
      { href: '/sales/returns', icon: RotateCcw, label: 'Returns' },
      { href: '/sales/quotations', icon: ScrollText, label: 'Quotations' },
      { href: '/sales/parties', icon: Users2, label: 'Parties' },
      { href: '/sales/dues', icon: TrendingDown, label: 'Sales Dues' },
      { href: '/sales/reports', icon: FileBarChart, label: 'Sales Reports' },
    ],
  },
  {
    id: 'purchases',
    label: 'Purchases',
    icon: Truck,
    color: 'text-orange-400',
    basePaths: ['/purchases'],
    items: [
      { href: '/purchases/new', icon: PenLine, label: 'New Purchase' },
      { href: '/purchases', icon: ClipboardList, label: 'Purchase Orders' },
      { href: '/purchases/returns', icon: RotateCcw, label: 'Purchase Returns' },
      { href: '/purchases/suppliers', icon: Users2, label: 'Suppliers' },
      { href: '/purchases/reports', icon: FileBarChart, label: 'Purchase Reports' },
    ],
  },
  {
    id: 'accounting',
    label: 'Accounting',
    icon: DollarSign,
    color: 'text-violet-400',
    basePaths: ['/accounting'],
    items: [
      { href: '/accounting', icon: Receipt, label: 'Transactions' },
      { href: '/accounting/accounts', icon: Wallet, label: 'Chart of Accounts' },
      { href: '/accounting/cheques', icon: CreditCard, label: 'Cheque Management' },
      { href: '/accounting/budget', icon: PiggyBank, label: 'Budget' },
    ],
  },
  {
    id: 'expenses',
    label: 'Expenses',
    icon: CreditCard,
    color: 'text-pink-400',
    basePaths: ['/expenses'],
    items: [
      { href: '/expenses', icon: CreditCard, label: 'Expense Claims' },
      { href: '/expenses/categories', icon: Tag, label: 'Expense Categories' },
    ],
  },
  {
    id: 'hr',
    label: 'HR',
    icon: Users,
    color: 'text-teal-400',
    basePaths: ['/hr'],
    items: [
      { href: '/hr', icon: Users, label: 'Employees' },
      { href: '/hr/payroll', icon: Banknote, label: 'Payroll' },
      { href: '/hr/attendance', icon: Clock, label: 'Attendance' },
      { href: '/hr/leaves', icon: CalendarDays, label: 'Leaves' },
      { href: '/hr/shift', icon: Calendar, label: 'Shift Roster' },
      { href: '/hr/holiday', icon: Award, label: 'Holidays' },
      { href: '/hr/designation', icon: BadgeCheck, label: 'Designations' },
      { href: '/hr/department', icon: Layers, label: 'Departments' },
      { href: '/hr/announcements', icon: Megaphone, label: 'Announcements' },
      { href: '/hr/reports', icon: FileBarChart, label: 'HR Reports' },
    ],
  },
  {
    id: 'targets',
    label: 'Targets',
    icon: BarChart2,
    color: 'text-lime-400',
    basePaths: ['/targets'],
    items: [
      { href: '/targets', icon: PlusCircle, label: 'Add Target' },
      { href: '/targets/report', icon: FileBarChart, label: 'Target Report' },
    ],
  },
  {
    id: 'assets',
    label: 'Assets',
    icon: Boxes,
    color: 'text-rose-400',
    basePaths: ['/assets'],
    items: [
      { href: '/assets', icon: HardDrive, label: 'Fixed Assets' },
      { href: '/assets/depreciation', icon: TrendingUp, label: 'Depreciation' },
    ],
  },
  {
    id: 'survey',
    label: 'Survey',
    icon: ClipboardCheck,
    color: 'text-cyan-400',
    basePaths: ['/survey'],
    items: [
      { href: '/survey', icon: Leaf, label: 'Farmer Visits' },
      { href: '/survey?tab=dealer', icon: Store, label: 'Dealer Visits' },
    ],
  },
];

const STORAGE_KEY = 'wintech-module-order';

function loadOrder(): string[] {
  if (typeof window === 'undefined') return MODULES.map(m => m.id);
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const parsed: string[] = JSON.parse(saved);
      const allIds = MODULES.map(m => m.id);
      const filtered = parsed.filter(id => allIds.includes(id));
      const missing = allIds.filter(id => !filtered.includes(id));
      return [...filtered, ...missing];
    }
  } catch {}
  return MODULES.map(m => m.id);
}

function saveOrder(order: string[]) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(order)); } catch {}
}

interface SidebarProps {
  open: boolean;
  onClose: () => void;
}

export default function Sidebar({ open, onClose }: SidebarProps) {
  const pathname = usePathname();
  const { user, logout } = useAuthStore();
  const router = useRouter();
  const { theme, setTheme } = useTheme();
  const [moduleOrder, setModuleOrder] = useState<string[]>([]);
  const [activeModuleId, setActiveModuleId] = useState<string | null>(null);
  const [reportsOpen, setReportsOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [mounted, setMounted] = useState(false);

  const dragId = useRef<string | null>(null);
  const [dragOver, setDragOver] = useState<string | null>(null);

  useEffect(() => { setMounted(true); }, []);
  useEffect(() => { setModuleOrder(loadOrder()); }, []);

  useEffect(() => {
    const matched = MODULES.find(m => m.basePaths.some(p => pathname === p || pathname.startsWith(p + '/')));
    if (matched) {
      setActiveModuleId(matched.id);
    } else if (pathname === '/dashboard' || pathname.startsWith('/reports')) {
      setActiveModuleId(null);
    }
  }, [pathname]);

  const orderedModules = moduleOrder
    .map(id => MODULES.find(m => m.id === id))
    .filter(Boolean) as Module[];

  // Only match startsWith for sub-pages (href has 2+ path segments), never for module roots
  const isActive = (href: string) => {
    if (pathname === href) return true;
    const segments = href.split('/').filter(Boolean);
    return segments.length >= 2 && pathname.startsWith(href + '/');
  };

  const roleColor: Record<string, string> = {
    admin: 'from-blue-500 to-violet-600',
    manager: 'from-emerald-500 to-teal-600',
    employee: 'from-amber-500 to-orange-500',
  };
  const gradClass = roleColor[user?.role ?? 'employee'] ?? roleColor.employee;

  const reportsItems = [
    { href: '/reports/sales', icon: ShoppingCart, label: 'Sales Reports' },
    { href: '/reports/purchases', icon: Truck, label: 'Purchase Reports' },
    { href: '/reports/hr', icon: Users, label: 'HR Reports' },
    { href: '/reports/inventory', icon: Package, label: 'Inventory Reports' },
    { href: '/reports/accounting', icon: DollarSign, label: 'Accounting Reports' },
  ];

  const handleDragStart = (id: string) => { dragId.current = id; };
  const handleDragOver = (e: React.DragEvent, id: string) => { e.preventDefault(); setDragOver(id); };
  const handleDrop = (targetId: string) => {
    if (!dragId.current || dragId.current === targetId) { setDragOver(null); return; }
    const newOrder = [...moduleOrder];
    const fromIdx = newOrder.indexOf(dragId.current);
    const toIdx = newOrder.indexOf(targetId);
    newOrder.splice(fromIdx, 1);
    newOrder.splice(toIdx, 0, dragId.current);
    setModuleOrder(newOrder);
    saveOrder(newOrder);
    dragId.current = null;
    setDragOver(null);
  };
  const handleDragEnd = () => { dragId.current = null; setDragOver(null); };
  const handleSignOut = () => { logout(); router.push('/login'); onClose(); };

  const isDark = mounted && theme === 'dark';

  const sidebarContent = (
    <aside
      className={`${collapsed ? 'w-[68px]' : 'w-[240px]'} bg-[#0d1526] h-full flex flex-col transition-all duration-300 flex-shrink-0 relative`}
      style={{ fontFamily: 'var(--font-inter)' }}
    >
      {/* Logo */}
      <div className={`flex items-center ${collapsed ? 'justify-center' : 'justify-between'} px-4 py-4 border-b border-white/[0.07] flex-shrink-0`}>
        {!collapsed && (
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="w-8 h-8 rounded-xl overflow-hidden flex-shrink-0 shadow-lg shadow-green-900/40">
              <Image src="/wintech.jpeg" alt="Wintech Logo" width={32} height={32} className="w-full h-full object-cover" />
            </div>
            <div className="min-w-0">
              <span className="text-white font-bold text-[14px] tracking-tight leading-none block truncate">WINTECH AGRO BD</span>
              <p className="text-[9px] text-emerald-400/70 leading-none mt-0.5 font-medium truncate">Fish Import & Distribution</p>
            </div>
          </div>
        )}
        {collapsed && (
          <div className="w-8 h-8 rounded-xl overflow-hidden shadow-lg shadow-green-900/40">
            <Image src="/wintech.jpeg" alt="Wintech Logo" width={32} height={32} className="w-full h-full object-cover" />
          </div>
        )}
        {!collapsed && (
          <button
            onClick={() => setCollapsed(true)}
            className="w-7 h-7 flex items-center justify-center rounded-lg text-gray-600 hover:text-gray-300 hover:bg-white/5 transition-colors ml-1 flex-shrink-0"
            title="Collapse"
          >
            <ChevronRight size={14} />
          </button>
        )}
        {collapsed && (
          <button
            onClick={() => setCollapsed(false)}
            className="absolute -right-3.5 top-5 w-7 h-7 flex items-center justify-center rounded-lg text-gray-500 hover:text-white hover:bg-white/5 transition-colors bg-[#0d1526] border border-white/10 shadow-md z-10"
            title="Expand"
          >
            <ChevronRight size={13} className="rotate-180" />
          </button>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-3 px-2.5 space-y-0.5 scrollbar-thin">
        {/* Dashboard */}
        <Link
          href="/dashboard"
          onClick={onClose}
          title={collapsed ? 'Dashboard' : undefined}
          className={`flex items-center gap-3 px-2.5 py-2 rounded-xl text-[13px] font-medium transition-all duration-150 relative
            ${isActive('/dashboard')
              ? 'bg-blue-600 text-white shadow-md shadow-blue-900/50'
              : 'text-gray-400 hover:bg-white/[0.06] hover:text-gray-200'
            }`}
        >
          {isActive('/dashboard') && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-white rounded-r-full" />}
          <LayoutDashboard size={16} className="flex-shrink-0" />
          {!collapsed && <span className="flex-1 truncate">Dashboard</span>}
        </Link>

        {/* Reports */}
        <div>
          <button
            onClick={() => setReportsOpen(v => !v)}
            title={collapsed ? 'Reports' : undefined}
            className={`w-full flex items-center gap-3 px-2.5 py-2 rounded-xl text-[13px] font-medium transition-all duration-150 relative
              ${pathname.startsWith('/reports')
                ? 'text-blue-400 bg-blue-500/[0.08]'
                : 'text-gray-400 hover:bg-white/[0.06] hover:text-gray-200'
              }`}
          >
            {pathname.startsWith('/reports') && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-blue-500 rounded-r-full" />}
            <BarChart3 size={16} className="flex-shrink-0" />
            {!collapsed && (
              <>
                <span className="flex-1 text-left truncate">Reports</span>
                <ChevronDown size={13} className={`flex-shrink-0 transition-transform duration-200 opacity-50 ${reportsOpen ? '' : '-rotate-90'}`} />
              </>
            )}
          </button>
          {reportsOpen && !collapsed && (
            <div className="ml-3 mt-0.5 pl-3 border-l border-white/[0.07] space-y-0.5 pb-1">
              {reportsItems.map(item => {
                const active = isActive(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={onClose}
                    className={`flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-[12px] font-medium transition-all
                      ${active ? 'bg-blue-600/20 text-blue-400' : 'text-gray-500 hover:bg-white/[0.05] hover:text-gray-300'}`}
                  >
                    <item.icon size={13} className="flex-shrink-0 opacity-80" />
                    <span className="truncate">{item.label}</span>
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        {/* Divider */}
        <div className="border-t border-white/[0.06] my-2 mx-1" />

        {!collapsed && (
          <p className="text-[9px] font-black text-gray-600 uppercase tracking-[0.14em] px-2.5 py-1 select-none">
            Modules
          </p>
        )}

        {/* Draggable module list */}
        {orderedModules.map(mod => {
          const isActiveModule = activeModuleId === mod.id;
          const isDragTarget = dragOver === mod.id;
          return (
            <div
              key={mod.id}
              draggable
              onDragStart={() => handleDragStart(mod.id)}
              onDragOver={e => handleDragOver(e, mod.id)}
              onDrop={() => handleDrop(mod.id)}
              onDragEnd={handleDragEnd}
              className={`rounded-xl transition-all duration-150 ${isDragTarget ? 'ring-1 ring-blue-500/50 bg-blue-500/5' : ''}`}
            >
              <button
                onClick={() => setActiveModuleId(isActiveModule ? null : mod.id)}
                title={collapsed ? mod.label : undefined}
                className={`w-full flex items-center gap-3 px-2.5 py-2 rounded-xl text-[13px] font-medium transition-all duration-150 relative group
                  ${isActiveModule
                    ? `${mod.color} bg-white/[0.06]`
                    : 'text-gray-400 hover:bg-white/[0.06] hover:text-gray-200'
                  }`}
              >
                {isActiveModule && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-current rounded-r-full opacity-70" />}
                {!collapsed && (
                  <GripVertical size={12} className="flex-shrink-0 opacity-0 group-hover:opacity-30 transition-opacity cursor-grab absolute left-[-2px]" />
                )}
                <mod.icon size={16} className="flex-shrink-0" />
                {!collapsed && (
                  <>
                    <span className="flex-1 text-left truncate">{mod.label}</span>
                    <ChevronDown size={13} className={`flex-shrink-0 transition-transform duration-200 opacity-40 ${isActiveModule ? '' : '-rotate-90'}`} />
                  </>
                )}
              </button>
              {isActiveModule && !collapsed && (
                <div className="ml-3 mt-0.5 pl-3 border-l border-white/[0.07] space-y-0.5 pb-1">
                  {mod.items.map(item => {
                    const active = isActive(item.href);
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        onClick={onClose}
                        className={`flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-[12px] font-medium transition-all
                          ${active ? 'bg-blue-600/20 text-blue-400' : 'text-gray-500 hover:bg-white/[0.05] hover:text-gray-300'}`}
                      >
                        <item.icon size={13} className="flex-shrink-0 opacity-80" />
                        <span className="truncate">{item.label}</span>
                      </Link>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}

        {/* Divider */}
        <div className="border-t border-white/[0.06] my-2 mx-1" />

        {/* Branches */}
        <Link
          href="/settings/branches"
          onClick={onClose}
          title={collapsed ? 'Branches' : undefined}
          className={`flex items-center gap-3 px-2.5 py-2 rounded-xl text-[13px] font-medium transition-all duration-150 relative
            ${isActive('/settings/branches')
              ? 'bg-blue-600 text-white shadow-md shadow-blue-900/50'
              : 'text-gray-400 hover:bg-white/[0.06] hover:text-gray-200'
            }`}
        >
          {isActive('/settings/branches') && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-white rounded-r-full" />}
          <MapPin size={16} className="flex-shrink-0" />
          {!collapsed && <span className="flex-1 truncate">Branches</span>}
        </Link>

        {/* Settings */}
        <Link
          href="/settings"
          onClick={onClose}
          title={collapsed ? 'Settings' : undefined}
          className={`flex items-center gap-3 px-2.5 py-2 rounded-xl text-[13px] font-medium transition-all duration-150 relative
            ${isActive('/settings')
              ? 'bg-blue-600 text-white shadow-md shadow-blue-900/50'
              : 'text-gray-400 hover:bg-white/[0.06] hover:text-gray-200'
            }`}
        >
          {isActive('/settings') && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-white rounded-r-full" />}
          <Settings size={16} className="flex-shrink-0" />
          {!collapsed && <span className="flex-1 truncate">Settings</span>}
        </Link>
      </nav>

      {/* Bottom — user, theme toggle, logout */}
      <div className="border-t border-white/[0.07] p-3 space-y-1 flex-shrink-0">
        {/* User info */}
        {!collapsed && user && (
          <div className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl hover:bg-white/[0.04] transition-colors cursor-default">
            <div className={`w-8 h-8 bg-gradient-to-br ${gradClass} rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0 shadow-lg`}>
              {user.name?.charAt(0).toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-white text-[13px] font-semibold truncate leading-tight">{user.name}</p>
              <p className="text-gray-500 text-[11px] capitalize leading-tight mt-0.5">{user.role}</p>
            </div>
          </div>
        )}

        {/* Theme toggle */}
        {mounted && (
          <button
            onClick={() => setTheme(isDark ? 'light' : 'dark')}
            title={isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
            className="w-full flex items-center gap-3 px-2.5 py-2 rounded-xl text-[12px] font-semibold text-gray-500 hover:bg-white/[0.06] hover:text-gray-200 transition-colors"
          >
            {isDark ? <Sun size={15} className="flex-shrink-0 text-amber-400" /> : <Moon size={15} className="flex-shrink-0 text-blue-400" />}
            {!collapsed && (
              <span>{isDark ? 'Light Mode' : 'Dark Mode'}</span>
            )}
          </button>
        )}

        {/* Sign Out */}
        <button
          onClick={handleSignOut}
          title={collapsed ? 'Sign Out' : undefined}
          className="w-full flex items-center gap-3 px-2.5 py-2 rounded-xl text-[12px] font-semibold text-gray-500 hover:bg-red-500/10 hover:text-red-400 transition-colors"
        >
          <LogOut size={15} className="flex-shrink-0" />
          {!collapsed && 'Sign Out'}
        </button>
      </div>
    </aside>
  );

  return (
    <>
      {/* Desktop */}
      <div className="hidden md:flex h-screen sticky top-0 flex-shrink-0">
        {sidebarContent}
      </div>

      {/* Mobile drawer */}
      {open && (
        <div className="md:hidden fixed inset-0 z-50 flex">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
          <div className="relative h-full overflow-y-auto">
            {sidebarContent}
          </div>
        </div>
      )}
    </>
  );
}
