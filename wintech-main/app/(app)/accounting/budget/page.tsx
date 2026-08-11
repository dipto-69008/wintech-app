'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { Plus, Loader2, Edit2, Trash2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Budget { _id: string; dept: string; budget: number; spent: number; year: number; }

const DEPTS = ['Engineering', 'Sales', 'HR', 'Accounting', 'Operations', 'Marketing', 'Fish Processing', 'Depot', 'Distribution'];

export default function BudgetPage() {
  const [budgetData, setBudgetData] = useState<Budget[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [year, setYear] = useState(new Date().getFullYear());
  const [form, setForm] = useState({ dept: DEPTS[0], budget: '', spent: '' });

  const fetchData = useCallback(async (y: number) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/budget?year=${y}`);
      const json = await res.json();
      setBudgetData(json.data || []);
    } catch { toast.error('Failed to load budget'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(year); }, [fetchData, year]);

  const totalBudget = budgetData.reduce((a, b) => a + b.budget, 0);
  const totalSpent = budgetData.reduce((a, b) => a + b.spent, 0);
  const remaining = totalBudget - totalSpent;
  const utilization = totalBudget > 0 ? ((totalSpent / totalBudget) * 100).toFixed(1) : '0.0';

  const openAdd = () => { setEditingId(null); setForm({ dept: DEPTS[0], budget: '', spent: '' }); setShowModal(true); };
  const openEdit = (b: Budget) => { setEditingId(b._id); setForm({ dept: b.dept, budget: String(b.budget), spent: String(b.spent) }); setShowModal(true); };

  const handleSave = async () => {
    if (!form.dept || !form.budget) return toast.error('Department and budget required');
    setSaving(true);
    try {
      const payload = { dept: form.dept, budget: Number(form.budget), spent: Number(form.spent) || 0, year };
      if (editingId) {
        const res = await fetch(`/api/budget/${editingId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error();
        toast.success('Budget updated');
      } else {
        const res = await fetch('/api/budget', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error();
        toast.success('Budget added');
      }
      setShowModal(false);
      fetchData(year);
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/budget/${id}`, { method: 'DELETE' });
      setBudgetData(prev => prev.filter(b => b._id !== id));
      toast.success('Deleted');
    } catch { toast.error('Failed to delete'); }
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Budget" subtitle="Track departmental budget and spending"
        actions={
          <div className="flex items-center gap-2">
            <select value={year} onChange={e => setYear(Number(e.target.value))} className="form-input py-2 text-sm">
              {[2024, 2025, 2026, 2027].map(y => <option key={y} value={y}>{y}</option>)}
            </select>
            <button onClick={openAdd} className="btn-primary"><Plus size={15} /> Add Budget</button>
          </div>
        }
      />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Budget', value: `৳${(totalBudget/1000).toFixed(0)}K`, color: 'blue' },
          { label: 'Total Spent', value: `৳${(totalSpent/1000).toFixed(0)}K`, color: 'red' },
          { label: 'Remaining', value: `৳${(remaining/1000).toFixed(0)}K`, color: 'emerald' },
          { label: 'Utilization', value: `${utilization}%`, color: 'purple' },
        ].map(s => (
          <div key={s.label} className="card text-center">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{loading ? '—' : s.value}</p>
            <p className="text-xs text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 className="animate-spin text-gray-400" size={28} /></div>
      ) : budgetData.length === 0 ? (
        <div className="card text-center py-16 text-gray-400">
          <p className="mb-3">No budget data for {year}.</p>
          <button onClick={openAdd} className="btn-primary"><Plus size={14} /> Add Budget</button>
        </div>
      ) : (
        <>
          <div className="card">
            <h3 className="font-bold text-gray-900 mb-5">Budget vs Spending by Department</h3>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={budgetData} margin={{ left: -10 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f5f5f5" vertical={false} />
                <XAxis dataKey="dept" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <Tooltip formatter={v => `৳${Number(v).toLocaleString()}`} />
                <Bar dataKey="budget" fill="#dbeafe" name="Budget" radius={[4,4,0,0]} />
                <Bar dataKey="spent" fill="#3b82f6" name="Spent" radius={[4,4,0,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="card">
            <h3 className="font-bold text-gray-900 mb-4">Department Budget Breakdown</h3>
            <div className="space-y-4">
              {budgetData.map(d => {
                const pct = d.budget > 0 ? (d.spent / d.budget) * 100 : 0;
                const isOver = pct > 90;
                return (
                  <div key={d._id}>
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="text-sm font-semibold text-gray-800">{d.dept}</span>
                      <div className="flex items-center gap-3 text-xs">
                        <span className="text-gray-500">Spent: <strong className={isOver ? 'text-red-600' : 'text-gray-700'}>৳{d.spent.toLocaleString()}</strong></span>
                        <span className="text-gray-400">/ ৳{d.budget.toLocaleString()}</span>
                        <span className={`font-bold ${isOver ? 'text-red-600' : pct > 70 ? 'text-amber-600' : 'text-emerald-600'}`}>{pct.toFixed(0)}%</span>
                        <button onClick={() => openEdit(d)} className="p-1 text-blue-400 hover:bg-blue-50 rounded"><Edit2 size={11} /></button>
                        <button onClick={() => del(d._id)} className="p-1 text-red-400 hover:bg-red-50 rounded"><Trash2 size={11} /></button>
                      </div>
                    </div>
                    <div className="w-full bg-gray-100 rounded-full h-2.5">
                      <div className={`h-2.5 rounded-full transition-all ${isOver ? 'bg-red-500' : pct > 70 ? 'bg-amber-400' : 'bg-emerald-500'}`} style={{ width: `${Math.min(pct, 100)}%` }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={`${editingId ? 'Edit' : 'Add'} Budget`}
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Save'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Department</label><select value={form.dept} onChange={e => setForm({...form, dept: e.target.value})} className="form-input">{DEPTS.map(d => <option key={d}>{d}</option>)}</select></div>
          <div><label className="form-label">Budget (৳)</label><input type="number" value={form.budget} onChange={e => setForm({...form, budget: e.target.value})} className="form-input" placeholder="e.g. 150000" /></div>
          <div><label className="form-label">Amount Spent (৳)</label><input type="number" value={form.spent} onChange={e => setForm({...form, spent: e.target.value})} className="form-input" placeholder="e.g. 98000" /></div>
        </div>
      </Modal>
    </div>
  );
}
