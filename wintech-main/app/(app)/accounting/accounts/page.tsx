'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Wallet, TrendingUp, TrendingDown, Loader2, Edit2, Trash2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Account {
  _id: string; name: string; type: 'asset' | 'liability' | 'income' | 'expense' | 'equity';
  balance?: number; description?: string; code: string;
}

const TYPE_COLORS: Record<string, string> = {
  asset: 'badge-blue', liability: 'badge-red', income: 'badge-green', expense: 'badge-yellow', equity: 'badge-purple'
};

export default function AccountsPage() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [financials, setFinancials] = useState({ totalIncome: 0, totalExpense: 0 });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [typeFilter, setTypeFilter] = useState<string>('all');
  const [form, setForm] = useState({ name: '', type: 'asset' as Account['type'], balance: '', description: '', code: '' });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [ar, tr] = await Promise.all([fetch('/api/accounts'), fetch('/api/transactions')]);
      const [aj, tj] = await Promise.all([ar.json(), tr.json()]);
      setAccounts(aj.data || []);
      setFinancials({ totalIncome: tj.totalIncome || 0, totalExpense: tj.totalExpense || 0 });
    } catch { toast.error('Failed to load accounts'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const filtered = accounts.filter(a => typeFilter === 'all' || a.type === typeFilter);
  const totalAssets = accounts.filter(a => a.type === 'asset').reduce((s, a) => s + (a.balance || 0), 0);
  const totalLiab = accounts.filter(a => a.type === 'liability').reduce((s, a) => s + (a.balance || 0), 0);
  const netWorth = totalAssets - totalLiab;

  const openEdit = (a: Account) => {
    setEditingId(a._id);
    setForm({ name: a.name, type: a.type, balance: String(a.balance || 0), description: a.description || '', code: a.code });
    setShowModal(true);
  };

  const openAdd = () => {
    setEditingId(null);
    setForm({ name: '', type: 'asset', balance: '', description: '', code: '' });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name || !form.code) return toast.error('Name and code required');
    setSaving(true);
    try {
      const payload = { ...form, balance: Number(form.balance) || 0 };
      if (editingId) {
        const res = await fetch(`/api/accounts/${editingId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error();
        toast.success('Account updated');
      } else {
        const res = await fetch('/api/accounts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error();
        toast.success('Account added');
      }
      setShowModal(false);
      fetchData();
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/accounts/${id}`, { method: 'DELETE' });
      setAccounts(prev => prev.filter(a => a._id !== id));
      toast.success('Removed');
    } catch { toast.error('Failed to delete'); }
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Chart of Accounts" subtitle="Manage company account structure"
        actions={<button onClick={openAdd} className="btn-primary"><Plus size={15} />Add Account</button>} />

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[
          { label: 'Total Assets', value: totalAssets, icon: TrendingUp, color: 'bg-blue-50 text-blue-600' },
          { label: 'Total Liabilities', value: totalLiab, icon: TrendingDown, color: 'bg-red-50 text-red-600' },
          { label: 'Net Worth', value: netWorth, icon: Wallet, color: netWorth >= 0 ? 'bg-emerald-50 text-emerald-600' : 'bg-orange-50 text-orange-600' },
        ].map(k => (
          <div key={k.label} className="stat-card flex items-center gap-4">
            <div className={`icon-box ${k.color}`}><k.icon size={20} /></div>
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">{k.label}</p>
              <p className="text-2xl font-bold text-gray-900 mt-0.5">{loading ? <Loader2 className="animate-spin inline" size={18} /> : `৳${k.value.toLocaleString()}`}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="flex gap-2 flex-wrap">
            {(['all', 'asset', 'liability', 'income', 'expense', 'equity'] as const).map(t => (
              <button key={t} onClick={() => setTypeFilter(t)} className={`px-3 py-1.5 rounded-xl text-sm font-medium capitalize transition-all ${typeFilter === t ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>{t}</button>
            ))}
          </div>
        </div>
        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead>
                <tr>{['Code', 'Account Name', 'Type', 'Description', 'Balance', ''].map(h => <th key={h} className="table-header">{h}</th>)}</tr>
              </thead>
              <tbody>
                {filtered.length === 0 && <tr><td colSpan={6} className="text-center py-10 text-gray-400">No accounts found. Add your first account.</td></tr>}
                {filtered.map(a => (
                  <tr key={a._id} className="table-row">
                    <td className="table-cell font-mono text-xs text-gray-500">{a.code}</td>
                    <td className="table-cell font-semibold text-gray-900">{a.name}</td>
                    <td className="table-cell"><span className={`badge ${TYPE_COLORS[a.type] || 'badge-gray'}`}>{a.type}</span></td>
                    <td className="table-cell text-gray-500 text-xs">{a.description}</td>
                    <td className="table-cell font-bold text-right">৳{(a.balance || 0).toLocaleString()}</td>
                    <td className="table-cell">
                      <div className="flex items-center gap-1">
                        <button onClick={() => openEdit(a)} className="p-1.5 hover:bg-blue-50 text-blue-400 rounded-lg"><Edit2 size={13} /></button>
                        <button onClick={() => del(a._id)} className="p-1.5 hover:bg-red-50 text-red-400 rounded-lg"><Trash2 size={13} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={`${editingId ? 'Edit' : 'Add'} Account`}
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : (editingId ? 'Update' : 'Add Account')}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Account Code *</label><input value={form.code} onChange={e => setForm({ ...form, code: e.target.value })} className="form-input" placeholder="e.g. 1003" /></div>
          <div><label className="form-label">Account Name *</label><input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="form-input" /></div>
          <div><label className="form-label">Type</label>
            <select value={form.type} onChange={e => setForm({ ...form, type: e.target.value as Account['type'] })} className="form-input">
              <option value="asset">Asset</option><option value="liability">Liability</option>
              <option value="income">Income</option><option value="expense">Expense</option>
              <option value="equity">Equity</option>
            </select>
          </div>
          <div><label className="form-label">Opening Balance (৳)</label><input type="number" value={form.balance} onChange={e => setForm({ ...form, balance: e.target.value })} className="form-input" /></div>
          <div><label className="form-label">Description</label><input value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} className="form-input" /></div>
        </div>
      </Modal>
    </div>
  );
}
