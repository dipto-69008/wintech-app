'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, AreaChart, Area, CartesianGrid } from 'recharts';
import { FileText, ShoppingCart, Package, Users, DollarSign, RotateCcw, CreditCard, ArrowRight } from 'lucide-react';
import Link from 'next/link';

interface MonthlyPoint { month: string; sales: number; dues: number; collection: number; }

const REPORT_SECTIONS = [
  {
    title: 'Sales Reports', color: 'blue', icon: ShoppingCart,
    items: [
      { label: 'Sales Invoice', href: '/sales/invoices' },
      { label: 'Sales Record', href: '/sales' },
      { label: 'Sale Return List', href: '/sales/returns' },
      { label: 'Party Due List', href: '/sales/reports/party-due' },
      { label: 'Party Payment Report', href: '/sales/reports/party-payment' },
      { label: 'Party List', href: '/sales/parties' },
      { label: 'Product Price List', href: '/sales/reports/price-list' },
      { label: 'Quotation Invoice', href: '/sales/quotations' },
      { label: 'Sales Summary', href: '/sales/reports/summary' },
      { label: 'Sales Dues Statement', href: '/sales/dues' },
    ],
  },
  {
    title: 'Purchase Reports', color: 'purple', icon: Package,
    items: [
      { label: 'Purchase Invoice', href: '/purchases' },
      { label: 'Supplier Due Report', href: '/purchases/reports/supplier-due' },
      { label: 'Supplier Payment Report', href: '/purchases/reports' },
      { label: 'Supplier List', href: '/purchases/suppliers' },
      { label: 'Purchase Return List', href: '/purchases/returns' },
      { label: 'Stock Reports', href: '/inventory/stock-reports' },
      { label: 'Production Unit', href: '/inventory/production' },
    ],
  },
  {
    title: 'Accounts Reports', color: 'emerald', icon: DollarSign,
    items: [
      { label: 'Profit & Loss Report', href: '/reports/accounting' },
      { label: 'Cash View', href: '/accounting' },
      { label: 'Bank Transaction Report', href: '/accounting/accounts' },
      { label: 'Cheque Management', href: '/accounting/cheques' },
      { label: 'Transaction Accounts', href: '/accounting/accounts' },
      { label: 'Budget', href: '/accounting/budget' },
    ],
  },
  {
    title: 'HR & Payroll Reports', color: 'amber', icon: Users,
    items: [
      { label: 'Employee List', href: '/hr' },
      { label: 'Salary Payment Report', href: '/hr/payroll' },
      { label: 'Payroll Report', href: '/hr/reports/payroll' },
      { label: 'Attendance Report', href: '/hr/reports/attendance' },
      { label: 'Leave Report', href: '/hr/reports/leaves' },
    ],
  },
];

const COLOR_MAP: Record<string, { bg: string; border: string; text: string; hover: string }> = {
  blue:    { bg: 'bg-blue-50/70 dark:bg-blue-900/10',    border: 'border-blue-100 dark:border-blue-800/40',    text: 'text-blue-700 dark:text-blue-300',    hover: 'hover:bg-blue-100 dark:hover:bg-blue-900/30 hover:text-blue-700 dark:hover:text-blue-300' },
  purple:  { bg: 'bg-purple-50/70 dark:bg-purple-900/10', border: 'border-purple-100 dark:border-purple-800/40', text: 'text-purple-700 dark:text-purple-300',  hover: 'hover:bg-purple-100 dark:hover:bg-purple-900/30 hover:text-purple-700 dark:hover:text-purple-300' },
  emerald: { bg: 'bg-emerald-50/70 dark:bg-emerald-900/10',border:'border-emerald-100 dark:border-emerald-800/40',text:'text-emerald-700 dark:text-emerald-300', hover:'hover:bg-emerald-100 dark:hover:bg-emerald-900/30 hover:text-emerald-700 dark:hover:text-emerald-300' },
  amber:   { bg: 'bg-amber-50/70 dark:bg-amber-900/10',   border: 'border-amber-100 dark:border-amber-800/40',   text: 'text-amber-700 dark:text-amber-300',   hover: 'hover:bg-amber-100 dark:hover:bg-amber-900/30 hover:text-amber-700 dark:hover:text-amber-300' },
};

export default function ReportsPage() {
  const [monthly, setMonthly] = useState<MonthlyPoint[]>([]);

  useEffect(() => {
    fetch('/api/monthly-summary?months=6')
      .then(r => r.ok ? r.json() : { monthly: [] })
      .then(j => setMonthly(j.monthly || []))
      .catch(() => {});
  }, []);

  return (
    <div className="page-wrapper">
      <Topbar title="Reports Module" subtitle="All business reports in one place" />

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 mb-4">
        <div className="card">
          <h3 className="font-bold text-gray-900 dark:text-white mb-4 text-sm">Sales vs Outstanding (Monthly)</h3>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={monthly} margin={{ left: -20 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
              <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} tickFormatter={v => `৳${(v / 1000).toFixed(0)}K`} />
              <Tooltip formatter={(v: any, n: any) => [`৳${Number(v).toLocaleString()}`, n]} />
              <Bar dataKey="sales" fill="#3b82f6" radius={[4, 4, 0, 0]} name="Sales" />
              <Bar dataKey="collection" fill="#10b981" radius={[4, 4, 0, 0]} name="Collection" />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card">
          <h3 className="font-bold text-gray-900 dark:text-white mb-4 text-sm">Outstanding Dues Trend</h3>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={monthly} margin={{ left: -20 }}>
              <defs>
                <linearGradient id="gDues" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#8b5cf6" stopOpacity={0.2} />
                  <stop offset="95%" stopColor="#8b5cf6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
              <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} tickFormatter={v => `৳${(v / 1000).toFixed(0)}K`} />
              <Tooltip formatter={(v: any) => [`৳${Number(v).toLocaleString()}`, 'Outstanding']} />
              <Area type="monotone" dataKey="dues" stroke="#8b5cf6" strokeWidth={2.5} fill="url(#gDues)" name="Outstanding" dot={{ fill: '#8b5cf6', r: 4 }} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        {REPORT_SECTIONS.map(section => {
          const c = COLOR_MAP[section.color];
          return (
            <div key={section.title} className={`rounded-2xl border ${c.border} ${c.bg} p-4`}>
              <div className={`flex items-center gap-2 ${c.text} font-bold text-sm mb-3`}>
                <section.icon size={16} />
                {section.title}
              </div>
              <div className="space-y-0.5">
                {section.items.map(item => (
                  <Link key={item.href + item.label} href={item.href}
                    className={`flex items-center gap-2 px-2 py-1.5 rounded-lg text-xs text-gray-600 dark:text-gray-400 transition-all ${c.hover}`}>
                    <FileText size={11} className="flex-shrink-0 opacity-60" />
                    {item.label}
                    <ArrowRight size={10} className="ml-auto opacity-40" />
                  </Link>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
