'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { TrendingUp, ShoppingCart, CheckCircle2, XCircle, Loader2 } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444'];

interface Sale { _id: string; status: string; subTotal: number; partyName: string; }
interface MonthlyData { month: string; sales: number; }

export default function SalesSummaryPage() {
  const [loading, setLoading] = useState(true);
  const [sales, setSales] = useState<Sale[]>([]);
  const [monthly, setMonthly] = useState<MonthlyData[]>([]);

  useEffect(() => {
    Promise.all([
      fetch('/api/sales?limit=1000').then(r => r.ok ? r.json() : { data: [] }),
      fetch('/api/monthly-summary?months=6').then(r => r.ok ? r.json() : { monthly: [] }),
    ]).then(([sj, mj]) => {
      setSales(sj.data || []);
      setMonthly((mj.monthly || []).map((m: any) => ({ month: m.month, sales: m.sales })));
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const totalRevenue = sales.reduce((a, o) => a + (o.subTotal || 0), 0);
  const approved = sales.filter(o => o.status === 'a').length;
  const pending = sales.filter(o => o.status === 'pending').length;

  const byStatus = [
    { name: 'Approved', value: approved, amount: sales.filter(o=>o.status==='a').reduce((a,o)=>a+(o.subTotal||0),0) },
    { name: 'Pending', value: pending, amount: sales.filter(o=>o.status==='pending').reduce((a,o)=>a+(o.subTotal||0),0) },
  ].filter(s => s.value > 0);

  const byParty = Object.entries(
    sales.reduce((acc, o) => { if (o.partyName) acc[o.partyName] = (acc[o.partyName] || 0) + (o.subTotal || 0); return acc; }, {} as Record<string, number>)
  ).map(([name, total]) => ({ name: name.length > 12 ? name.slice(0, 12) + '…' : name, total }))
    .sort((a, b) => b.total - a.total).slice(0, 8);

  const fmt = (v: number) => `৳${(v/1000).toFixed(0)}K`;

  if (loading) return (
    <div className="page-wrapper">
      <Topbar title="Sales Summary" subtitle="Overview of all sales performance" />
      <div className="flex justify-center py-20"><Loader2 className="animate-spin text-gray-400" size={28} /></div>
    </div>
  );

  return (
    <div className="page-wrapper">
      <Topbar title="Sales Summary" subtitle="Overview of all sales performance" />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Revenue', value: fmt(totalRevenue), color: 'blue', icon: TrendingUp },
          { label: 'Total Orders', value: sales.length, color: 'purple', icon: ShoppingCart },
          { label: 'Approved', value: approved, color: 'emerald', icon: CheckCircle2 },
          { label: 'Pending', value: pending, color: 'amber', icon: XCircle },
        ].map(s => (
          <div key={s.label} className="card flex items-center gap-4">
            <div className={`w-12 h-12 bg-${s.color}-50 dark:bg-${s.color}-900/20 rounded-2xl flex items-center justify-center`}>
              <s.icon className={`w-5 h-5 text-${s.color}-500`} />
            </div>
            <div><p className="text-2xl font-bold text-gray-900 dark:text-white">{s.value}</p><p className="text-xs text-gray-400">{s.label}</p></div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <div className="card">
          <h3 className="font-bold text-gray-900 dark:text-white mb-4">Monthly Sales (from Sales Dues)</h3>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={monthly} margin={{ left: -20, right: 5 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
              <XAxis dataKey="month" tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} tickFormatter={v => `৳${(v/1000).toFixed(0)}K`} />
              <Tooltip formatter={(v: any) => [`৳${Number(v).toLocaleString()}`, 'Sales']} />
              <Bar dataKey="sales" fill="#3b82f6" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {byParty.length > 0 ? (
          <div className="card">
            <h3 className="font-bold text-gray-900 dark:text-white mb-4">Revenue by Party</h3>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={byParty} margin={{ left: -20, right: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <Tooltip formatter={(v: any) => [`৳${Number(v).toLocaleString()}`, 'Revenue']} />
                <Bar dataKey="total" fill="#10b981" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        ) : byStatus.length > 0 ? (
          <div className="card">
            <h3 className="font-bold text-gray-900 dark:text-white mb-4">Orders by Status</h3>
            <ResponsiveContainer width="100%" height={180}>
              <PieChart>
                <Pie data={byStatus} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={70} innerRadius={35}>
                  {byStatus.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Pie>
                <Tooltip formatter={(v, n) => [`${v} orders`, n]} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        ) : null}
      </div>
    </div>
  );
}
