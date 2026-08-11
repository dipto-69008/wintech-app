'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { ScrollText, Plus, Search, Eye, Loader2, Trash2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface QuotationItem { productName: string; quantity: number; rate: number; totalAmount: number; }
interface Quotation { _id: string; quotationNo: string; partyName: string; partyEmail?: string; quotationDate: string; validUntil?: string; items: QuotationItem[]; totalAmount: number; status: 'draft' | 'sent' | 'accepted' | 'rejected'; notes?: string; }

export default function QuotationsPage() {
  const [quotations, setQuotations] = useState<Quotation[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [viewItem, setViewItem] = useState<Quotation | null>(null);
  const [form, setForm] = useState({ partyName: '', partyEmail: '', validUntil: '', notes: '', items: [{ productName: '', quantity: 1, rate: 0 }] });

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/quotations');
      const json = await res.json();
      setQuotations(json.data || []);
    } catch { toast.error('Failed to load quotations'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const filtered = quotations.filter(q =>
    q.partyName.toLowerCase().includes(search.toLowerCase()) || q.quotationNo.toLowerCase().includes(search.toLowerCase())
  );

  const addItem = () => setForm(f => ({ ...f, items: [...f.items, { productName: '', quantity: 1, rate: 0 }] }));
  const removeItem = (i: number) => setForm(f => ({ ...f, items: f.items.filter((_, idx) => idx !== i) }));
  const updateItem = (i: number, field: string, value: string | number) => {
    setForm(f => { const items = [...f.items]; (items[i] as Record<string, string | number>)[field] = value; return { ...f, items }; });
  };

  const handleSave = async () => {
    if (!form.partyName) return toast.error('Party required');
    setSaving(true);
    try {
      const items = form.items.map(i => ({ ...i, totalAmount: i.quantity * i.rate }));
      const totalAmount = items.reduce((a, i) => a + i.totalAmount, 0);
      const res = await fetch('/api/quotations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partyName: form.partyName, partyEmail: form.partyEmail, validUntil: form.validUntil || undefined, notes: form.notes, items, totalAmount, subTotal: totalAmount, discountAmount: 0, taxAmount: 0 }),
      });
      if (!res.ok) throw new Error();
      toast.success('Quotation created');
      setShowModal(false);
      setForm({ partyName: '', partyEmail: '', validUntil: '', notes: '', items: [{ productName: '', quantity: 1, rate: 0 }] });
      fetchData();
    } catch { toast.error('Failed to save'); }
    finally { setSaving(false); }
  };

  const updateStatus = async (id: string, status: Quotation['status']) => {
    try {
      await fetch(`/api/quotations/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      setQuotations(prev => prev.map(q => q._id === id ? { ...q, status } : q));
      toast.success('Status updated');
    } catch { toast.error('Failed to update'); }
  };

  const del = async (id: string) => {
    try {
      await fetch(`/api/quotations/${id}`, { method: 'DELETE' });
      setQuotations(prev => prev.filter(q => q._id !== id));
      toast.success('Deleted');
    } catch { toast.error('Failed to delete'); }
  };

  const statusColor = (s: string) => s === 'accepted' ? 'badge-green' : s === 'rejected' ? 'badge-red' : s === 'sent' ? 'badge-blue' : 'badge-gray';

  return (
    <div className="page-wrapper">
      <Topbar title="Quotations" subtitle="Manage price quotations for parties"
        actions={<button onClick={() => setShowModal(true)} className="btn-primary"><Plus size={15} />New Quotation</button>} />

      <div className="grid grid-cols-4 gap-4">
        {[
          { label: 'Total', value: quotations.length, color: 'blue' },
          { label: 'Sent', value: quotations.filter(q=>q.status==='sent').length, color: 'purple' },
          { label: 'Accepted', value: quotations.filter(q=>q.status==='accepted').length, color: 'emerald' },
          { label: 'Total Value', value: `৳${quotations.reduce((a,q)=>a+q.totalAmount,0).toLocaleString()}`, color: 'amber' },
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
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search quotations..." className="form-input pl-9 w-64" />
          </div>
          <span className="text-sm text-gray-400">{filtered.length} quotations</span>
        </div>
        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead><tr>{['Quotation #', 'Party', 'Date', 'Valid Until', 'Total', 'Status', 'Action'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.map(q => (
                  <tr key={q._id} className="table-row">
                    <td className="table-cell font-mono font-bold text-purple-600">{q.quotationNo}</td>
                    <td className="table-cell">
                      <p className="font-medium text-gray-900">{q.partyName}</p>
                      {q.partyEmail && <p className="text-xs text-gray-400">{q.partyEmail}</p>}
                    </td>
                    <td className="table-cell text-gray-500 text-xs">{q.quotationDate?.split('T')[0]}</td>
                    <td className="table-cell text-gray-500 text-xs">{q.validUntil?.split?.('T')[0] || '—'}</td>
                    <td className="table-cell font-bold text-gray-900">৳{q.totalAmount.toLocaleString()}</td>
                    <td className="table-cell"><span className={`badge ${statusColor(q.status)}`}>{q.status}</span></td>
                    <td className="table-cell">
                      <div className="flex gap-2 items-center">
                        <button onClick={() => setViewItem(q)} className="p-1.5 text-blue-500 hover:bg-blue-50 rounded-lg"><Eye size={14} /></button>
                        <select value={q.status} onChange={e => updateStatus(q._id, e.target.value as Quotation['status'])} className="text-xs border border-gray-200 rounded-lg px-2 py-1.5 bg-white focus:outline-none">
                          {(['draft','sent','accepted','rejected'] as const).map(s => <option key={s} value={s}>{s}</option>)}
                        </select>
                        <button onClick={() => del(q._id)} className="p-1.5 text-red-400 hover:bg-red-50 rounded-lg"><Trash2 size={14} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filtered.length === 0 && !loading && <div className="text-center py-12 text-gray-400"><ScrollText className="w-10 h-10 mx-auto mb-2 opacity-30" /><p>No quotations found</p></div>}
          </div>
        )}
      </div>

      <Modal
        open={!!viewItem}
        onClose={() => setViewItem(null)}
        title={viewItem ? viewItem.quotationNo : ''}
      >
        {viewItem && (
          <>
            <div className="bg-gray-50 rounded-xl p-4 mb-4">
              <p className="font-bold">{viewItem.partyName}</p>
              {viewItem.partyEmail && <p className="text-sm text-gray-500">{viewItem.partyEmail}</p>}
              <p className="text-xs text-gray-400 mt-1">Valid until: {viewItem.validUntil?.split?.('T')[0] || '—'}</p>
              <span className={`badge ${statusColor(viewItem.status)} mt-2`}>{viewItem.status}</span>
            </div>
            <div className="space-y-2 mb-4">
              {viewItem.items.map((item, i) => (
                <div key={i} className="flex items-center justify-between py-2 border-b border-gray-50 text-sm">
                  <span>{item.productName}</span>
                  <span className="text-gray-400 text-xs">x{item.quantity} @ ৳{item.rate}</span>
                  <span className="font-bold">৳{item.totalAmount.toLocaleString()}</span>
                </div>
              ))}
            </div>
            {viewItem.notes && <p className="text-xs text-gray-500 mb-3">Note: {viewItem.notes}</p>}
            <div className="flex justify-between items-center pt-3 border-t border-gray-100">
              <span className="font-bold text-gray-700">Total</span>
              <span className="text-xl font-bold text-purple-600">৳{viewItem.totalAmount.toLocaleString()}</span>
            </div>
          </>
        )}
      </Modal>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title="New Quotation"
        size="lg"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? <Loader2 size={14} className="animate-spin" /> : 'Save Quotation'}</button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div><label className="form-label">Party *</label><input value={form.partyName} onChange={e => setForm({...form, partyName: e.target.value})} className="form-input" /></div>
          <div><label className="form-label">Email</label><input value={form.partyEmail} onChange={e => setForm({...form, partyEmail: e.target.value})} className="form-input" /></div>
          <div><label className="form-label">Valid Until</label><input type="date" value={form.validUntil} onChange={e => setForm({...form, validUntil: e.target.value})} className="form-input" /></div>
          <div><label className="form-label">Notes</label><input value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="form-input" /></div>
        </div>
        <label className="form-label">Items</label>
        <div className="space-y-2 mb-3">
          {form.items.map((item, i) => (
            <div key={i} className="grid grid-cols-12 gap-2 items-center">
              <div className="col-span-5"><input value={item.productName} onChange={e => updateItem(i, 'productName', e.target.value)} placeholder="Item name" className="form-input text-xs" /></div>
              <div className="col-span-2"><input type="number" value={item.quantity} onChange={e => updateItem(i, 'quantity', Number(e.target.value))} min="1" className="form-input text-xs" placeholder="Qty" /></div>
              <div className="col-span-3"><input type="number" value={item.rate} onChange={e => updateItem(i, 'rate', Number(e.target.value))} className="form-input text-xs" placeholder="Rate" /></div>
              <div className="col-span-1 text-xs font-bold text-right">৳{(item.quantity * item.rate).toLocaleString()}</div>
              {form.items.length > 1 && <button onClick={() => removeItem(i)} className="col-span-1 text-red-400 hover:text-red-600 text-lg leading-none">×</button>}
            </div>
          ))}
          <button onClick={addItem} className="btn-ghost text-xs"><Plus size={12} />Add Item</button>
        </div>
        <div className="bg-purple-50 rounded-xl p-3 text-right mb-4">
          <span className="text-sm font-bold text-purple-700">Total: ৳{form.items.reduce((a, i) => a + i.quantity * i.rate, 0).toLocaleString()}</span>
        </div>
      </Modal>
    </div>
  );
}
