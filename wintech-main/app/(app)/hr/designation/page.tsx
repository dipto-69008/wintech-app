'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Edit2, Trash2, BadgeCheck, Loader2, Users } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Designation { _id: string; name: string; department?: string; level?: string; description?: string; status: string; }
interface Employee { _id: string; name: string; designation?: string; department?: string; contactNo?: string; status: string; }

const LEVELS = ['Intern', 'Jr. Officer', 'Officer', 'Sr. Officer', 'Executive', 'Manager', 'Deputy Manager', 'Director', 'C-Level'];
const LEVEL_COLORS: Record<string, string> = {
  Intern: 'badge-gray', 'Jr. Officer': 'badge-gray', Officer: 'badge-blue', 'Sr. Officer': 'badge-teal',
  Executive: 'badge-purple', Manager: 'badge-yellow', 'Deputy Manager': 'badge-yellow',
  Director: 'badge-red', 'C-Level': 'badge-green',
};

export default function DesignationPage() {
  const [designations, setDesignations] = useState<Designation[]>([]);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Designation | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', department: '', level: 'Officer', description: '' });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [dr, er] = await Promise.all([
        fetch('/api/designations').then(r => r.json()),
        fetch('/api/employees?limit=500').then(r => r.json()),
      ]);
      setDesignations(dr.data || []);
      setEmployees(er.data || []);
    } catch { toast.error('Failed to load'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const openAdd = () => { setEditing(null); setForm({ name: '', department: '', level: 'Officer', description: '' }); setShowModal(true); };
  const openEdit = (d: Designation) => {
    setEditing(d);
    setForm({ name: d.name, department: d.department || '', level: d.level || 'Officer', description: d.description || '' });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name) return toast.error('Name required');
    setSaving(true);
    try {
      const url = editing ? `/api/designations/${editing._id}` : '/api/designations';
      const method = editing ? 'PUT' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...form, status: 'a' }) });
      if (!res.ok) throw new Error();
      toast.success(editing ? 'Updated' : 'Designation added');
      setShowModal(false); fetchData();
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const del = async (id: string) => {
    if (!confirm('Delete this designation?')) return;
    try {
      await fetch(`/api/designations/${id}`, { method: 'DELETE' });
      toast.success('Deleted'); fetchData();
    } catch { toast.error('Failed to delete'); }
  };

  const empsByDesig = (name: string) => employees.filter(e =>
    e.designation?.toLowerCase() === name.toLowerCase() && e.status === 'a'
  );

  return (
    <div className="page-wrapper">
      <Topbar title="Designations" subtitle={`${designations.length} job titles`}
        actions={<button onClick={openAdd} className="btn-primary"><Plus size={15} /> Add Designation</button>} />

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 className="animate-spin text-gray-400" size={28} /></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {designations.length === 0 && (
            <div className="card text-center py-12 text-gray-400 col-span-3">
              <BadgeCheck className="w-10 h-10 mx-auto mb-2 opacity-30" />
              <p>No designations yet. Add the first one!</p>
            </div>
          )}
          {designations.map(d => {
            const emps = empsByDesig(d.name);
            const isOpen = expanded === d._id;
            return (
              <div key={d._id} className="card hover:shadow-md transition-all group">
                <div className="flex items-start justify-between mb-3">
                  <div className="w-10 h-10 bg-blue-50 dark:bg-blue-900/20 rounded-xl flex items-center justify-center">
                    <BadgeCheck className="w-5 h-5 text-blue-500" />
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => openEdit(d)} className="p-1.5 text-blue-500 hover:bg-blue-50 rounded-lg"><Edit2 size={13} /></button>
                    <button onClick={() => del(d._id)} className="p-1.5 text-red-400 hover:bg-red-50 rounded-lg"><Trash2 size={13} /></button>
                  </div>
                </div>
                <h3 className="font-bold text-gray-900 dark:text-white">{d.name}</h3>
                {d.department && <p className="text-xs text-gray-500 mt-0.5">{d.department}</p>}
                {d.description && <p className="text-xs text-gray-400 mt-2 line-clamp-2">{d.description}</p>}
                <div className="flex items-center justify-between mt-3 pt-3 border-t border-gray-100 dark:border-gray-700">
                  {d.level ? <span className={`badge text-[10px] ${LEVEL_COLORS[d.level] || 'badge-gray'}`}>{d.level}</span> : <span />}
                  <button
                    onClick={() => setExpanded(isOpen ? null : d._id)}
                    className="flex items-center gap-1 text-xs text-gray-500 hover:text-blue-600 transition-colors"
                  >
                    <Users size={12} />
                    <span>{emps.length} employee{emps.length !== 1 ? 's' : ''}</span>
                  </button>
                </div>
                {isOpen && emps.length > 0 && (
                  <div className="mt-3 pt-3 border-t border-gray-100 dark:border-gray-700 space-y-2">
                    {emps.map(e => (
                      <div key={e._id} className="flex items-center gap-2 p-2 bg-gray-50 dark:bg-gray-800 rounded-lg">
                        <div className="w-7 h-7 rounded-full bg-gradient-to-br from-blue-400 to-purple-500 flex items-center justify-center text-white text-[10px] font-bold flex-shrink-0">
                          {e.name.charAt(0)}
                        </div>
                        <div className="min-w-0">
                          <p className="text-xs font-semibold text-gray-800 dark:text-white truncate">{e.name}</p>
                          <p className="text-[10px] text-gray-400 truncate">{e.department || '—'} · {e.contactNo || '—'}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={`${editing ? 'Edit' : 'Add'} Designation`}
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Save'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div>
            <label className="form-label">Job Title *</label>
            <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="form-input" placeholder="e.g. Sr. Officer" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="form-label">Department</label>
              <input value={form.department} onChange={e => setForm({ ...form, department: e.target.value })} className="form-input" placeholder="e.g. Sales" />
            </div>
            <div>
              <label className="form-label">Level</label>
              <select value={form.level} onChange={e => setForm({ ...form, level: e.target.value })} className="form-input">
                {LEVELS.map(l => <option key={l}>{l}</option>)}
              </select>
            </div>
          </div>
          <div>
            <label className="form-label">Description</label>
            <textarea value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} className="form-input" rows={2} placeholder="Optional notes..." />
          </div>
        </div>
      </Modal>
    </div>
  );
}
