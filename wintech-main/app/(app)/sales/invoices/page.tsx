'use client';
import { useState, useEffect, useCallback, useRef } from 'react';
import Topbar from '@/components/layout/Topbar';
import { FileText, Search, Eye, Plus, Trash2, Edit2, Loader2, Calendar, CheckCircle2, X, Package } from 'lucide-react';
import Link from 'next/link';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { formatDate } from '@/lib/utils';

interface SaleDetail { productId: string; productName: string; quantity: number; rate: number; discount: number; tax: number; totalAmount: number; }
interface Invoice {
  _id: string; invoiceNo: string; partyName: string; partyId?: string;
  saleDate: string; paymentType: string; totalAmount: number; discountAmount: number;
  subTotal: number; paidAmount: number; dueAmount: number; previousDue: number;
  description?: string; status: string; details?: SaleDetail[];
}
interface Party { _id: string; name: string; code: string; mobile?: string; previousDue?: number; }
interface Product { _id: string; name: string; code: string; sellingPrice: number; unit?: string; packSize?: string; }

const emptyLine = (): SaleDetail => ({ productId: '', productName: '', quantity: 1, rate: 0, discount: 0, tax: 0, totalAmount: 0 });
const PAYMENT_TYPES = ['Cash', 'Bank Transfer', 'Cheque', 'Mobile Banking', 'Credit'];
const STATUS_OPTS = [{ v: 'a', l: 'Active' }, { v: 'pending', l: 'Pending' }, { v: 'd', l: 'Cancelled' }];

function calcLine(l: SaleDetail): SaleDetail {
  const base = l.quantity * l.rate;
  const disc = (base * l.discount) / 100;
  return { ...l, totalAmount: parseFloat((base - disc + ((base - disc) * l.tax) / 100).toFixed(2)) };
}

