'use client';
import { useState, useEffect, useCallback } from 'react';
import { useBranchStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import { Target, Plus, Trash2, Edit2, CheckCircle2, Clock, AlertCircle, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

interface TargetItem {
  _id: string; title: string; module: string; assignedTo?: string;
  targetValue: number; currentValue: number; unit: string;
  deadline?: string; status: 'on-track' | 'at-risk' | 'completed' | 'overdue';
}

const MODULES = ['Sales', 'Purchases', 'Inventory', 'HR', 'CRM', 'Accounting', 'Assets'];
const statusConfig = {
  'on-track': { label: 'On Track', icon: CheckCircle2, className: 'badge-green' },
  'at-risk': { label: 'At Risk', icon: AlertCircle, className: 'badge-yellow' },
  'completed': { label: 'Completed', icon: CheckCircle2, className: 'badge-blue' },
  'overdue': { label: 'Overdue', icon: AlertCircle, className: 'badge-red' },
};

const emptyForm = () => ({ title: '', module: 'Sales', assignedTo: '', targetValue: '', currentValue: '', unit: 'BDT', deadline: '', status: 'on-track' as TargetItem['status'] });

export default function TargetsPage() {
  const [targets, setTargets] = useState<TargetItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editTarget, setEditTarget] = useState<TargetItem | null>(null);
  const [form, setForm] = useState(emptyForm());

  const { selectedBranchLegacyId } = useBranchStore();

  const fetchTargets = useCallback(async () => {
    setLoading(true);
    try {
      const url = selectedBranchLegacyId ? `/api/targets?branchId=${selectedBranchLegacyId}` : '/api/targets';
      const r = await fetch(url);
      const d = await r.json();
      setTargets(d.data || []);
    } catch { toast.error('Could not load targets'); }
    finally { setLoading(false); }
  }, [selectedBranchLegacyId]);

  useEffect(() => { fetchTargets(); }, [fetchTargets]);

  const openAdd = () => { setEditTarget(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (t: TargetItem) => {
    setEditTarget(t);
    setForm({ title: t.title, module: t.module, assignedTo: t.assignedTo || '', targetValue: String(t.targetValue), currentValue: String(t.currentValue), unit: t.unit, deadline: t.deadline || '', status: t.status });
    setShowModal(true);
  };

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const handleSave = async () => {
    if (!form.title) return toast.error('Title required');
    setSaving(true);
    try {
      const payload = { ...form, targetValue: Number(form.targetValue) || 0, currentValue: Number(form.currentValue) || 0 };
      const url = editTarget ? `/api/targets/${editTarget._id}` : '/api/targets';
      const method = editTarget ? 'PATCH' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) throw new Error('Save failed');
      toast.success(editTarget ? 'Target updated' : 'Target added');
      setShowModal(false);
      fetchTargets();
    } catch { toast.error('Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this target?')) return;
    try {
      await fetch(`/api/targets/${id}`, { method: 'DELETE' });
      toast.success('Deleted');
      fetchTargets();
    } catch { toast.error('Delete failed'); }
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Targets & Goals" subtitle="Track business targets and KPIs"
        actions={<Button size="sm" onClick={openAdd}><Plus size={15} />New Target</Button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {Object.entries(statusConfig).map(([key, cfg]) => (
          <div key={key} className="card">
            <p className={`text-2xl font-bold text-${key === 'on-track' ? 'emerald' : key === 'at-risk' ? 'amber' : key === 'completed' ? 'blue' : 'red'}-600`}>
              {targets.filter(t => t.status === key).length}
            </p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{cfg.label}</p>
          </div>
        ))}
      </div>

      {loading ? (
        <div className="card flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
      ) : (
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
          {targets.map(t => {
            const pct = t.targetValue > 0 ? Math.min((t.currentValue / t.targetValue) * 100, 100) : 0;
            const cfg = statusConfig[t.status];
            const Icon = cfg.icon;
            return (
              <div key={t._id} className="card group hover:shadow-md transition-all">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="badge badge-blue text-xs">{t.module}</span>
                      <span className={`badge ${cfg.className} flex items-center gap-1 text-xs`}><Icon size={10} />{cfg.label}</span>
                    </div>
                    <h3 className="font-bold text-gray-900 dark:text-white">{t.title}</h3>
                    {t.assignedTo && <p className="text-xs text-gray-400 mt-0.5">Assigned to: {t.assignedTo}</p>}
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => openEdit(t)} className="p-1.5 text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg"><Edit2 size={13} /></button>
                    <button onClick={() => handleDelete(t._id)} className="p-1.5 text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg"><Trash2 size={13} /></button>
                  </div>
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500 dark:text-gray-400">Progress</span>
                    <span className="font-bold text-gray-900 dark:text-white">{t.currentValue.toLocaleString()} / {t.targetValue.toLocaleString()} {t.unit}</span>
                  </div>
                  <div className="bg-gray-100 dark:bg-gray-700 rounded-full h-2">
                    <div className={`h-2 rounded-full ${pct >= 100 ? 'bg-emerald-500' : pct >= 70 ? 'bg-blue-500' : pct >= 40 ? 'bg-amber-500' : 'bg-red-400'}`} style={{ width: `${pct}%` }} />
                  </div>
                  <div className="flex justify-between text-xs text-gray-400">
                    <span>{pct.toFixed(0)}% achieved</span>
                    {t.deadline && <span className="flex items-center gap-1"><Clock size={10} />{t.deadline}</span>}
                  </div>
                </div>
              </div>
            );
          })}
          {targets.length === 0 && (
            <div className="col-span-2 text-center py-16 text-gray-400">
              <Target size={40} className="mx-auto mb-3 opacity-30" />
              <p>No targets set. Add your first business goal!</p>
            </div>
          )}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editTarget ? 'Edit Target' : 'New Target'}
        size="md"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editTarget ? 'Update' : 'Add Target'}</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="Title" required>
            <Input value={form.title} onChange={set('title')} placeholder="Target title" />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Module">
              <Select value={form.module} onChange={set('module')}>
                {MODULES.map(m => <option key={m}>{m}</option>)}
              </Select>
            </Field>
            <Field label="Unit">
              <Input value={form.unit} onChange={set('unit')} placeholder="BDT, units, %" />
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Target Value">
              <Input type="number" value={form.targetValue} onChange={set('targetValue')} placeholder="0" min="0" />
            </Field>
            <Field label="Current Value">
              <Input type="number" value={form.currentValue} onChange={set('currentValue')} placeholder="0" min="0" />
            </Field>
          </div>
          <Field label="Assigned To">
            <Input value={form.assignedTo} onChange={set('assignedTo')} placeholder="Team or person" />
          </Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Deadline">
              <Input type="date" value={form.deadline} onChange={set('deadline')} />
            </Field>
            <Field label="Status">
              <Select value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as TargetItem['status'] }))}>
                <option value="on-track">On Track</option>
                <option value="at-risk">At Risk</option>
                <option value="completed">Completed</option>
                <option value="overdue">Overdue</option>
              </Select>
            </Field>
          </div>
        </div>
      </Modal>
    </div>
  );
}
