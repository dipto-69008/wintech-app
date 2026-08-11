'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, CalendarDays, CheckCircle2, XCircle, Clock, Loader2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Leave {
  _id: string; employee: string; type: string; from: string; to: string;
  days: number; reason: string; status: 'pending' | 'approved' | 'rejected'; appliedOn: string;
}

const LEAVE_TYPES = ['Annual', 'Sick', 'Casual', 'Maternity', 'Paternity', 'Unpaid', 'Emergency'];

export default function LeavesPage() {
  const [leaves, setLeaves] = useState<Leave[]>([]);
  const [employees, setEmployees] = useState<{ _id: string; name: string }[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [filter, setFilter] = useState<'all' | Leave['status']>('all');
  const [form, setForm] = useState({ employee: '', type: 'Annual', from: '', to: '', reason: '' });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [lr, er] = await Promise.all([fetch('/api/leaves'), fetch('/api/employees')]);
      const [lj, ej] = await Promise.all([lr.json(), er.json()]);
      setLeaves(lj.data || []);
      setEmployees((ej.data || []).map((e: { _id: string; name: string }) => ({ _id: e._id, name: e.name })));
      if ((ej.data || []).length > 0 && !form.employee) {
        setForm(f => ({ ...f, employee: ej.data[0].name }));
      }
    } catch { toast.error('Failed to load data'); }
    finally { setLoading(false); }
  }, []); // eslint-disable-line

  useEffect(() => { fetchData(); }, [fetchData]);

  const filtered = leaves.filter(l => filter === 'all' || l.status === filter);

  const updateStatus = async (id: string, status: Leave['status']) => {
    try {
      await fetch(`/api/leaves/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      setLeaves(prev => prev.map(l => l._id === id ? { ...l, status } : l));
      toast.success(`Leave ${status}`);
    } catch { toast.error('Failed to update'); }
  };

  const handleSave = async () => {
    if (!form.employee || !form.from || !form.to) return toast.error('Fill required fields');
    const from = new Date(form.from), to = new Date(form.to);
    const days = Math.ceil((to.getTime() - from.getTime()) / 86400000) + 1;
    setSaving(true);
    try {
      const res = await fetch('/api/leaves', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, days, appliedOn: new Date().toISOString().split('T')[0] }),
      });
      if (!res.ok) throw new Error();
      toast.success('Leave applied');
      setShowModal(false);
      setForm(f => ({ ...f, from: '', to: '', reason: '' }));
      fetchData();
    } catch { toast.error('Failed to submit'); }
    finally { setSaving(false); }
  };

  const statusBadge = (s: string) => s === 'approved' ? 'badge-green' : s === 'rejected' ? 'badge-red' : 'badge-yellow';
  const pending = leaves.filter(l => l.status === 'pending').length;
  const approved = leaves.filter(l => l.status === 'approved').length;

  return (
    <div className="page-wrapper">
      <Topbar title="Leave Management" subtitle="Track and manage employee leave requests"
        actions={<button onClick={() => setShowModal(true)} className="btn-primary"><Plus size={15} /> Apply Leave</button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Requests', value: leaves.length, color: 'blue', icon: CalendarDays },
          { label: 'Pending', value: pending, color: 'amber', icon: Clock },
          { label: 'Approved', value: approved, color: 'emerald', icon: CheckCircle2 },
          { label: 'Rejected', value: leaves.filter(l => l.status === 'rejected').length, color: 'red', icon: XCircle },
        ].map(s => (
          <div key={s.label} className="card flex items-center gap-4">
            <div className={`w-12 h-12 bg-${s.color}-50 rounded-2xl flex items-center justify-center`}>
              <s.icon className={`w-5 h-5 text-${s.color}-500`} />
            </div>
            <div><p className="text-2xl font-bold text-gray-900">{s.value}</p><p className="text-xs text-gray-400">{s.label}</p></div>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="flex gap-2 flex-wrap">
            {(['all', 'pending', 'approved', 'rejected'] as const).map(f => (
              <button key={f} onClick={() => setFilter(f)} className={`px-4 py-2 rounded-xl text-sm font-medium capitalize transition-all ${filter === f ? 'bg-blue-600 text-white shadow-sm' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>{f}</button>
            ))}
          </div>
          <span className="text-sm text-gray-400">{filtered.length} records</span>
        </div>
        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead><tr>{['Employee', 'Leave Type', 'From', 'To', 'Days', 'Reason', 'Applied On', 'Status', 'Actions'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.length === 0 && <tr><td colSpan={9} className="text-center py-10 text-gray-400">No leave requests found</td></tr>}
                {filtered.map(l => (
                  <tr key={l._id} className="table-row">
                    <td className="table-cell">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{l.employee.charAt(0)}</div>
                        <span className="font-medium text-sm">{l.employee}</span>
                      </div>
                    </td>
                    <td className="table-cell"><span className="badge badge-purple">{l.type}</span></td>
                    <td className="table-cell text-gray-500 text-xs">{l.from}</td>
                    <td className="table-cell text-gray-500 text-xs">{l.to}</td>
                    <td className="table-cell font-bold text-center">{l.days}</td>
                    <td className="table-cell text-gray-500 max-w-[160px] truncate">{l.reason}</td>
                    <td className="table-cell text-gray-400 text-xs">{l.appliedOn}</td>
                    <td className="table-cell"><span className={`badge ${statusBadge(l.status)}`}>{l.status}</span></td>
                    <td className="table-cell">
                      {l.status === 'pending' && (
                        <div className="flex gap-1">
                          <button onClick={() => updateStatus(l._id, 'approved')} className="p-1.5 text-emerald-500 hover:bg-emerald-50 rounded-lg transition-colors"><CheckCircle2 size={14} /></button>
                          <button onClick={() => updateStatus(l._id, 'rejected')} className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition-colors"><XCircle size={14} /></button>
                        </div>
                      )}
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
        title="Apply for Leave"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Submit'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div>
            <label className="form-label">Employee</label>
            {employees.length > 0 ? (
              <select value={form.employee} onChange={e => setForm({...form, employee: e.target.value})} className="form-input">
                <option value="">Select employee</option>
                {employees.map(e => <option key={e._id} value={e.name}>{e.name}</option>)}
              </select>
            ) : (
              <input value={form.employee} onChange={e => setForm({...form, employee: e.target.value})} className="form-input" placeholder="Employee name" />
            )}
          </div>
          <div><label className="form-label">Leave Type</label><select value={form.type} onChange={e => setForm({...form, type: e.target.value})} className="form-input">{LEAVE_TYPES.map(t => <option key={t}>{t}</option>)}</select></div>
          <div className="grid grid-cols-2 gap-4">
            <div><label className="form-label">From</label><input type="date" value={form.from} onChange={e => setForm({...form, from: e.target.value})} className="form-input" /></div>
            <div><label className="form-label">To</label><input type="date" value={form.to} onChange={e => setForm({...form, to: e.target.value})} className="form-input" /></div>
          </div>
          <div><label className="form-label">Reason</label><textarea value={form.reason} onChange={e => setForm({...form, reason: e.target.value})} className="form-input" rows={3} /></div>
        </div>
      </Modal>
    </div>
  );
}
