'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { RotateCcw, Plus, Search, Loader2, Trash2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface SalesReturn {
  _id: string; returnNo: string; invoiceNo?: string; partyName: string;
  returnDate: string; reason?: string;
  items: { productName: string; quantity: number; rate: number; totalAmount: number }[];
  totalAmount: number; status: 'pending' | 'approved' | 'refunded';
}

export default function SalesReturnsPage() {
  const [returns, setReturns] = useState<SalesReturn[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ partyName: '', invoiceNo: '', reason: '', productName: '', quantity: 1, rate: 0 });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/sales-returns');
      const json = await res.json();
      setReturns(json.data || []);
    } catch { toast.error('Failed to load returns'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const filtered = returns.filter(r =>
    r.partyName.toLowerCase().includes(search.toLowerCase()) || r.returnNo.toLowerCase().includes(search.toLowerCase())
  );

  const handleSave = async () => {
    if (!form.partyName || !form.productName) return toast.error('Party and product required');
    const totalAmount = form.quantity * form.rate;
    setSaving(true);
    try {
      const res = await fetch('/api/sales-returns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          partyName: form.partyName,
          invoiceNo: form.invoiceNo || undefined,
          reason: form.reason,
          items: [{ productName: form.productName, quantity: form.quantity, rate: form.rate, totalAmount }],
          totalAmount,
        }),
      });
      if (!res.ok) throw new Error();
      toast.success('Return created');
      setShowModal(false);
      setForm({ partyName: '', invoiceNo: '', reason: '', productName: '', quantity: 1, rate: 0 });
      fetchData();
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const updateStatus = async (id: string, status: SalesReturn['status']) => {
    try {
      await fetch(`/api/sales-returns/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      setReturns(prev => prev.map(r => r._id === id ? { ...r, status } : r));
      toast.success('Status updated');
    } catch { toast.error('Failed to update'); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/sales-returns/${id}`, { method: 'DELETE' });
      setReturns(prev => prev.filter(r => r._id !== id));
      toast.success('Deleted');
    } catch { toast.error('Failed to delete'); }
  };

  const statusColor = (s: string) => s === 'approved' ? 'badge-green' : s === 'refunded' ? 'badge-blue' : 'badge-yellow';

  return (
    <div className="page-wrapper">
      <Topbar title="Sales Returns" subtitle="Manage party return requests"
        actions={<button onClick={() => setShowModal(true)} className="btn-primary"><Plus size={15} />New Return</button>} />

      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Returns', value: returns.length, color: 'blue' },
          { label: 'Pending', value: returns.filter(r=>r.status==='pending').length, color: 'amber' },
          { label: 'Total Value', value: `৳${returns.reduce((a,r)=>a+r.totalAmount,0).toLocaleString()}`, color: 'red' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search returns..." className="form-input pl-9 w-64" />
          </div>
          <span className="text-sm text-gray-400">{filtered.length} returns</span>
        </div>
        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead><tr>{['Return ID', 'Invoice', 'Party', 'Date', 'Reason', 'Total', 'Status', 'Action'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.length === 0 && <tr><td colSpan={8} className="text-center py-10 text-gray-400"><RotateCcw className="w-8 h-8 mx-auto mb-2 opacity-30" /><p>No returns found</p></td></tr>}
                {filtered.map(r => (
                  <tr key={r._id} className="table-row">
                    <td className="table-cell font-mono font-bold text-red-500">{r.returnNo}</td>
                    <td className="table-cell font-mono text-xs text-blue-600">{r.invoiceNo || '—'}</td>
                    <td className="table-cell font-medium text-gray-900">{r.partyName}</td>
                    <td className="table-cell text-gray-500 text-xs">{r.returnDate?.split?.('T')[0]}</td>
                    <td className="table-cell text-gray-600 text-xs max-w-[150px] truncate">{r.reason}</td>
                    <td className="table-cell font-bold text-gray-900">৳{r.totalAmount.toLocaleString()}</td>
                    <td className="table-cell"><span className={`badge ${statusColor(r.status)}`}>{r.status}</span></td>
                    <td className="table-cell">
                      <div className="flex items-center gap-1">
                        <select value={r.status} onChange={e => updateStatus(r._id, e.target.value as SalesReturn['status'])} className="text-xs border border-gray-200 rounded-lg px-2 py-1.5 bg-white focus:outline-none">
                          {(['pending','approved','refunded'] as const).map(s => <option key={s} value={s}>{s}</option>)}
                        </select>
                        <button onClick={() => del(r._id)} className="p-1.5 text-red-400 hover:bg-red-50 rounded-lg"><Trash2 size={13} /></button>
                      </div>
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
        title="New Sales Return"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Create Return'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Party Name *</label><input value={form.partyName} onChange={e => setForm({...form, partyName: e.target.value})} className="form-input" /></div>
          <div><label className="form-label">Original Invoice ID</label><input value={form.invoiceNo} onChange={e => setForm({...form, invoiceNo: e.target.value})} className="form-input" placeholder="e.g. INV-0001" /></div>
          <div><label className="form-label">Return Reason</label><input value={form.reason} onChange={e => setForm({...form, reason: e.target.value})} className="form-input" placeholder="Defective, wrong item, etc." /></div>
          <div><label className="form-label">Product Name *</label><input value={form.productName} onChange={e => setForm({...form, productName: e.target.value})} className="form-input" /></div>
          <div className="grid grid-cols-2 gap-3">
            <div><label className="form-label">Quantity</label><input type="number" value={form.quantity} onChange={e => setForm({...form, quantity: Number(e.target.value)})} className="form-input" min="1" /></div>
            <div><label className="form-label">Unit Rate (৳)</label><input type="number" value={form.rate} onChange={e => setForm({...form, rate: Number(e.target.value)})} className="form-input" /></div>
          </div>
          <div className="bg-blue-50 rounded-xl p-3 text-sm font-semibold text-blue-700">Return Total: ৳{(form.quantity * form.rate).toLocaleString()}</div>
        </div>
      </Modal>
    </div>
  );
}
