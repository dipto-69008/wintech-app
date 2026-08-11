'use client';
import { useState, useEffect, useCallback } from 'react';
import { useBranchStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import { CreditCard, Plus, Edit2, Trash2, Search, CheckCircle2, Clock, XCircle, Banknote, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Textarea, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

interface Expense {
  _id: string; employee: string; date: string; category: string;
  description: string; amount: number; status: 'pending' | 'approved' | 'rejected' | 'paid'; approvedBy?: string;
}

const statusBadge: Record<string, string> = {
  pending: 'badge-yellow', approved: 'badge-blue', rejected: 'badge-red', paid: 'badge-green',
};

const CATEGORIES = ['Travel', 'Meals', 'Office Supplies', 'Training', 'Marketing', 'Utilities', 'Medical', 'Other'];
const emptyForm = () => ({ employee: '', date: new Date().toISOString().split('T')[0], category: 'Travel', description: '', amount: '', status: 'pending' as Expense['status'], approvedBy: '' });

export default function ExpensesPage() {
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Expense | null>(null);
  const [form, setForm] = useState(emptyForm());

  const { selectedBranchLegacyId } = useBranchStore();

  const fetchExpenses = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (search) params.set('search', search);
      if (filterStatus !== 'all') params.set('status', filterStatus);
      if (selectedBranchLegacyId) params.set('branchId', String(selectedBranchLegacyId));
      const r = await fetch(`/api/expenses?${params}`);
      const d = await r.json();
      setExpenses(d.data || []);
    } catch { toast.error('Could not load expenses'); }
    finally { setLoading(false); }
  }, [search, filterStatus, selectedBranchLegacyId]);

  useEffect(() => { fetchExpenses(); }, [fetchExpenses]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (e: Expense) => {
    setEditing(e);
    setForm({ employee: e.employee, date: e.date, category: e.category, description: e.description, amount: String(e.amount), status: e.status, approvedBy: e.approvedBy || '' });
    setShowModal(true);
  };

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const handleSave = async () => {
    if (!form.employee || !form.description) return toast.error('Employee and description required');
    setSaving(true);
    try {
      const payload = { ...form, amount: Number(form.amount) || 0 };
      const url = editing ? `/api/expenses/${editing._id}` : '/api/expenses';
      const method = editing ? 'PATCH' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) throw new Error('Save failed');
      toast.success(editing ? 'Expense updated' : 'Expense submitted');
      setShowModal(false);
      fetchExpenses();
    } catch { toast.error('Save failed'); }
    finally { setSaving(false); }
  };

  const quickStatus = async (id: string, status: Expense['status']) => {
    try {
      await fetch(`/api/expenses/${id}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status }) });
      toast.success(`Claim ${status}`);
      fetchExpenses();
    } catch { toast.error('Failed to update'); }
  };

  const handleDelete = async (id: string) => {
    try {
      await fetch(`/api/expenses/${id}`, { method: 'DELETE' });
      toast.success('Deleted');
      fetchExpenses();
    } catch { toast.error('Delete failed'); }
  };

  const totalPending = expenses.filter(e => e.status === 'pending').reduce((s, e) => s + e.amount, 0);
  const totalApproved = expenses.filter(e => ['approved', 'paid'].includes(e.status)).reduce((s, e) => s + e.amount, 0);
  const totalPaid = expenses.filter(e => e.status === 'paid').reduce((s, e) => s + e.amount, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Expense Claims" subtitle="Employee expense submissions and approvals"
        actions={<Button size="sm" onClick={openAdd}><Plus size={15} />New Claim</Button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Claims', value: expenses.length, icon: CreditCard, color: 'bg-blue-50 text-blue-600' },
          { label: 'Pending', value: `৳${totalPending.toLocaleString()}`, icon: Clock, color: 'bg-amber-50 text-amber-600' },
          { label: 'Approved', value: `৳${totalApproved.toLocaleString()}`, icon: CheckCircle2, color: 'bg-emerald-50 text-emerald-600' },
          { label: 'Paid Out', value: `৳${totalPaid.toLocaleString()}`, icon: Banknote, color: 'bg-purple-50 text-purple-600' },
        ].map(k => (
          <div key={k.label} className="stat-card flex items-center gap-4">
            <div className={`icon-box ${k.color}`}><k.icon size={20} /></div>
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">{k.label}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white mt-0.5">{k.value}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search claims..." className="form-input pl-9 w-60 py-2" />
            </div>
            <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)} className="form-input w-40 py-2">
              <option value="all">All Status</option>
              <option value="pending">Pending</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
              <option value="paid">Paid</option>
            </select>
          </div>
          <p className="text-sm text-gray-400 font-medium">{expenses.length} claims</p>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-12 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead>
                <tr>{['Employee', 'Date', 'Category', 'Description', 'Amount', 'Status', 'Approved By', ''].map(h => (<th key={h} className="table-header">{h}</th>))}</tr>
              </thead>
              <tbody>
                {expenses.map(e => (
                  <tr key={e._id} className="table-row">
                    <td className="table-cell font-semibold text-gray-900 dark:text-white">{e.employee}</td>
                    <td className="table-cell text-gray-500">{e.date}</td>
                    <td className="table-cell"><span className="badge badge-blue">{e.category}</span></td>
                    <td className="table-cell max-w-[200px]"><p className="truncate text-gray-600 dark:text-gray-300">{e.description}</p></td>
                    <td className="table-cell font-bold text-gray-900 dark:text-white">৳{e.amount.toLocaleString()}</td>
                    <td className="table-cell"><span className={`badge ${statusBadge[e.status] || 'badge-gray'}`}>{e.status}</span></td>
                    <td className="table-cell text-gray-400 text-xs">{e.approvedBy || '—'}</td>
                    <td className="table-cell">
                      <div className="flex items-center gap-1">
                        {e.status === 'pending' && (
                          <>
                            <button onClick={() => quickStatus(e._id, 'approved')} title="Approve" className="p-1.5 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 text-emerald-500 rounded-lg"><CheckCircle2 size={14} /></button>
                            <button onClick={() => quickStatus(e._id, 'rejected')} title="Reject" className="p-1.5 hover:bg-red-50 dark:hover:bg-red-900/20 text-red-400 rounded-lg"><XCircle size={14} /></button>
                          </>
                        )}
                        <button onClick={() => openEdit(e)} className="p-1.5 hover:bg-blue-50 dark:hover:bg-blue-900/20 text-blue-500 rounded-lg"><Edit2 size={14} /></button>
                        <button onClick={() => handleDelete(e._id)} className="p-1.5 hover:bg-red-50 dark:hover:bg-red-900/20 text-red-400 rounded-lg"><Trash2 size={14} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
                {expenses.length === 0 && (
                  <tr><td colSpan={8} className="text-center py-12 text-gray-400"><CreditCard className="w-8 h-8 mx-auto mb-2 text-gray-300" /><p>No expense claims found</p></td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Claim' : 'New Expense Claim'}
        size="md"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editing ? 'Update' : 'Submit Claim'}</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="Employee Name" required>
            <Input value={form.employee} onChange={set('employee')} placeholder="Employee name" />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Date">
              <Input type="date" value={form.date} onChange={set('date')} />
            </Field>
            <Field label="Category">
              <Select value={form.category} onChange={set('category')}>
                {CATEGORIES.map(c => <option key={c}>{c}</option>)}
              </Select>
            </Field>
          </div>
          <Field label="Description" required>
            <Textarea value={form.description} onChange={set('description')} placeholder="Describe the expense..." />
          </Field>
          <Field label="Amount (৳)">
            <Input type="number" value={form.amount} onChange={set('amount')} placeholder="0" min="0" />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Status">
              <Select value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as Expense['status'] }))}>
                <option value="pending">Pending</option>
                <option value="approved">Approved</option>
                <option value="rejected">Rejected</option>
                <option value="paid">Paid</option>
              </Select>
            </Field>
            <Field label="Approved By">
              <Input value={form.approvedBy} onChange={set('approvedBy')} placeholder="Manager name" />
            </Field>
          </div>
        </div>
      </Modal>
    </div>
  );
}
