'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { CreditCard, AlertTriangle, Phone, Mail, Loader2, Search } from 'lucide-react';

interface Party { _id: string; name: string; email?: string; phone?: string; balance: number; totalOrders?: number; totalSpent?: number; }

export default function PartyDuePage() {
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

  const dueParties = parties
    .filter(c => (c.balance || 0) > 0)
    .filter(c => !search || c.name.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => b.balance - a.balance);

  const totalDue = dueParties.reduce((a, c) => a + c.balance, 0);
  const fmt = (n: number) => `৳${n.toLocaleString()}`;

  return (
    <div className="page-wrapper">
      <Topbar title="Party Due List" subtitle="Parties with outstanding balance" />

      <div className="grid grid-cols-3 gap-4">
        <div className="card"><p className="text-2xl font-bold text-red-600">{fmt(totalDue)}</p><p className="text-sm text-gray-500 mt-1">Total Outstanding</p></div>
        <div className="card"><p className="text-2xl font-bold text-amber-600">{dueParties.length}</p><p className="text-sm text-gray-500 mt-1">Parties with Dues</p></div>
        <div className="card"><p className="text-2xl font-bold text-blue-600">{fmt(dueParties.length > 0 ? Math.round(totalDue / dueParties.length) : 0)}</p><p className="text-sm text-gray-500 mt-1">Average Due</p></div>
      </div>

      <div className="card">
        <div className="section-header mb-4">
          <h3 className="font-bold text-gray-900 dark:text-white">Outstanding Party Balances</h3>
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
              <thead><tr>{['Party', 'Contact', 'Outstanding Balance', 'Risk Level'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-50">
                {dueParties.map(c => {
                  const risk = c.balance > 100000 ? 'High' : c.balance > 20000 ? 'Medium' : 'Low';
                  const riskColor = risk === 'High' ? 'badge-red' : risk === 'Medium' ? 'badge-yellow' : 'badge-green';
                  return (
                    <tr key={c._id} className="table-row">
                      <td className="table-cell">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 bg-gradient-to-br from-red-400 to-orange-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{c.name.charAt(0)}</div>
                          <p className="font-semibold text-gray-900 dark:text-white">{c.name}</p>
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="flex flex-col gap-0.5 text-xs text-gray-500">
                          {c.email && <span className="flex items-center gap-1"><Mail size={10} />{c.email}</span>}
                          {c.phone && <span className="flex items-center gap-1"><Phone size={10} />{c.phone}</span>}
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center gap-2">
                          <AlertTriangle size={14} className="text-red-500 flex-shrink-0" />
                          <span className="font-bold text-red-600 text-base">{fmt(c.balance)}</span>
                        </div>
                      </td>
                      <td className="table-cell"><span className={`badge ${riskColor}`}>{risk}</span></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {dueParties.length === 0 && !loading && (
              <div className="text-center py-12 text-gray-400">
                <CreditCard className="w-10 h-10 mx-auto mb-2 opacity-30" />
                <p>No outstanding balances</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