export default function InvoicesPage() {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [statusFilter, setStatusFilter] = useState('a');

  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Invoice | null>(null);
  const [viewItem, setViewItem] = useState<Invoice | null>(null);

  // form state
  const [form, setForm] = useState({ partyName: '', partyId: '', invoiceNo: '', saleDate: new Date().toISOString().split('T')[0], paymentType: 'Cash', description: '', discountAmount: 0, paidAmount: 0, previousDue: 0, status: 'a' });
  const [lines, setLines] = useState<SaleDetail[]>([emptyLine()]);
  const [custSearch, setCustSearch] = useState('');
  const [parties, setParties] = useState<Party[]>([]);
  const [showCustDrop, setShowCustDrop] = useState(false);
  const [prodSearches, setProdSearches] = useState<string[]>(['']);
  const [prodResults, setProdResults] = useState<Product[]>([]);
  const [activeProdRow, setActiveProdRow] = useState<number | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // ── fetch invoices ──
  const fetchInvoices = useCallback(async () => {
    setLoading(true);
    try {
      const p = new URLSearchParams({ limit: '200', status: statusFilter });
      if (search) p.set('search', search);
      if (fromDate) p.set('from', fromDate);
      if (toDate) p.set('to', toDate);
      const res = await fetch(`/api/sales?${p}`);
      const json = await res.json();
      setInvoices(json.data || []);
      setTotal(json.total || 0);
    } catch { toast.error('Failed to load'); }
    finally { setLoading(false); }
  }, [search, fromDate, toDate, statusFilter]);

  useEffect(() => { fetchInvoices(); }, [fetchInvoices]);

  // ── party search ──
  useEffect(() => {
    if (!custSearch) { setParties([]); return; }
    fetch(`/api/parties?search=${encodeURIComponent(custSearch)}&limit=15`).then(r => r.json()).then(d => setParties(d.data || [])).catch(() => setParties([]));
  }, [custSearch]);

  // ── product search ──
  const searchProducts = (term: string) => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      try { const r = await fetch(`/api/products?search=${encodeURIComponent(term)}&limit=20`); const d = await r.json(); setProdResults(d.data || []); } catch { setProdResults([]); }
    }, 250);
  };

  const selectParty = (p: Party) => {
    setForm(f => ({ ...f, partyId: p._id, partyName: p.name, previousDue: p.previousDue || 0 }));
    setCustSearch(p.name); setShowCustDrop(false);
  };
  const selectProduct = (i: number, p: Product) => {
    setLines(prev => { const n = [...prev]; n[i] = calcLine({ ...n[i], productId: p._id, productName: `${p.name}${p.packSize ? ' ' + p.packSize : ''}`, rate: p.sellingPrice || 0 }); return n; });
    setProdSearches(prev => { const n = [...prev]; n[i] = p.name + (p.packSize ? ' ' + p.packSize : ''); return n; });
    setActiveProdRow(null); setProdResults([]);
  };
  const updateLine = (i: number, field: keyof SaleDetail, value: string | number) =>
    setLines(prev => { const n = [...prev]; n[i] = calcLine({ ...n[i], [field]: value }); return n; });
  const addRow = () => { setLines(p => [...p, emptyLine()]); setProdSearches(p => [...p, '']); };
  const removeRow = (i: number) => { setLines(p => p.filter((_, idx) => idx !== i)); setProdSearches(p => p.filter((_, idx) => idx !== i)); };

  const subTotal = lines.reduce((a, l) => a + l.totalAmount, 0) - (form.discountAmount || 0);
  const dueAmount = subTotal - (form.paidAmount || 0);

  const openAdd = () => {
    setEditing(null);
    setForm({ partyName: '', partyId: '', invoiceNo: `INV-${Date.now().toString().slice(-6)}`, saleDate: new Date().toISOString().split('T')[0], paymentType: 'Cash', description: '', discountAmount: 0, paidAmount: 0, previousDue: 0, status: 'a' });
    setLines([emptyLine()]); setProdSearches(['']); setCustSearch('');
    setShowModal(true);
  };

  const openEdit = async (inv: Invoice) => {
    setEditing(inv);
    // fetch full details
    try {
      const r = await fetch(`/api/sales/${inv._id}`);
      const d = await r.json();
      setForm({ partyName: d.partyName || '', partyId: d.partyId || '', invoiceNo: d.invoiceNo, saleDate: d.saleDate?.split?.('T')[0] || '', paymentType: d.paymentType || 'Cash', description: d.description || '', discountAmount: d.discountAmount || 0, paidAmount: d.paidAmount || 0, previousDue: d.previousDue || 0, status: d.status || 'a' });
      const dets: SaleDetail[] = (d.details || []).map((x: SaleDetail) => ({ productId: x.productId, productName: x.productName, quantity: x.quantity, rate: x.rate, discount: x.discount || 0, tax: x.tax || 0, totalAmount: x.totalAmount }));
      setLines(dets.length ? dets : [emptyLine()]);
      setProdSearches(dets.length ? dets.map(x => x.productName) : ['']);
      setCustSearch(d.partyName || '');
    } catch { toast.error('Could not load invoice'); }
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.partyName) return toast.error('Party name required');
    const validLines = lines.filter(l => l.productId || l.productName);
    if (!validLines.length) return toast.error('Add at least one product');
    setSaving(true);
    try {
      const payload = { invoiceNo: form.invoiceNo, partyId: form.partyId || undefined, partyName: form.partyName, saleDate: form.saleDate, paymentType: form.paymentType, description: form.description, totalAmount: lines.reduce((a, l) => a + l.quantity * l.rate, 0), discountAmount: form.discountAmount || 0, taxAmount: 0, subTotal, paidAmount: form.paidAmount || 0, dueAmount, previousDue: form.previousDue || 0, status: form.status, details: validLines.map(l => ({ productId: l.productId, productName: l.productName, quantity: l.quantity, rate: l.rate, discount: l.discount || 0, tax: l.tax || 0, totalAmount: l.totalAmount, status: 'a' })) };
      const url = editing ? `/api/sales/${editing._id}` : '/api/sales';
      const res = await fetch(url, { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success(editing ? 'Invoice updated' : 'Invoice created');
      setShowModal(false); fetchInvoices();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (inv: Invoice) => {
    if (!confirm(`Delete invoice ${inv.invoiceNo}?`)) return;
    try {
      await fetch(`/api/sales/${inv._id}`, { method: 'DELETE' });
      toast.success('Invoice deleted'); fetchInvoices();
    } catch { toast.error('Delete failed'); }
  };

  const openView = async (inv: Invoice) => {
    try {
      const r = await fetch(`/api/sales/${inv._id}`);
      setViewItem(await r.json());
    } catch { setViewItem(inv); }
  };

  const fmt = (n: number) => `৳${(n || 0).toLocaleString()}`;
  const statusBadge = (s: string) => s === 'a' ? 'badge-green' : s === 'pending' ? 'badge-yellow' : 'badge-gray';
  const statusLabel = (s: string) => s === 'a' ? 'Active' : s === 'pending' ? 'Pending' : 'Cancelled';

  const totalSales = invoices.reduce((a, r) => a + (r.subTotal || 0), 0);
  const totalPaid  = invoices.reduce((a, r) => a + (r.paidAmount || 0), 0);
  const totalDue   = invoices.reduce((a, r) => a + (r.dueAmount || 0), 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Sales Invoices" subtitle={`${total} invoices`}
        actions={<button className="btn-primary text-xs py-2 px-3 gap-1.5" onClick={openAdd}><Plus size={14} /> New Invoice</button>} />

      {/* Summary */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Sales', value: fmt(totalSales), color: 'blue' },
          { label: 'Total Paid',  value: fmt(totalPaid),  color: 'emerald' },
          { label: 'Total Due',   value: fmt(totalDue),   color: 'red' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="card">
        <div className="section-header mb-4">
          <div className="flex flex-wrap gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search party / invoice…" className="form-input pl-9 w-56" />
            </div>
            <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="form-input w-36">
              <option value="">All Status</option>
              {STATUS_OPTS.map(s => <option key={s.v} value={s.v}>{s.l}</option>)}
            </select>
            <div className="flex items-center gap-1">
              <Calendar size={14} className="text-gray-400" />
              <input type="date" value={fromDate} onChange={e => setFromDate(e.target.value)} className="form-input w-36" />
              <span className="text-gray-400 text-xs">to</span>
              <input type="date" value={toDate} onChange={e => setToDate(e.target.value)} className="form-input w-36" />
              {(fromDate || toDate) && <button onClick={() => { setFromDate(''); setToDate(''); }} className="text-gray-400 hover:text-red-500"><X size={14} /></button>}
            </div>
          </div>
          <span className="text-sm text-gray-400">{invoices.length} records</span>
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full text-sm">
              <thead>
                <tr>
                  {['Invoice No', 'Party', 'Date', 'Payment', 'Amount', 'Paid', 'Due', 'Status', ''].map(h => (
                    <th key={h} className="table-header">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                {invoices.map(r => (
                  <tr key={r._id} className="table-row">
                    <td className="table-cell font-mono text-xs text-blue-600 font-semibold">{r.invoiceNo}</td>
                    <td className="table-cell font-medium text-gray-900 dark:text-white max-w-[160px] truncate">{r.partyName}</td>
                    <td className="table-cell text-xs text-gray-500">{formatDate(r.saleDate)}</td>
                    <td className="table-cell text-xs text-gray-500">{r.paymentType}</td>
                    <td className="table-cell font-bold text-gray-800 dark:text-white">{fmt(r.subTotal)}</td>
                    <td className="table-cell text-emerald-600 font-semibold">{fmt(r.paidAmount)}</td>
                    <td className="table-cell">
                      {(r.dueAmount || 0) > 0
                        ? <span className="text-red-500 font-semibold">{fmt(r.dueAmount)}</span>
                        : <span className="badge badge-green text-[10px]">Clear</span>}
                    </td>
                    <td className="table-cell"><span className={`badge ${statusBadge(r.status)}`}>{statusLabel(r.status)}</span></td>
                    <td className="table-cell">
                      <div className="flex items-center gap-1">
                        <Link href={`/sales/invoices/${r._id}`} className="p-1.5 text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg inline-flex" title="View Detail"><Eye size={13} /></Link>
                        <button onClick={() => openEdit(r)} className="p-1.5 text-gray-500 hover:bg-gray-100 rounded-lg"><Edit2 size={13} /></button>
                        <button onClick={() => handleDelete(r)} className="p-1.5 text-red-400 hover:bg-red-50 rounded-lg"><Trash2 size={13} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {invoices.length === 0 && (
              <div className="text-center py-12 text-gray-400">
                <FileText className="w-10 h-10 mx-auto mb-2 opacity-30" />
                <p>No invoices found</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Add/Edit Modal ── */}
      <Modal open={showModal} onClose={() => setShowModal(false)} title={editing ? `Edit Invoice` : 'New Invoice'} size="xl"
        footer={
          <>
            <button className="btn-secondary" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn-primary" onClick={handleSave} disabled={saving}>{saving ? <Loader2 size={14} className="animate-spin" /> : editing ? 'Update Invoice' : 'Save Invoice'}</button>
          </>
        }
      >
        <div className="space-y-5">
          {/* Party */}
          <div className="relative">
            <label className="form-label">Party *</label>
            <div className="relative">
              <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
              <input className="form-input pl-9" placeholder="Type party name…" value={custSearch}
                onChange={e => { setCustSearch(e.target.value); setForm(f => ({ ...f, partyName: e.target.value })); setShowCustDrop(true); }}
                onFocus={() => setShowCustDrop(true)} onBlur={() => setTimeout(() => setShowCustDrop(false), 200)} />
              {form.partyName && <button onClick={() => { setCustSearch(''); setForm(f => ({ ...f, partyName: '', partyId: '' })); }} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500"><X size={13} /></button>}
            </div>
            {showCustDrop && parties.length > 0 && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-xl shadow-xl max-h-48 overflow-y-auto">
                {parties.map(p => (
                  <button key={p._id} onMouseDown={() => selectParty(p)} className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm border-b last:border-0">
                    <span className="font-medium">{p.name}</span>
                    <span className="text-gray-400 ml-2 text-xs">{p.code}</span>
                    {(p.previousDue || 0) > 0 && <span className="float-right text-red-500 text-xs">Due ৳{p.previousDue?.toLocaleString()}</span>}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Invoice meta */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="form-label">Invoice No</label><input className="form-input font-mono" value={form.invoiceNo} onChange={e => setForm(f => ({ ...f, invoiceNo: e.target.value }))} /></div>
            <div><label className="form-label">Date</label><input type="date" className="form-input" value={form.saleDate} onChange={e => setForm(f => ({ ...f, saleDate: e.target.value }))} /></div>
            <div><label className="form-label">Payment</label>
              <select className="form-input" value={form.paymentType} onChange={e => setForm(f => ({ ...f, paymentType: e.target.value }))}>
                {PAYMENT_TYPES.map(p => <option key={p}>{p}</option>)}
              </select>
            </div>
            <div><label className="form-label">Status</label>
              <select className="form-input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value }))}>
                {STATUS_OPTS.map(s => <option key={s.v} value={s.v}>{s.l}</option>)}
              </select>
            </div>
          </div>

          {/* Products */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="form-label mb-0">Products</label>
              <button className="btn-ghost text-xs py-1 px-2" onClick={addRow}><Plus size={12} /> Add Row</button>
            </div>
            <div className="border border-gray-100 rounded-xl overflow-hidden">
              <table className="w-full text-xs">
                <thead className="bg-gray-50">
                  <tr>
                    {['Product', 'Qty', 'Rate', 'Comm%', 'Total', ''].map(h => <th key={h} className="py-2 px-3 text-left font-medium text-gray-500">{h}</th>)}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {lines.map((line, i) => (
                    <tr key={i}>
                      <td className="px-2 py-1.5 relative min-w-[180px]">
                        <input
                          className="form-input text-xs py-1.5"
                          placeholder="Search product…"
                          value={prodSearches[i] || ''}
                          onChange={e => { const v = e.target.value; setProdSearches(p => { const n = [...p]; n[i] = v; return n; }); setActiveProdRow(i); searchProducts(v); }}
                          onFocus={() => { setActiveProdRow(i); if (prodSearches[i]) searchProducts(prodSearches[i]); }}
                          onBlur={() => setTimeout(() => { setActiveProdRow(null); setProdResults([]); }, 200)}
                        />
                        {activeProdRow === i && prodResults.length > 0 && (
                          <div className="absolute z-50 left-2 right-2 top-full mt-0.5 bg-white border border-gray-200 rounded-xl shadow-xl max-h-48 overflow-y-auto">
                            {prodResults.map(p => (
                              <button key={p._id} onMouseDown={() => selectProduct(i, p)} className="w-full text-left px-3 py-2 hover:bg-blue-50 text-xs border-b last:border-0">
                                <div className="flex items-center gap-2"><Package size={11} className="text-gray-400 flex-shrink-0" /><span className="font-medium">{p.name}</span>{p.packSize && <span className="text-gray-400">{p.packSize}</span>}<span className="ml-auto text-emerald-600 font-bold">৳{p.sellingPrice}</span></div>
                              </button>
                            ))}
                          </div>
                        )}
                      </td>
                      <td className="px-2 py-1.5 w-16"><input type="number" className="form-input text-xs py-1.5 w-full" min="1" value={line.quantity} onChange={e => updateLine(i, 'quantity', Number(e.target.value))} /></td>
                      <td className="px-2 py-1.5 w-24"><input type="number" className="form-input text-xs py-1.5 w-full" min="0" value={line.rate} onChange={e => updateLine(i, 'rate', Number(e.target.value))} /></td>
                      <td className="px-2 py-1.5 w-16"><input type="number" className="form-input text-xs py-1.5 w-full" min="0" max="100" value={line.discount} onChange={e => updateLine(i, 'discount', Number(e.target.value))} /></td>
                      <td className="px-2 py-1.5 w-24 font-semibold text-gray-700">৳{line.totalAmount.toLocaleString()}</td>
                      <td className="px-2 py-1.5 w-8">
                        {lines.length > 1 && <button onClick={() => removeRow(i)} className="text-red-400 hover:text-red-600"><X size={13} /></button>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Totals */}
          <div className="grid grid-cols-2 gap-3">
            <div><label className="form-label">Extra Commission (৳)</label><input type="number" className="form-input" min="0" value={form.discountAmount} onChange={e => setForm(f => ({ ...f, discountAmount: parseFloat(e.target.value) || 0 }))} /></div>
            <div><label className="form-label">Paid Amount (৳)</label><input type="number" className="form-input" min="0" value={form.paidAmount} onChange={e => setForm(f => ({ ...f, paidAmount: parseFloat(e.target.value) || 0 }))} /></div>
            <div><label className="form-label">Notes</label><input className="form-input" value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} /></div>
            <div className="bg-blue-50 rounded-xl p-3 flex flex-col gap-1">
              <div className="flex justify-between text-xs text-gray-500"><span>Sub Total</span><span className="font-bold text-gray-800">৳{subTotal.toLocaleString()}</span></div>
              <div className="flex justify-between text-xs text-gray-500"><span>Paid</span><span className="text-emerald-600 font-bold">৳{(form.paidAmount || 0).toLocaleString()}</span></div>
              <div className="flex justify-between text-sm font-bold border-t border-blue-100 pt-1 mt-1"><span>Due</span><span className={dueAmount > 0 ? 'text-red-600' : 'text-emerald-600'}>৳{dueAmount.toLocaleString()}</span></div>
            </div>
          </div>
        </div>
      </Modal>

      {/* ── View Modal ── */}
      <Modal open={!!viewItem} onClose={() => setViewItem(null)} title={viewItem ? `${viewItem.invoiceNo}` : ''}>
        {viewItem && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-bold text-gray-900">{viewItem.partyName}</p>
                <p className="text-xs text-gray-400">{formatDate(viewItem.saleDate)} · {viewItem.paymentType}</p>
              </div>
              <span className={`badge ${statusBadge(viewItem.status)}`}>{statusLabel(viewItem.status)}</span>
            </div>
            {viewItem.details && viewItem.details.length > 0 && (
              <div className="border border-gray-100 rounded-xl overflow-hidden">
                <table className="w-full text-xs">
                  <thead className="bg-gray-50"><tr>{['Product', 'Qty', 'Rate', 'Amount'].map(h => <th key={h} className="py-2 px-3 text-left text-gray-500 font-medium">{h}</th>)}</tr></thead>
                  <tbody className="divide-y divide-gray-50">
                    {viewItem.details.map((d, i) => (
                      <tr key={i}>
                        <td className="px-3 py-2 font-medium">{d.productName}</td>
                        <td className="px-3 py-2 text-gray-500">{d.quantity}</td>
                        <td className="px-3 py-2 text-gray-500">৳{d.rate}</td>
                        <td className="px-3 py-2 font-bold">৳{d.totalAmount.toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="space-y-1.5 text-sm">
              {[
                { label: 'Sub Total',   value: fmt(viewItem.subTotal),     cls: 'font-bold text-gray-800' },
                { label: 'Paid',        value: fmt(viewItem.paidAmount),   cls: 'text-emerald-600 font-semibold' },
                { label: 'Due',         value: fmt(viewItem.dueAmount),    cls: (viewItem.dueAmount || 0) > 0 ? 'text-red-600 font-bold' : 'text-emerald-600' },
                { label: 'Prev. Due',   value: fmt(viewItem.previousDue),  cls: 'text-gray-500' },
              ].map(r => (
                <div key={r.label} className="flex justify-between py-1.5 border-b border-gray-50 last:border-0">
                  <span className="text-gray-500">{r.label}</span>
                  <span className={r.cls}>{r.value}</span>
                </div>
              ))}
            </div>
            {viewItem.description && <p className="text-xs text-gray-400 italic">Note: {viewItem.description}</p>}
            <div className="flex gap-2 pt-2">
              <button className="btn-secondary flex-1" onClick={() => { setViewItem(null); openEdit(viewItem); }}><Edit2 size={13} /> Edit</button>
              <button className="btn-danger flex-1" onClick={() => { setViewItem(null); handleDelete(viewItem); }}><Trash2 size={13} /> Delete</button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
