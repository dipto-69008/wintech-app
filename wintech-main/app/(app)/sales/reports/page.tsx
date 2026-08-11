'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import Link from 'next/link';
import { FileText, Users2, DollarSign, RotateCcw, Tag, CreditCard, ClipboardList, ScrollText, TrendingUp, ArrowRight, Loader2 } from 'lucide-react';

const reportItems = [
  { title: 'Sales Invoice', desc: 'All confirmed sales invoices', href: '/sales/invoices', icon: FileText, color: 'blue' },
  { title: 'Sales Return List', desc: 'List of all sales returns', href: '/sales/returns', icon: RotateCcw, color: 'red' },
  { title: 'Party Due List', desc: 'Parties with outstanding balance', href: '/sales/reports/party-due', icon: CreditCard, color: 'amber' },
  { title: 'Party Payment Report', desc: 'Payment history by party', href: '/sales/reports/party-payment', icon: DollarSign, color: 'emerald' },
  { title: 'Party List', desc: 'Complete party directory', href: '/sales/parties', icon: Users2, color: 'purple' },
  { title: 'Product Price List', desc: 'All products with current prices', href: '/sales/reports/price-list', icon: Tag, color: 'indigo' },
  { title: 'Quotation Invoice', desc: 'Accepted quotations as invoices', href: '/sales/quotations', icon: ScrollText, color: 'cyan' },
  { title: 'Sales Summary', desc: 'Monthly and yearly sales overview', href: '/sales/reports/summary', icon: TrendingUp, color: 'orange' },
  { title: 'Sales Dues Statement', desc: 'Zone-wise party dues report', href: '/sales/dues', icon: ClipboardList, color: 'rose' },
];

function fmt(n: number) {
  if (n >= 1_00_00_000) return `৳${(n / 1_00_00_000).toFixed(1)} Cr`;
  if (n >= 1_00_000) return `৳${(n / 1_00_000).toFixed(1)}L`;
  if (n >= 1_000) return `৳${(n / 1_000).toFixed(1)}K`;
  return `৳${n.toLocaleString()}`;
}

export default function SalesReportsPage() {
  const [loading, setLoading] = useState(true);
  const [totalRevenue, setTotalRevenue] = useState(0);
  const [thisMonthSales, setThisMonthSales] = useState(0);
  const [totalDues, setTotalDues] = useState(0);

  useEffect(() => {
    fetch('/api/monthly-summary?months=12')
      .then(r => r.ok ? r.json() : null)
      .then(data => {
        if (data) {
          setTotalRevenue(data.totalRevenue ?? 0);
          setThisMonthSales(data.thisMonthSales ?? 0);
          setTotalDues(data.totalDues ?? 0);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const stats = [
    { label: 'Total Revenue', value: fmt(totalRevenue), color: 'blue' },
    { label: 'This Month', value: fmt(thisMonthSales), color: 'emerald' },
    { label: 'Total Outstanding', value: fmt(totalDues), color: 'amber' },
  ];

  return (
    <div className="page-wrapper">
      <Topbar title="Sales Reports" subtitle="All sales-related reports and analytics" />

      <div className="grid grid-cols-3 gap-4">
        {loading ? (
          <div className="col-span-3 flex items-center justify-center py-8 text-gray-400 gap-2">
            <Loader2 className="animate-spin" size={18} /><span className="text-sm">Loading…</span>
          </div>
        ) : stats.map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 dark:text-white mb-4 text-lg">Available Reports</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3">
          {reportItems.map((r) => (
            <Link key={r.href} href={r.href}
              className="group flex items-center gap-4 p-4 border border-gray-100 dark:border-gray-700 rounded-2xl hover:border-blue-200 hover:bg-blue-50/40 dark:hover:border-blue-700 dark:hover:bg-blue-900/10 transition-all">
              <div className={`w-11 h-11 bg-${r.color}-50 dark:bg-${r.color}-900/20 rounded-xl flex items-center justify-center flex-shrink-0`}>
                <r.icon className={`w-5 h-5 text-${r.color}-500`} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-gray-900 dark:text-white text-sm">{r.title}</p>
                <p className="text-xs text-gray-400 mt-0.5 truncate">{r.desc}</p>
              </div>
              <ArrowRight size={16} className="text-gray-300 group-hover:text-blue-400 flex-shrink-0 transition-colors" />
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
