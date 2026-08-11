'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';
import { Plus, Search, X, CheckCircle, AlertCircle, Clock, XCircle, CreditCard, Trash2 } from 'lucide-react';

interface Cheque {
  _id: string;
  chequeNo: string;
  bankName: string;
  bankBranch?: string;
  accountNo?: string;
  amount: number;
  chequeDate: string;
  issueDate: string;
  partyName: string;
  partyType: string;
  chequeType: string;
  status: string;
  reminderDate?: string;
  description?: string;
  createdAt: string;
}

const STATUS_TABS = [
  { key: 'all', label: 'All Cheques', icon: CreditCard, color: 'blue' },
  { key: 'pending', label: 'Pending', icon: Clock, color: 'amber' },
  { key: 'reminder', label: 'Reminder', icon: AlertCircle, color: 'orange' },
  { key: 'approved', label: 'Approved', icon: CheckCircle, color: 'emerald' },
  { key: 'dishonoured', label: 'Dishonoured', icon: XCircle, color: 'red' },
];

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  reminder: 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400',
  approved: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400',
  dishonoured: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
};

const emptyForm = () => ({
  chequeNo: '',
  bankName: '',
  bankBranch: '',
  accountNo: '',
  amount: 0,
  chequeDate: new Date().toISOString().split('T')[0],
  issueDate: new Date().toISOString().split('T')[0],
  partyName: '',
  partyType: 'party',
  chequeType: 'receive',
  status: 'pending',
  reminderDate: '',
  description: '',
});

