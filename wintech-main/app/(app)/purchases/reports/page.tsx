'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import Link from 'next/link';
import { FileText, Building2, DollarSign, TrendingDown, Package, ArrowRight, Loader2 } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

interface PurchaseStat {
  supplierName?: string; subTotal: number; paidAmount: number; dueAmount: number;
  orderDate: string;
}

export default function PurchaseReportsPage() {
  const [purchases, setPurchases] = useState<PurchaseStat[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/purchases?limit=500').then(r => r.json()).then(d => {
      setPurchases(d.data || []);
      setTotal(d.total || 0);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const totalSpent = purchases.reduce((a, p) => a + (p.subTotal || 0), 0);
  const totalPaid = purchases.reduce((a, p) => a + (p.paidAmount || 0), 0);
  const totalDue = purchases.reduce((a, p) => a + (p.dueAmount || 0), 0);

  const bySupplier = Object.entries(
    purchases.reduce((acc, p) => {
      const sup = p.supplierName || 'Unknown';
      acc[sup] = (acc[sup] || 0) + (p.subTotal || 0);
      return acc;
    }, {} as Record<string, number>)
  ).map(([name, total]) => ({ name: name.length > 14 ? name.slice(0, 14) + '…' : name, total }))
    .sort((a, b) => b.total - a.total).slice(0, 8);

  const reportLinks = [
    { title: 'Purchase Orders', desc: 'All purchase order records', href: '/purchases', icon: FileText, color: 'blue' },
    { title: 'Supplier List', desc: 'All supplier accounts', href: '/purchases/suppliers', icon: Building2, color: 'emerald' },
    { title: 'Supplier Due List', desc: 'Outstanding supplier balances', href: '/purchases/reports/supplier-due', icon: DollarSign, color: 'amber' },
    { title: 'Stock Report', desc: 'Current inventory levels', href: '/inventory/reports', icon: Package, color: 'purple' },
  ];

  return (
    <div className="page-wrapper">
      <Topbar title="Purchase Reports" subtitle="All purchase-related analytics" />

      <div className="grid grid-cols-3 gap-4">
        <div className="card">
          <p className="text-2xl font-bold text-blue-600">{loading ? <Loader2 className="animate-spin" size={20} /> : `৳${(totalSpent / 1000).toFixed(1)}K`}</p>
          <p className="text-sm text-gray-500 mt-1">Total Purchased ({total} orders)</p>
        </div>
        <div className="card">
          <p className="text-2xl font-bold text-emerald-600">{loading ? '…' : `৳${(totalPaid / 1000).toFixed(1)}K`}</p>
          <p className="text-sm text-gray-500 mt-1">Paid</p>
        </div>
        <div className="card">
          <p className="text-2xl font-bold text-red-600">{loading ? '…' : `৳${(totalDue / 1000).toFixed(1)}K`}</p>
          <p className="text-sm text-gray-500 mt-1">Outstanding Due</p>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Available Reports</h3>
          <div className="space-y-3">
            {reportLinks.map(r => (
              <Link key={r.href} href={r.href} className="group flex items-center gap-4 p-4 border border-gray-100 rounded-2xl hover:border-blue-200 hover:bg-blue-50/40 transition-all">
                <div className={`w-10 h-10 bg-${r.color}-50 rounded-xl flex items-center justify-center`}>
                  <r.icon className={`w-4 h-4 text-${r.color}-500`} />
                </div>
                <div className="flex-1">
                  <p className="font-semibold text-gray-900">{r.title}</p>
                  <p className="text-xs text-gray-400">{r.desc}</p>
                </div>
                <ArrowRight size={16} className="text-gray-300 group-hover:text-blue-400 transition-colors" />
              </Link>
            ))}
          </div>
        </div>

        {bySupplier.length > 0 && (
          <div className="card">
            <h3 className="font-bold text-gray-900 mb-4">Top Suppliers by Purchase Value</h3>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={bySupplier} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis type="number" tick={{ fontSize: 11 }} tickFormatter={v => `৳${(v / 1000).toFixed(0)}K`} />
                <YAxis type="category" dataKey="name" tick={{ fontSize: 11 }} width={80} />
                <Tooltip formatter={(v: unknown) => `৳${Number(v).toLocaleString()}`} />
                <Bar dataKey="total" fill="#3b82f6" radius={[0, 4, 4, 0]} name="Purchase Amount" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      <div className="grid grid-cols-2 xl:grid-cols-3 gap-4">
        {[
          { label: 'Total Orders', value: total, icon: FileText, color: 'blue' },
          { label: 'Suppliers', value: Object.keys(purchases.reduce((a, p) => ({ ...a, [p.supplierName || '']: 1 }), {})).length, icon: Building2, color: 'emerald' },
          { label: 'Avg Order Value', value: total > 0 ? `৳${(totalSpent / total).toLocaleString(undefined, { maximumFractionDigits: 0 })}` : '—', icon: TrendingDown, color: 'purple' },
        ].map(s => (
          <div key={s.label} className="card flex items-center gap-4">
            <div className={`w-12 h-12 bg-${s.color}-50 rounded-xl flex items-center justify-center`}>
              <s.icon className={`w-5 h-5 text-${s.color}-600`} />
            </div>
            <div>
              <p className="text-xs text-gray-400">{s.label}</p>
              <p className={`text-2xl font-bold text-${s.color}-600`}>{loading ? '…' : s.value}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
