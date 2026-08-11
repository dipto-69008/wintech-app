'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { DollarSign, Loader2, Search } from 'lucide-react';

interface Party { _id: string; name: string; email?: string; phone?: string; balance: number; totalOrders: number; totalSpent: number; }

export default function PartyPaymentPage() {
  const [loading, setLoading] = useState(true);
  const [parties, setParties] = useState<Party[]>([]);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetch('/api/parties?limit=1000')
      .then(r => r.ok ? r.json() : { data: [] })
      .then(j => setParties(j.data || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const filtered = parties
    .filter(c => (c.totalOrders || 0) > 0 || (c.totalSpent || 0) > 0)
    .filter(c => !search || c.name.toLowerCase().includes(search.toLowerCase()));

  const totalSpent = filtered.reduce((a, c) => a + (c.totalSpent || 0), 0);
  const totalDue = filtered.reduce((a, c) => a + (c.balance || 0), 0);
  const fmt = (n: number) => `৳${n.toLocaleString()}`;

  return (
    <div className="page-wrapper">
      <Topbar title="Party Payment Report" subtitle="Payment status by party" />

      <div className="grid grid-cols-3 gap-4">
        <div className="card"><p className="text-2xl font-bold text-emerald-600">{fmt(totalSpent)}</p><p className="text-sm text-gray-500 mt-1">Total Spent</p></div>
        <div className="card"><p className="text-2xl font-bold text-red-600">{fmt(totalDue)}</p><p className="text-sm text-gray-500 mt-1">Total Outstanding</p></div>
        <div className="card"><p className="text-2xl font-bold text-blue-600">{filtered.length}</p><p className="text-sm text-gray-500 mt-1">Active Parties</p></div>
      </div>

      <div className="card">
        <div className="section-header mb-4">
          <h3 className="font-bold text-gray-900 dark:text-white">Party Payment History</h3>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search…" className="form-input pl-9 w-56" />
          </div>
        </div>
        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead><tr>{['Party', 'Orders', 'Total Spent', 'Balance Due', 'Status'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.map(c => (
                  <tr key={c._id} className="table-row">
                    <td className="table-cell">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-gradient-to-br from-emerald-400 to-blue-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{c.name.charAt(0)}</div>
                        <div>
                          <p className="font-semibold text-gray-900 dark:text-white text-sm">{c.name}</p>
                          {c.email && <p className="text-xs text-gray-400">{c.email}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="table-cell text-center font-semibold text-gray-700">{c.totalOrders || 0}</td>
                    <td className="table-cell font-bold text-gray-700">{fmt(c.totalSpent || 0)}</td>
                    <td className="table-cell font-bold">
                      <span className={(c.balance || 0) > 0 ? 'text-red-600' : 'text-emerald-600'}>{fmt(c.balance || 0)}</span>
                    </td>
                    <td className="table-cell">
                      <span className={`badge ${(c.balance || 0) > 0 ? 'badge-red' : 'badge-green'}`}>
                        {(c.balance || 0) > 0 ? 'Due' : 'Clear'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filtered.length === 0 && !loading && <div className="text-center py-12 text-gray-400"><DollarSign className="w-10 h-10 mx-auto mb-2 opacity-30" /><p>No party data</p></div>}
          </div>
        )}
      </div>
    </div>
  );
}
