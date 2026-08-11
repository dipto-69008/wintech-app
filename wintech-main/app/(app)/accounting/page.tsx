'use client';
import { useState, useEffect, useCallback } from 'react';
import { useBranchStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import { Plus, TrendingUp, TrendingDown, DollarSign, Search, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

interface Transaction {
  _id: string; date: string; description: string; type: 'income' | 'expense';
  category: string; amount: number; reference?: string; method?: string;
}

const METHODS = ['Bank Transfer', 'Cash', 'Cheque', 'Mobile Banking', 'Card'];
const INCOME_CATS = ['Sales Revenue', 'Service Income', 'Commission', 'Interest', 'Other Income'];
const EXPENSE_CATS = ['Salary', 'Rent', 'Utilities', 'Marketing', 'Travel', 'Supplies', 'Maintenance', 'Other'];
const emptyForm = () => ({ description: '', amount: '', type: 'income' as 'income' | 'expense', category: 'Sales Revenue', date: new Date().toISOString().split('T')[0], reference: '', method: 'Bank Transfer' });

export default function AccountingPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<'all' | 'income' | 'expense'>('all');
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState(emptyForm());
  const [totals, setTotals] = useState({ income: 0, expense: 0 });

  const { selectedBranchLegacyId } = useBranchStore();

  const fetchTransactions = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (search) params.set('search', search);
      if (typeFilter !== 'all') params.set('type', typeFilter);
      if (selectedBranchLegacyId) params.set('branchId', String(selectedBranchLegacyId));
      const r = await fetch(`/api/transactions?${params}`);
      const d = await r.json();
      setTransactions(d.data || []);
      setTotals({ income: d.totalIncome || 0, expense: d.totalExpense || 0 });
    } catch { toast.error('Could not load transactions'); }
    finally { setLoading(false); }
  }, [search, typeFilter, selectedBranchLegacyId]);

  useEffect(() => { fetchTransactions(); }, [fetchTransactions]);

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const handleSave = async () => {
    if (!form.description || !form.amount) return toast.error('Fill required fields');
    setSaving(true);
    try {
      const payload = { ...form, amount: Number(form.amount) };
      const res = await fetch('/api/transactions', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) throw new Error('Save failed');
      toast.success('Transaction recorded');
      setShowModal(false);
      fetchTransactions();
    } catch { toast.error('Save failed'); }
    finally { setSaving(false); }
  };

  const netBalance = totals.income - totals.expense;

  const monthlyMap = transactions.reduce((acc, t) => {
    const month = t.date?.slice(0, 7) || '';
    if (!acc[month]) acc[month] = { month, income: 0, expense: 0 };
    if (t.type === 'income') acc[month].income += t.amount;
    else acc[month].expense += t.amount;
    return acc;
  }, {} as Record<string, { month: string; income: number; expense: number }>);
  const chartData = Object.values(monthlyMap).sort((a, b) => a.month.localeCompare(b.month)).slice(-6).map(m => ({ ...m, month: m.month.slice(5) }));

  const cats = form.type === 'income' ? INCOME_CATS : EXPENSE_CATS;

  return (
    <div className="page-wrapper">
      <Topbar title="Accounting" subtitle="Financial transactions and records"
        actions={<Button size="sm" onClick={() => { setForm(emptyForm()); setShowModal(true); }}><Plus size={15} />New Transaction</Button>} />

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <div className="card bg-gradient-to-br from-blue-500 to-blue-600 text-white relative overflow-hidden">
          <div className="absolute right-4 top-4 opacity-20"><TrendingUp size={48} /></div>
          <p className="text-sm text-blue-100">Total Income</p>
          <p className="text-3xl font-bold mt-1">৳{totals.income.toLocaleString()}</p>
          <p className="text-xs text-blue-200 mt-2">All recorded income</p>
        </div>
        <div className="card bg-gradient-to-br from-red-500 to-red-600 text-white relative overflow-hidden">
          <div className="absolute right-4 top-4 opacity-20"><TrendingDown size={48} /></div>
          <p className="text-sm text-red-100">Total Expenses</p>
          <p className="text-3xl font-bold mt-1">৳{totals.expense.toLocaleString()}</p>
          <p className="text-xs text-red-200 mt-2">All recorded expenses</p>
        </div>
        <div className={`card bg-gradient-to-br ${netBalance >= 0 ? 'from-emerald-500 to-emerald-600' : 'from-orange-500 to-orange-600'} text-white relative overflow-hidden`}>
          <div className="absolute right-4 top-4 opacity-20"><DollarSign size={48} /></div>
          <p className="text-sm text-white/80">Net Balance</p>
          <p className="text-3xl font-bold mt-1">৳{netBalance.toLocaleString()}</p>
          <p className="text-xs text-white/70 mt-2">{netBalance >= 0 ? 'Profit' : 'Loss'}</p>
        </div>
      </div>

      {chartData.length > 0 && (
        <div className="card">
          <h3 className="font-bold text-gray-900 dark:text-gray-100 mb-4">Income vs Expenses (Monthly)</h3>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartData} barGap={4}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `৳${(v / 1000).toFixed(0)}K`} />
              <Tooltip formatter={(v: unknown) => `৳${Number(v).toLocaleString()}`} />
              <Bar dataKey="income" fill="#10b981" radius={[4, 4, 0, 0]} name="Income" />
              <Bar dataKey="expense" fill="#ef4444" radius={[4, 4, 0, 0]} name="Expense" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      <div className="card">
        <div className="section-header">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search transactions..." className="form-input pl-9 w-60" />
            </div>
            <select value={typeFilter} onChange={e => setTypeFilter(e.target.value as 'all' | 'income' | 'expense')} className="form-input w-36">
              <option value="all">All Types</option>
              <option value="income">Income</option>
              <option value="expense">Expense</option>
            </select>
          </div>
          <p className="text-sm text-gray-400">{transactions.length} records</p>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-12 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                  {['Date', 'Description', 'Category', 'Type', 'Method', 'Reference', 'Amount'].map(h => (
                    <th key={h} className={`py-3 pr-4 font-medium ${h === 'Amount' ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {transactions.map(t => (
                  <tr key={t._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-3 pr-4 text-gray-500 text-xs">{t.date}</td>
                    <td className="py-3 pr-4 font-medium text-gray-900 dark:text-white max-w-[200px] truncate">{t.description}</td>
                    <td className="py-3 pr-4"><span className="badge badge-blue">{t.category}</span></td>
                    <td className="py-3 pr-4">
                      <span className={`badge ${t.type === 'income' ? 'badge-green' : 'badge-red'} flex items-center gap-1 w-fit`}>
                        {t.type === 'income' ? <TrendingUp size={10} /> : <TrendingDown size={10} />}{t.type}
                      </span>
                    </td>
                    <td className="py-3 pr-4 text-gray-500 text-xs">{t.method || '—'}</td>
                    <td className="py-3 pr-4 text-gray-400 text-xs font-mono">{t.reference || '—'}</td>
                    <td className={`py-3 font-bold text-right ${t.type === 'income' ? 'text-emerald-600' : 'text-red-600'}`}>
                      {t.type === 'income' ? '+' : '-'}৳{t.amount.toLocaleString()}
                    </td>
                  </tr>
                ))}
                {transactions.length === 0 && (
                  <tr><td colSpan={7} className="text-center py-12 text-gray-400"><DollarSign className="w-8 h-8 mx-auto mb-2 opacity-30" /><p>No transactions found</p></td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title="New Transaction"
        size="md"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>Record Transaction</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="Description" required>
            <Input value={form.description} onChange={set('description')} placeholder="Enter description" />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Type">
              <Select value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value as 'income' | 'expense', category: e.target.value === 'income' ? INCOME_CATS[0] : EXPENSE_CATS[0] }))}>
                <option value="income">Income</option>
                <option value="expense">Expense</option>
              </Select>
            </Field>
            <Field label="Category">
              <Select value={form.category} onChange={set('category')}>
                {cats.map(c => <option key={c}>{c}</option>)}
              </Select>
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Amount (৳)" required>
              <Input type="number" value={form.amount} onChange={set('amount')} placeholder="0" />
            </Field>
            <Field label="Date">
              <Input type="date" value={form.date} onChange={set('date')} />
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Payment Method">
              <Select value={form.method} onChange={set('method')}>
                {METHODS.map(m => <option key={m}>{m}</option>)}
              </Select>
            </Field>
            <Field label="Reference">
              <Input value={form.reference} onChange={set('reference')} placeholder="Ref no." />
            </Field>
          </div>
        </div>
      </Modal>
    </div>
  );
}
