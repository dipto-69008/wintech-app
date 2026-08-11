'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Megaphone, Trash2, Pin, Loader2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Announcement { _id: string; title: string; body: string; audience: string; priority: 'low' | 'medium' | 'high'; pinned: boolean; date: string; author: string; }

const PRIORITY_COLORS = { high: 'badge-red', medium: 'badge-yellow', low: 'badge-blue' };
const PRIORITY_BG = { high: 'border-l-red-500', medium: 'border-l-amber-400', low: 'border-l-blue-400' };

export default function AnnouncementsPage() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ title: '', body: '', audience: 'All Staff', priority: 'medium' as Announcement['priority'], author: 'Admin' });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/announcements');
      const json = await res.json();
      setAnnouncements(json.data || []);
    } catch { toast.error('Failed to load announcements'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const sorted = [...announcements].sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));

  const handleSave = async () => {
    if (!form.title || !form.body) return toast.error('Fill all fields');
    setSaving(true);
    try {
      const res = await fetch('/api/announcements', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, date: new Date().toISOString().split('T')[0] }),
      });
      if (!res.ok) throw new Error();
      toast.success('Announcement published');
      setShowModal(false);
      setForm({ title: '', body: '', audience: 'All Staff', priority: 'medium', author: 'Admin' });
      fetchData();
    } catch { toast.error('Failed to publish'); }
    finally { setSaving(false); }
  };

  const togglePin = async (a: Announcement) => {
    try {
      await fetch(`/api/announcements/${a._id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pinned: !a.pinned }),
      });
      setAnnouncements(prev => prev.map(x => x._id === a._id ? { ...x, pinned: !x.pinned } : x));
    } catch { toast.error('Failed to update'); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/announcements/${id}`, { method: 'DELETE' });
      setAnnouncements(prev => prev.filter(a => a._id !== id));
      toast.success('Deleted');
    } catch { toast.error('Failed to delete'); }
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Announcements" subtitle="Company-wide communications"
        actions={<button onClick={() => setShowModal(true)} className="btn-primary"><Plus size={15} /> New Announcement</button>} />

      <div className="grid grid-cols-3 gap-4 mb-2">
        {[
          { label: 'Total', value: announcements.length, color: 'blue' },
          { label: 'Pinned', value: announcements.filter(a => a.pinned).length, color: 'purple' },
          { label: 'High Priority', value: announcements.filter(a => a.priority === 'high').length, color: 'red' },
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
        <div className="space-y-3">
          {sorted.length === 0 && <div className="card text-center py-12 text-gray-400"><Megaphone className="w-10 h-10 mx-auto mb-2 opacity-30" /><p>No announcements yet</p></div>}
          {sorted.map(a => (
            <div key={a._id} className={`card border-l-4 ${PRIORITY_BG[a.priority]} group`}>
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-start gap-3 flex-1">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${a.priority === 'high' ? 'bg-red-50' : a.priority === 'medium' ? 'bg-amber-50' : 'bg-blue-50'}`}>
                    <Megaphone className={`w-5 h-5 ${a.priority === 'high' ? 'text-red-500' : a.priority === 'medium' ? 'text-amber-500' : 'text-blue-500'}`} />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <h3 className="font-bold text-gray-900">{a.title}</h3>
                      {a.pinned && <span className="text-[10px] bg-purple-100 text-purple-600 px-2 py-0.5 rounded-full font-semibold flex items-center gap-1"><Pin size={9} />Pinned</span>}
                      <span className={`badge ${PRIORITY_COLORS[a.priority]}`}>{a.priority}</span>
                      <span className="badge badge-gray">{a.audience}</span>
                    </div>
                    <p className="text-sm text-gray-600 leading-relaxed">{a.body}</p>
                    <p className="text-xs text-gray-400 mt-2">By {a.author} • {a.date}</p>
                  </div>
                </div>
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button onClick={() => togglePin(a)} className={`p-2 rounded-xl transition-colors ${a.pinned ? 'text-purple-500 bg-purple-50' : 'text-gray-400 hover:bg-gray-50'}`}><Pin size={14} /></button>
                  <button onClick={() => del(a._id)} className="p-2 text-red-400 hover:bg-red-50 rounded-xl"><Trash2 size={14} /></button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title="New Announcement"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Publish'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Title</label><input value={form.title} onChange={e => setForm({...form, title: e.target.value})} className="form-input" /></div>
          <div className="grid grid-cols-2 gap-4">
            <div><label className="form-label">Audience</label><select value={form.audience} onChange={e => setForm({...form, audience: e.target.value})} className="form-input"><option>All Staff</option><option>Engineering</option><option>Sales</option><option>HR</option><option>Accounting</option></select></div>
            <div><label className="form-label">Priority</label><select value={form.priority} onChange={e => setForm({...form, priority: e.target.value as Announcement['priority']})} className="form-input"><option value="low">Low</option><option value="medium">Medium</option><option value="high">High</option></select></div>
          </div>
          <div><label className="form-label">Author</label><input value={form.author} onChange={e => setForm({...form, author: e.target.value})} className="form-input" /></div>
          <div><label className="form-label">Message</label><textarea value={form.body} onChange={e => setForm({...form, body: e.target.value})} className="form-input" rows={4} /></div>
        </div>
      </Modal>
    </div>
  );
}
