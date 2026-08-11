'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Edit2, Trash2, Layers, Loader2, Users, ChevronDown, ChevronUp } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Department { _id: string; name: string; head?: string; description?: string; budget?: number; status?: string; }
interface Employee { _id: string; name: string; designation?: string; department?: string; contactNo?: string; status: string; }

const BG_COLORS = [
  'from-blue-400 to-blue-600', 'from-emerald-400 to-emerald-600', 'from-purple-400 to-purple-600',
  'from-amber-400 to-amber-600', 'from-red-400 to-red-600', 'from-teal-400 to-teal-600',
];

export default function DepartmentPage() {
  const [departments, setDepartments] = useState<Department[]>([]);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Department | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', head: '', description: '', budget: '' });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [dr, er] = await Promise.all([
        fetch('/api/departments').then(r => r.json()),
        fetch('/api/employees?limit=500').then(r => r.json()),
      ]);
      setDepartments(dr.data || []);
      setEmployees(er.data || []);
    } catch { toast.error('Could not load departments'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const openAdd = () => { setEditing(null); setForm({ name: '', head: '', description: '', budget: '' }); setShowModal(true); };
  const openEdit = (d: Department) => {
    setEditing(d);
    setForm({ name: d.name, head: d.head || '', description: d.description || '', budget: String(d.budget || '') });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name) return toast.error('Department name required');
    setSaving(true);
    try {
      const payload = { name: form.name, head: form.head, description: form.description, budget: Number(form.budget) || 0, status: 'a' };
      const url = editing ? `/api/departments/${editing._id}` : '/api/departments';
      const res = await fetch(url, { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) throw new Error('Save failed');
      toast.success(editing ? 'Updated' : 'Department added');
      setShowModal(false); fetchData();
    } catch { toast.error('Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Delete department "${name}"?`)) return;
    try {
      await fetch(`/api/departments/${id}`, { method: 'DELETE' });
      toast.success('Deleted'); fetchData();
    } catch { toast.error('Delete failed'); }
  };

  const empsByDept = (name: string) =>
    employees.filter(e => e.department?.toLowerCase() === name.toLowerCase() && e.status === 'a');

  return (
    <div className="page-wrapper">
      <Topbar title="Departments" subtitle="Manage company departments"
        actions={<button onClick={openAdd} className="btn-primary"><Plus size={15} />Add Department</button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        <div className="card"><p className="text-2xl font-bold text-blue-600">{departments.length}</p><p className="text-sm text-gray-500 mt-1">Total Departments</p></div>
        <div className="card"><p className="text-2xl font-bold text-emerald-600">{employees.filter(e => e.status === 'a').length}</p><p className="text-sm text-gray-500 mt-1">Total Employees</p></div>
        <div className="card"><p className="text-2xl font-bold text-purple-600">{departments.filter(d => d.head).length}</p><p className="text-sm text-gray-500 mt-1">With Head</p></div>
        <div className="card"><p className="text-2xl font-bold text-amber-600">৳{((departments.reduce((s, d) => s + (d.budget || 0), 0)) / 1000).toFixed(0)}K</p><p className="text-sm text-gray-500 mt-1">Total Budget</p></div>
      </div>

      {loading ? (
        <div className="card flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {departments.map((d, i) => {
            const emps = empsByDept(d.name);
            const isOpen = expanded === d._id;
            return (
              <div key={d._id} className="card hover:shadow-lg transition-all group">
                <div className="flex items-start justify-between mb-4">
                  <div className={`w-12 h-12 rounded-2xl bg-gradient-to-br ${BG_COLORS[i % BG_COLORS.length]} flex items-center justify-center`}>
                    <Layers size={22} className="text-white" />
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => openEdit(d)} className="p-1.5 text-blue-500 hover:bg-blue-50 rounded-lg"><Edit2 size={13} /></button>
                    <button onClick={() => handleDelete(d._id, d.name)} className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg"><Trash2 size={13} /></button>
                  </div>
                </div>
                <h3 className="font-bold text-gray-900 dark:text-white text-lg">{d.name}</h3>
                {d.head && <p className="text-sm text-gray-500 mt-0.5">Head: <span className="font-medium">{d.head}</span></p>}
                {d.description && <p className="text-xs text-gray-400 mt-2 line-clamp-2">{d.description}</p>}

                <div className="mt-4 pt-3 border-t border-gray-100 dark:border-gray-700 flex items-center justify-between">
                  {(d.budget || 0) > 0 ? (
                    <span className="text-sm font-bold text-gray-700 dark:text-gray-200">৳{(d.budget || 0).toLocaleString()}</span>
                  ) : <span />}
                  <button
                    onClick={() => setExpanded(isOpen ? null : d._id)}
                    className="flex items-center gap-1 text-xs text-gray-500 hover:text-blue-600 transition-colors"
                  >
                    <Users size={12} />
                    <span>{emps.length} employee{emps.length !== 1 ? 's' : ''}</span>
                    {isOpen ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
                  </button>
                </div>

                {isOpen && (
                  <div className="mt-3 space-y-2">
                    {emps.length === 0 ? (
                      <p className="text-xs text-gray-400 text-center py-2">No employees in this department</p>
                    ) : emps.map(e => (
                      <div key={e._id} className="flex items-center gap-2 p-2 bg-gray-50 dark:bg-gray-800 rounded-lg">
                        <div className="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                          {e.name.charAt(0)}
                        </div>
                        <div className="min-w-0">
                          <p className="text-xs font-semibold text-gray-800 dark:text-white truncate">{e.name}</p>
                          <p className="text-[10px] text-gray-400 truncate">{e.designation || '—'} · {e.contactNo || '—'}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
          {departments.length === 0 && (
            <div className="col-span-3 text-center py-16 text-gray-400">
              <Layers size={40} className="mx-auto mb-3 opacity-30" />
              <p>No departments found. Add the first one!</p>
            </div>
          )}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Department' : 'Add Department'}
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? 'Saving...' : editing ? 'Update' : 'Add'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Department Name *</label><input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="form-input" placeholder="e.g. Sales & Marketing" /></div>
          <div><label className="form-label">Department Head</label><input value={form.head} onChange={e => setForm({ ...form, head: e.target.value })} className="form-input" placeholder="e.g. Sonjoy Ghosh" /></div>
          <div><label className="form-label">Description</label><textarea value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} className="form-input" rows={2} /></div>
          <div><label className="form-label">Budget (৳)</label><input type="number" value={form.budget} onChange={e => setForm({ ...form, budget: e.target.value })} className="form-input" /></div>
        </div>
      </Modal>
    </div>
  );
}
