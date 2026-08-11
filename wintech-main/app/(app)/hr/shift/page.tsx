'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Clock, Trash2, Loader2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Shift { _id: string; name: string; startTime: string; endTime: string; employees: string[]; color: string; days: string[]; }

const COLORS = ['bg-blue-500', 'bg-emerald-500', 'bg-purple-500', 'bg-amber-500', 'bg-red-500'];
const ALL_DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

export default function ShiftPage() {
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [employees, setEmployees] = useState<{ _id: string; name: string }[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ name: '', startTime: '09:00', endTime: '17:00', employees: [] as string[], color: COLORS[0], days: ['Monday','Tuesday','Wednesday','Thursday','Friday'] });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [sr, er] = await Promise.all([fetch('/api/shifts'), fetch('/api/employees')]);
      const [sj, ej] = await Promise.all([sr.json(), er.json()]);
      setShifts(sj.data || []);
      setEmployees((ej.data || []).map((e: { _id: string; name: string }) => ({ _id: e._id, name: e.name })));
    } catch { toast.error('Failed to load data'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const handleSave = async () => {
    if (!form.name) return toast.error('Shift name required');
    setSaving(true);
    try {
      const res = await fetch('/api/shifts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error();
      toast.success('Shift created');
      setShowModal(false);
      setForm({ name: '', startTime: '09:00', endTime: '17:00', employees: [], color: COLORS[0], days: ['Monday','Tuesday','Wednesday','Thursday','Friday'] });
      fetchData();
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/shifts/${id}`, { method: 'DELETE' });
      setShifts(prev => prev.filter(s => s._id !== id));
      toast.success('Deleted');
    } catch { toast.error('Failed to delete'); }
  };

  const toggleDay = (d: string) => setForm(f => ({ ...f, days: f.days.includes(d) ? f.days.filter(x => x !== d) : [...f.days, d] }));
  const toggleEmp = (e: string) => setForm(f => ({ ...f, employees: f.employees.includes(e) ? f.employees.filter(x => x !== e) : [...f.employees, e] }));

  return (
    <div className="page-wrapper">
      <Topbar title="Shift Roster" subtitle="Manage employee work shifts"
        actions={<button onClick={() => setShowModal(true)} className="btn-primary"><Plus size={15} /> New Shift</button>} />

      {loading ? (
        <div className="flex justify-center py-16"><Loader2 className="animate-spin text-gray-400" size={28} /></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {shifts.length === 0 && <div className="card text-center py-12 text-gray-400 col-span-3"><Clock className="w-10 h-10 mx-auto mb-2 opacity-30" /><p>No shifts created yet</p></div>}
          {shifts.map(s => (
            <div key={s._id} className="card hover:shadow-md transition-shadow">
              <div className={`${s.color} text-white rounded-xl p-4 mb-4`}>
                <div className="flex items-center justify-between">
                  <div><h3 className="font-bold text-lg">{s.name}</h3><p className="text-white/80 text-sm mt-0.5">{s.startTime} — {s.endTime}</p></div>
                  <div className="flex items-center gap-2">
                    <Clock size={24} className="text-white/60" />
                    <button onClick={() => del(s._id)} className="p-1.5 bg-white/20 hover:bg-white/30 rounded-lg transition-colors"><Trash2 size={13} className="text-white" /></button>
                  </div>
                </div>
              </div>
              <div className="space-y-3">
                <div>
                  <p className="text-xs font-bold text-gray-500 uppercase mb-2">Working Days</p>
                  <div className="flex flex-wrap gap-1">
                    {ALL_DAYS.map(d => (
                      <span key={d} className={`text-xs px-2 py-1 rounded-lg font-medium ${s.days.includes(d) ? 'bg-blue-50 text-blue-600' : 'bg-gray-50 text-gray-300'}`}>{d.slice(0,3)}</span>
                    ))}
                  </div>
                </div>
                <div>
                  <p className="text-xs font-bold text-gray-500 uppercase mb-2">Assigned Employees ({s.employees.length})</p>
                  <div className="flex flex-wrap gap-1">
                    {s.employees.map(e => <span key={e} className="badge badge-gray text-xs">{e}</span>)}
                    {s.employees.length === 0 && <span className="text-xs text-gray-400">None assigned</span>}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title="Create Shift"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Create Shift'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Shift Name</label><input value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="form-input" placeholder="e.g. Morning Shift" /></div>
          <div className="grid grid-cols-2 gap-4">
            <div><label className="form-label">Start Time</label><input type="time" value={form.startTime} onChange={e => setForm({...form, startTime: e.target.value})} className="form-input" /></div>
            <div><label className="form-label">End Time</label><input type="time" value={form.endTime} onChange={e => setForm({...form, endTime: e.target.value})} className="form-input" /></div>
          </div>
          <div>
            <label className="form-label">Color</label>
            <div className="flex gap-2 mt-1">
              {COLORS.map(c => <button key={c} type="button" onClick={() => setForm({...form, color: c})} className={`w-7 h-7 rounded-full ${c} ${form.color === c ? 'ring-2 ring-offset-2 ring-gray-400' : ''}`} />)}
            </div>
          </div>
          <div>
            <label className="form-label">Working Days</label>
            <div className="flex flex-wrap gap-2 mt-1">
              {ALL_DAYS.map(d => <button key={d} type="button" onClick={() => toggleDay(d)} className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${form.days.includes(d) ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>{d.slice(0,3)}</button>)}
            </div>
          </div>
          {employees.length > 0 && (
            <div>
              <label className="form-label">Assign Employees</label>
              <div className="space-y-2 mt-1 max-h-40 overflow-y-auto">
                {employees.map(e => (
                  <label key={e._id} className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" checked={form.employees.includes(e.name)} onChange={() => toggleEmp(e.name)} className="w-4 h-4 rounded text-blue-600" />
                    <span className="text-sm text-gray-700">{e.name}</span>
                  </label>
                ))}
              </div>
            </div>
          )}
        </div>
      </Modal>
    </div>
  );
}
