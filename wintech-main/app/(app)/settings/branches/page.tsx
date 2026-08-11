'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Edit2, Trash2, MapPin, Phone, User, Loader2, Building2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Branch {
  _id: string; name: string; nickname?: string; zoneCode?: string;
  address?: string; phone?: string; manager?: string; status?: string;
}

const emptyForm = () => ({ name: '', nickname: '', zoneCode: '', address: '', phone: '', manager: '', status: 'a' });

export default function BranchesPage() {
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Branch | null>(null);
  const [form, setForm] = useState(emptyForm());

  const fetchBranches = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch('/api/branches');
      const d = await r.json();
      setBranches(d.data || []);
    } catch { toast.error('Could not load branches'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchBranches(); }, [fetchBranches]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (b: Branch) => {
    setEditing(b);
    setForm({ name: b.name, nickname: b.nickname || '', zoneCode: b.zoneCode || '', address: b.address || '', phone: b.phone || '', manager: b.manager || '', status: b.status || 'a' });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name) return toast.error('Branch name required');
    setSaving(true);
    try {
      const url = editing ? `/api/branches/${editing._id}` : '/api/branches';
      const method = editing ? 'PUT' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success(editing ? 'Branch updated' : 'Branch added');
      setShowModal(false);
      fetchBranches();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (b: Branch) => {
    if (!confirm(`Delete "${b.name}"?`)) return;
    try {
      const res = await fetch(`/api/branches/${b._id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Delete failed');
      toast.success('Deleted');
      fetchBranches();
    } catch { toast.error('Delete failed'); }
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Branches" subtitle={`${branches.length} branches / zones`}
        actions={<button onClick={openAdd} className="btn-primary"><Plus size={15} /> Add Branch</button>} />

      <div className="card">
        {loading ? (
          <div className="flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
        ) : branches.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <Building2 className="w-10 h-10 mx-auto mb-2 opacity-30" />
            <p className="font-medium">No branches found</p>
            <p className="text-xs mt-1">Add a branch or run a monthly sales import</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {branches.map(b => (
              <div key={b._id} className="border border-gray-100 dark:border-gray-800 rounded-2xl p-4 hover:shadow-md transition-all group">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <div className="w-11 h-11 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-xl flex items-center justify-center text-white font-bold text-lg">
                      {b.name.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <p className="font-bold text-gray-900 dark:text-white text-sm">{b.name}</p>
                      {b.nickname && <p className="text-xs text-emerald-500 font-medium">&quot;{b.nickname}&quot;</p>}
                    </div>
                  </div>
                  <span className={`badge ${b.status === 'a' ? 'badge-green' : 'badge-gray'}`}>{b.status === 'a' ? 'Active' : 'Inactive'}</span>
                </div>
                <div className="space-y-1.5 mb-3">
                  {b.manager && <div className="flex items-center gap-2 text-xs text-gray-500"><User size={11} />{b.manager}</div>}
                  {b.phone && <div className="flex items-center gap-2 text-xs text-gray-500"><Phone size={11} />{b.phone}</div>}
                  {b.address && <div className="flex items-center gap-2 text-xs text-gray-500"><MapPin size={11} />{b.address}</div>}
                </div>
                <div className="flex items-center justify-end pt-3 border-t border-gray-50 dark:border-gray-800">
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => openEdit(b)} className="p-1.5 text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg"><Edit2 size={13} /></button>
                    <button onClick={() => handleDelete(b)} className="p-1.5 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg"><Trash2 size={13} /></button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={`${editing ? 'Edit' : 'Add'} Branch`}
        size="lg"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? 'Saving...' : 'Save'}</button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          <div className="col-span-2"><label className="form-label">Branch / Zone Name *</label><input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. Comilla-1" className="form-input" /></div>
          <div><label className="form-label">Nickname</label><input value={form.nickname} onChange={e => setForm({ ...form, nickname: e.target.value })} placeholder="e.g. Kingfisher" className="form-input" /></div>
          <div><label className="form-label">Zone Code</label><input value={form.zoneCode} onChange={e => setForm({ ...form, zoneCode: e.target.value })} className="form-input" /></div>
          <div><label className="form-label">Manager</label><input value={form.manager} onChange={e => setForm({ ...form, manager: e.target.value })} className="form-input" /></div>
          <div><label className="form-label">Phone</label><input value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} className="form-input" /></div>
          <div className="col-span-2"><label className="form-label">Address</label><input value={form.address} onChange={e => setForm({ ...form, address: e.target.value })} className="form-input" /></div>
          <div><label className="form-label">Status</label>
            <select value={form.status} onChange={e => setForm({ ...form, status: e.target.value })} className="form-input">
              <option value="a">Active</option>
              <option value="d">Inactive</option>
            </select>
          </div>
        </div>
      </Modal>
    </div>
  );
}
