'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Calendar, Trash2, Loader2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Holiday { _id: string; name: string; date: string; type: 'public' | 'company' | 'optional'; description: string; }

const TYPE_COLORS: Record<Holiday['type'], string> = { public: 'badge-red', company: 'badge-blue', optional: 'badge-yellow' };

export default function HolidayPage() {
  const [holidays, setHolidays] = useState<Holiday[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ name: '', date: '', type: 'public' as Holiday['type'], description: '' });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/holidays');
      const json = await res.json();
      setHolidays(json.data || []);
    } catch { toast.error('Failed to load holidays'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const sorted = [...holidays].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  const upcoming = holidays.filter(h => new Date(h.date) >= new Date()).length;

  const handleSave = async () => {
    if (!form.name || !form.date) return toast.error('Fill all fields');
    setSaving(true);
    try {
      const res = await fetch('/api/holidays', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error();
      toast.success('Holiday added');
      setShowModal(false);
      setForm({ name: '', date: '', type: 'public', description: '' });
      fetchData();
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/holidays/${id}`, { method: 'DELETE' });
      setHolidays(prev => prev.filter(h => h._id !== id));
      toast.success('Removed');
    } catch { toast.error('Failed to delete'); }
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Holidays" subtitle="Manage company and public holidays"
        actions={<button onClick={() => setShowModal(true)} className="btn-primary"><Plus size={15} /> Add Holiday</button>} />

      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Holidays', value: holidays.length, color: 'blue' },
          { label: 'Upcoming', value: upcoming, color: 'emerald' },
          { label: 'Public Holidays', value: holidays.filter(h => h.type === 'public').length, color: 'red' },
        ].map(s => (
          <div key={s.label} className="card text-center">
            <p className={`text-3xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-xs text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 className="animate-spin text-gray-400" size={28} /></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {sorted.length === 0 && <div className="card text-center py-12 text-gray-400 col-span-3"><Calendar className="w-10 h-10 mx-auto mb-2 opacity-30" /><p>No holidays added yet</p></div>}
          {sorted.map(h => {
            const date = new Date(h.date);
            const isPast = date < new Date();
            return (
              <div key={h._id} className={`card flex items-start gap-4 ${isPast ? 'opacity-50' : ''}`}>
                <div className={`flex-shrink-0 w-14 h-14 rounded-2xl flex flex-col items-center justify-center ${h.type === 'public' ? 'bg-red-50' : h.type === 'company' ? 'bg-blue-50' : 'bg-amber-50'}`}>
                  <span className={`text-lg font-bold ${h.type === 'public' ? 'text-red-500' : h.type === 'company' ? 'text-blue-500' : 'text-amber-500'}`}>{date.getDate()}</span>
                  <span className={`text-[10px] font-semibold ${h.type === 'public' ? 'text-red-400' : h.type === 'company' ? 'text-blue-400' : 'text-amber-400'}`}>{date.toLocaleString('default', { month: 'short' }).toUpperCase()}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2">
                    <p className="font-bold text-gray-900 text-sm">{h.name}</p>
                    <button onClick={() => del(h._id)} className="p-1 text-gray-300 hover:text-red-500 transition-colors flex-shrink-0"><Trash2 size={13} /></button>
                  </div>
                  <span className={`badge ${TYPE_COLORS[h.type]} text-[10px] mt-1`}>{h.type}</span>
                  {h.description && <p className="text-xs text-gray-400 mt-1">{h.description}</p>}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title="Add Holiday"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Add Holiday'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Holiday Name</label><input value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="form-input" /></div>
          <div className="grid grid-cols-2 gap-4">
            <div><label className="form-label">Date</label><input type="date" value={form.date} onChange={e => setForm({...form, date: e.target.value})} className="form-input" /></div>
            <div><label className="form-label">Type</label><select value={form.type} onChange={e => setForm({...form, type: e.target.value as Holiday['type']})} className="form-input"><option value="public">Public</option><option value="company">Company</option><option value="optional">Optional</option></select></div>
          </div>
          <div><label className="form-label">Description</label><input value={form.description} onChange={e => setForm({...form, description: e.target.value})} className="form-input" /></div>
        </div>
      </Modal>
    </div>
  );
}