export default function ChequesPage() {
  const [tab, setTab] = useState('all');
  const [view, setView] = useState<'list' | 'new'>('list');
  const [cheques, setCheques] = useState<Cheque[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState(emptyForm());

  const fetchCheques = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ search, limit: '200' });
      if (tab !== 'all') params.set('status', tab);
      const r = await fetch(`/api/cheques?${params}`);
      if (r.ok) { const d = await r.json(); setCheques(d.data || []); }
    } finally { setLoading(false); }
  }, [search, tab]);

  useEffect(() => { fetchCheques(); }, [fetchCheques]);

  const counts = cheques.reduce((acc, c) => {
    acc[c.status] = (acc[c.status] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const handleSave = async () => {
    if (!form.chequeNo) return toast.error('Cheque number is required');
    if (!form.bankName) return toast.error('Bank name is required');
    if (!form.partyName) return toast.error('Party name is required');
    if (!form.amount || form.amount <= 0) return toast.error('Valid amount is required');
    setSaving(true);
    try {
      const res = await fetch('/api/cheques', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) });
      if (!res.ok) throw new Error((await res.json()).error || 'Failed');
      toast.success('Cheque entry saved!');
      setView('list');
      setForm(emptyForm());
      fetchCheques();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Save failed');
    } finally { setSaving(false); }
  };

  const updateStatus = async (id: string, status: string) => {
    const res = await fetch(`/api/cheques/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status }) });
    if (res.ok) { toast.success(`Marked as ${status}`); fetchCheques(); }
    else toast.error('Update failed');
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this cheque?')) return;
    const res = await fetch(`/api/cheques/${id}`, { method: 'DELETE' });
    if (res.ok) { toast.success('Deleted'); fetchCheques(); }
    else toast.error('Delete failed');
  };

  const totalAmount = cheques.reduce((a, c) => a + c.amount, 0);

  return (
    <div className="page-wrapper">
      <Topbar
        title="Cheque Management"
        subtitle={view === 'list' ? `${cheques.length} cheques` : 'New cheque entry'}
        actions={
          view === 'list'
            ? <button className="btn-primary" onClick={() => setView('new')}><Plus size={15} /> New Cheque</button>
            : <button className="btn-secondary" onClick={() => setView('list')}><X size={15} /> Cancel</button>
        }
      />

      {view === 'new' ? (
        <div className="max-w-2xl">
          <div className="card space-y-4">
            <h3 className="font-semibold text-gray-700 dark:text-gray-200">Cheque Entry Form</h3>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Cheque No *</label>
                <input className="input" placeholder="e.g. 0012345" value={form.chequeNo} onChange={e => setForm(f => ({ ...f, chequeNo: e.target.value }))} />
              </div>
              <div>
                <label className="label">Amount (৳) *</label>
                <input type="number" min="0" className="input" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: parseFloat(e.target.value) || 0 }))} />
              </div>
              <div>
                <label className="label">Bank Name *</label>
                <input className="input" placeholder="e.g. Dutch Bangla Bank" value={form.bankName} onChange={e => setForm(f => ({ ...f, bankName: e.target.value }))} />
              </div>
              <div>
                <label className="label">Bank Branch</label>
                <input className="input" placeholder="Branch name" value={form.bankBranch} onChange={e => setForm(f => ({ ...f, bankBranch: e.target.value }))} />
              </div>
              <div>
                <label className="label">Account No</label>
                <input className="input" placeholder="Account number" value={form.accountNo} onChange={e => setForm(f => ({ ...f, accountNo: e.target.value }))} />
              </div>
              <div>
                <label className="label">Party Name *</label>
                <input className="input" placeholder="Party / Supplier name" value={form.partyName} onChange={e => setForm(f => ({ ...f, partyName: e.target.value }))} />
              </div>
              <div>
                <label className="label">Party Type</label>
                <select className="input" value={form.partyType} onChange={e => setForm(f => ({ ...f, partyType: e.target.value }))}>
                  <option value="party">Party</option>
                  <option value="supplier">Supplier</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div>
                <label className="label">Cheque Type</label>
                <select className="input" value={form.chequeType} onChange={e => setForm(f => ({ ...f, chequeType: e.target.value }))}>
                  <option value="receive">Receive (Incoming)</option>
                  <option value="issue">Issue (Outgoing)</option>
                </select>
              </div>
              <div>
                <label className="label">Cheque Date *</label>
                <input type="date" className="input" value={form.chequeDate} onChange={e => setForm(f => ({ ...f, chequeDate: e.target.value }))} />
              </div>
              <div>
                <label className="label">Issue Date</label>
                <input type="date" className="input" value={form.issueDate} onChange={e => setForm(f => ({ ...f, issueDate: e.target.value }))} />
              </div>
              <div>
                <label className="label">Status</label>
                <select className="input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value }))}>
                  <option value="pending">Pending</option>
                  <option value="reminder">Reminder</option>
                  <option value="approved">Approved</option>
                  <option value="dishonoured">Dishonoured</option>
                </select>
              </div>
              <div>
                <label className="label">Reminder Date</label>
                <input type="date" className="input" value={form.reminderDate} onChange={e => setForm(f => ({ ...f, reminderDate: e.target.value }))} />
              </div>
              <div className="col-span-2">
                <label className="label">Description</label>
                <textarea className="input" rows={2} placeholder="Optional notes..." value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
              </div>
            </div>
            <div className="flex gap-3 pt-2">
              <button onClick={handleSave} disabled={saving} className="btn-primary py-2.5 px-6">{saving ? 'Saving...' : 'Save Cheque'}</button>
              <button onClick={() => setView('list')} className="btn-secondary py-2.5 px-6">Cancel</button>
            </div>
          </div>
        </div>
      ) : (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
            {[
              { label: 'Total Amount', value: `৳${totalAmount.toLocaleString()}`, color: 'blue' },
              { label: 'Pending', value: counts.pending || 0, color: 'amber' },
              { label: 'Reminder', value: counts.reminder || 0, color: 'orange' },
              { label: 'Dishonoured', value: counts.dishonoured || 0, color: 'red' },
            ].map(s => (
              <div key={s.label} className="card py-3">
                <p className="text-xs text-gray-500 dark:text-gray-400">{s.label}</p>
                <p className={`text-xl font-bold mt-0.5 text-${s.color}-600 dark:text-${s.color}-400`}>{s.value}</p>
              </div>
            ))}
          </div>

          {/* Tabs */}
          <div className="flex gap-1 mb-4 bg-gray-100 dark:bg-gray-800 rounded-xl p-1 w-fit">
            {STATUS_TABS.map(t => (
              <button key={t.key} onClick={() => setTab(t.key)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all
                  ${tab === t.key ? 'bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 shadow-sm' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'}`}>
                <t.icon size={12} />
                {t.label}
                {t.key !== 'all' && counts[t.key] ? <span className="bg-gray-200 dark:bg-gray-600 rounded-full px-1.5 text-[10px]">{counts[t.key]}</span> : null}
              </button>
            ))}
          </div>

          <div className="card">
            <div className="flex gap-3 mb-4">
              <div className="relative flex-1 max-w-xs">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input className="input pl-8" placeholder="Search cheques..." value={search} onChange={e => setSearch(e.target.value)} />
              </div>
            </div>

            {loading ? (
              <div className="text-center py-12 text-gray-400">Loading...</div>
            ) : cheques.length === 0 ? (
              <div className="text-center py-16">
                <CreditCard size={36} className="mx-auto mb-3 text-gray-300" />
                <p className="text-gray-500 font-medium">No cheques found</p>
                <button className="btn-primary mt-4" onClick={() => setView('new')}><Plus size={14} /> Add Cheque</button>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-gray-200 dark:border-gray-700 text-gray-500 text-xs">
                      <th className="text-left py-3 pr-3">Cheque No</th>
                      <th className="text-left py-3 pr-3">Party</th>
                      <th className="text-left py-3 pr-3">Bank</th>
                      <th className="text-left py-3 pr-3">Type</th>
                      <th className="text-left py-3 pr-3">Cheque Date</th>
                      <th className="text-right py-3 pr-3">Amount</th>
                      <th className="text-center py-3 pr-3">Status</th>
                      <th className="text-center py-3">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {cheques.map(c => (
                      <tr key={c._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                        <td className="py-2.5 pr-3 font-mono text-xs text-blue-600 dark:text-blue-400 font-medium">{c.chequeNo}</td>
                        <td className="py-2.5 pr-3 font-medium">{c.partyName}<br /><span className="text-xs text-gray-400 capitalize">{c.partyType}</span></td>
                        <td className="py-2.5 pr-3 text-gray-500 text-xs">{c.bankName}{c.bankBranch ? `, ${c.bankBranch}` : ''}</td>
                        <td className="py-2.5 pr-3">
                          <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${c.chequeType === 'receive' ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' : 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400'}`}>
                            {c.chequeType === 'receive' ? 'Receive' : 'Issue'}
                          </span>
                        </td>
                        <td className="py-2.5 pr-3 text-gray-500 text-xs">{formatDate(c.chequeDate)}</td>
                        <td className="py-2.5 pr-3 text-right font-semibold">৳{Number(c.amount).toLocaleString()}</td>
                        <td className="py-2.5 pr-3 text-center">
                          <span className={`text-xs px-2 py-0.5 rounded-full font-medium capitalize ${STATUS_COLORS[c.status] || 'bg-gray-100 text-gray-600'}`}>{c.status}</span>
                        </td>
                        <td className="py-2.5 text-center">
                          <div className="flex items-center justify-center gap-1">
                            {c.status === 'pending' && (
                              <>
                                <button onClick={() => updateStatus(c._id, 'approved')} className="text-emerald-500 hover:text-emerald-700 p-1 rounded" title="Approve">
                                  <CheckCircle size={14} />
                                </button>
                                <button onClick={() => updateStatus(c._id, 'reminder')} className="text-orange-400 hover:text-orange-600 p-1 rounded" title="Set Reminder">
                                  <AlertCircle size={14} />
                                </button>
                                <button onClick={() => updateStatus(c._id, 'dishonoured')} className="text-red-400 hover:text-red-600 p-1 rounded" title="Mark Dishonoured">
                                  <XCircle size={14} />
                                </button>
                              </>
                            )}
                            {c.status === 'reminder' && (
                              <button onClick={() => updateStatus(c._id, 'approved')} className="text-emerald-500 hover:text-emerald-700 p-1 rounded" title="Approve">
                                <CheckCircle size={14} />
                              </button>
                            )}
                            <button onClick={() => handleDelete(c._id)} className="text-red-400 hover:text-red-600 p-1 rounded" title="Delete">
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
