'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import {
  Truck, Plus, Search, Trash2, Edit2, ArrowRight,
  Loader2, X, ChevronDown, CalendarDays, User,
  StickyNote, Tag, Filter, ArrowLeftRight, Package,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { formatDate } from '@/lib/utils';

const BRANCHES = ['Cumilla', 'Mymensingh', 'Bogra', 'Jessore', 'Feni', 'Depot'];

interface Transfer {
  _id: string;
  productId?: string;
  productName: string;
  packSize?: string;
  fromBranch: string;
  toBranch: string;
  quantity: number;
  weightGram?: number;
  weightUnit?: 'g' | 'ml';
  pcsCount?: number;
  transferredBy?: string;
  notes?: string;
  date: string;
  time?: string;
  tags?: string[];
}

const emptyForm = () => ({
  productId: '', productName: '', packSize: '',
  fromBranch: '', toBranch: '',
  quantity: '', weightGram: '', weightUnit: 'g' as 'g' | 'ml', pcsCount: '',
  transferredBy: '', notes: '',
  date: new Date().toISOString().slice(0, 10),
  time: new Date().toTimeString().slice(0, 5),
  tags: '',
});

interface Product {
  _id: string;
  name: string;
  code: string;
  packSize?: string;
}

function packWeight(packSize: string): { value: number; unit: 'g' | 'ml' } | null {
  const match = packSize.trim().toLowerCase().match(/([\d.]+)\s*(kg|g|gm|gram|grams|l|lt|liter|litre|ml|milliliter|millilitre)/);
  if (!match) return null;
  const amount = Number(match[1]);
  const rawUnit = match[2];
  if (['kg'].includes(rawUnit)) return { value: amount * 1000, unit: 'g' };
  if (['l', 'lt', 'liter', 'litre'].includes(rawUnit)) return { value: amount * 1000, unit: 'ml' };
  if (['ml', 'milliliter', 'millilitre'].includes(rawUnit)) return { value: amount, unit: 'ml' };
  return { value: amount, unit: 'g' };
}

const TAG_COLORS: Record<string, string> = {
  transfer: 'bg-purple-100 text-purple-700',
  received: 'bg-emerald-100 text-emerald-700',
  return:   'bg-amber-100 text-amber-700',
  urgent:   'bg-red-100 text-red-700',
  bonus:    'bg-blue-100 text-blue-700',
};
function tagColor(t: string) { return TAG_COLORS[t.toLowerCase()] ?? 'bg-gray-100 text-gray-600'; }
export default function StockTransferPage() {
  const [transfers, setTransfers]   = useState<Transfer[]>([]);
  const [products, setProducts]     = useState<Product[]>([]);
  const [total, setTotal]           = useState(0);
  const [loading, setLoading]       = useState(true);
  const [saving, setSaving]         = useState(false);

  // filters
  const [search,     setSearch]     = useState('');
  const [filterFrom, setFilterFrom] = useState('');
  const [filterTo,   setFilterTo]   = useState('');

  // modal
  const [showModal, setShowModal]   = useState(false);
  const [editing,   setEditing]     = useState<Transfer | null>(null);
  const [form,      setForm]        = useState(emptyForm());
  const [liveTime,  setLiveTime]    = useState(() => new Date().toTimeString().slice(0, 5));

  // summary stats
  const totalQty  = transfers.reduce((s, t) => s + t.quantity, 0);
  const uniqueProducts = new Set(transfers.map(t => t.productName)).size;
  const productChoices = products.filter((p, index, all) => all.findIndex(x => x.name === p.name) === index);
  const packOptions = products
    .filter(p => p.name === form.productName && p.packSize)
    .filter((p, index, all) => all.findIndex(x => x.packSize === p.packSize) === index);

  useEffect(() => {
    fetch('/api/products?status=a&limit=200')
      .then(r => r.json())
      .then(d => setProducts(d.data || []))
      .catch(() => setProducts([]));
  }, []);

  useEffect(() => {
    const update = () => setLiveTime(new Date().toTimeString().slice(0, 5));
    update();
    const timer = window.setInterval(update, 1000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    const parsed = packWeight(form.packSize);
    const quantity = Number(form.quantity);
    if (!parsed || !quantity) return;
    const total = Number((parsed.value * quantity).toFixed(2));
    setForm(current => current.weightGram === String(total) && current.weightUnit === parsed.unit
      ? current
      : { ...current, weightGram: String(total), weightUnit: parsed.unit });
  }, [form.packSize, form.quantity]);

  const fetchTransfers = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ limit: '500' });
      if (search)     params.set('productName', search);
      if (filterFrom) params.set('fromBranch', filterFrom);
      if (filterTo)   params.set('toBranch', filterTo);
      const r = await fetch(`/api/stock-transfers?${params}`);
      const d = await r.json();
      setTransfers(d.data || []);
      setTotal(d.total || 0);
    } catch { toast.error('Could not load transfers'); setTransfers([]); }
    finally { setLoading(false); }
  }, [search, filterFrom, filterTo]);

  useEffect(() => { fetchTransfers(); }, [fetchTransfers]);

  const openAdd = () => {
    setEditing(null);
    setForm(emptyForm());
    setShowModal(true);
  };

  const openEdit = (t: Transfer) => {
    setEditing(t);
    setForm({
      productId:     t.productId || '',
      productName:   t.productName,
      packSize:      t.packSize || '',
      fromBranch:    t.fromBranch,
      toBranch:      t.toBranch,
      quantity:      String(t.quantity),
      weightGram:    t.weightGram != null ? String(t.weightGram) : '',
      weightUnit:    t.weightUnit || 'g',
      pcsCount:      t.pcsCount   != null ? String(t.pcsCount)   : '',
      transferredBy: t.transferredBy || '',
      notes:         t.notes || '',
      date:          t.date ? t.date.slice(0, 10) : new Date().toISOString().slice(0, 10),
      time:          t.time || '',
      tags:          (t.tags || []).join(', '),
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.productName.trim()) return toast.error('Product name required');
    if (!form.fromBranch)         return toast.error('From branch required');
    if (!form.toBranch)           return toast.error('To branch required');
    if (form.fromBranch === form.toBranch) return toast.error('From and To branch must differ');
    if (!form.quantity || Number(form.quantity) <= 0) return toast.error('Quantity must be > 0');

    setSaving(true);
    try {
      const payload = {
        productId:      form.productId || undefined,
        productName:   form.productName.trim(),
        packSize:      form.packSize.trim(),
        fromBranch:    form.fromBranch,
        toBranch:      form.toBranch,
        quantity:      Number(form.quantity),
        weightGram:    form.weightGram ? Number(form.weightGram) : undefined,
        pcsCount:      form.pcsCount   ? Number(form.pcsCount)   : undefined,
        transferredBy: form.transferredBy.trim(),
        notes:         form.notes.trim(),
        date:          form.date,
         time:          liveTime || form.time,
        weightUnit:    form.weightUnit,
        tags: form.tags
          ? form.tags.split(',').map((t: string) => t.trim()).filter(Boolean)
          : [],
      };

      const url    = editing ? `/api/stock-transfers/${editing._id}` : '/api/stock-transfers';
      const method = editing ? 'PUT' : 'POST';
      const res = await fetch(url, {
        method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success(editing ? 'Transfer updated' : 'Transfer recorded');
      setShowModal(false);
      fetchTransfers();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (t: Transfer) => {
    if (!confirm(`Delete transfer of "${t.productName}" (${t.fromBranch} → ${t.toBranch})?`)) return;
    try {
      const res = await fetch(`/api/stock-transfers/${t._id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Delete failed');
      toast.success('Deleted');
      fetchTransfers();
    } catch { toast.error('Could not delete'); }
  };

  const set = (key: string) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
      setForm(f => ({ ...f, [key]: e.target.value }));

  // group by date for timeline view
  const grouped = transfers.reduce<Record<string, Transfer[]>>((acc, t) => {
     const key = formatDate(t.date);
    if (!acc[key]) acc[key] = [];
    acc[key].push(t);
    return acc;
  }, {});

  return (
    <div className="page-wrapper">
      <Topbar
        title="Stock Transfer"
        subtitle={`${total} total transfer records`}
        actions={
          <Button size="sm" onClick={openAdd}>
            <Plus size={15} /> New Transfer
          </Button>
        }
      />

      {/* Summary cards */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Records',    value: total,          color: 'blue' },
          { label: 'Total Qty Moved',  value: totalQty.toLocaleString(), color: 'emerald' },
          { label: 'Unique Products',  value: uniqueProducts, color: 'purple' },
          { label: 'Branches Active',  value: BRANCHES.length, color: 'amber' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-3xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm font-medium text-gray-700 dark:text-gray-200 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="card">
        <div className="flex flex-wrap gap-3 items-center">
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search product…"
              className="form-input pl-9 w-52"
            />
            {search && (
              <button onClick={() => setSearch('')} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500">
                <X size={13} />
              </button>
            )}
          </div>

          {/* From branch */}
          <div className="flex items-center gap-1.5">
            <Filter size={13} className="text-emerald-500" />
            <span className="text-xs text-emerald-600 font-medium whitespace-nowrap">From:</span>
            <div className="relative">
              <select value={filterFrom} onChange={e => setFilterFrom(e.target.value)}
                className="form-input w-36 text-sm py-2 pr-7 appearance-none">
                <option value="">All Branches</option>
                {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
              <ChevronDown size={12} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            </div>
            {filterFrom && <button onClick={() => setFilterFrom('')} className="text-gray-400 hover:text-red-500"><X size={12} /></button>}
          </div>

          {/* To branch */}
          <div className="flex items-center gap-1.5">
            <Filter size={13} className="text-purple-500" />
            <span className="text-xs text-purple-600 font-medium whitespace-nowrap">To:</span>
            <div className="relative">
              <select value={filterTo} onChange={e => setFilterTo(e.target.value)}
                className="form-input w-36 text-sm py-2 pr-7 appearance-none">
                <option value="">All Branches</option>
                {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
              <ChevronDown size={12} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            </div>
            {filterTo && <button onClick={() => setFilterTo('')} className="text-gray-400 hover:text-red-500"><X size={12} /></button>}
          </div>

          <span className="text-sm text-gray-400 ml-auto">{transfers.length} shown</span>
        </div>
      </div>

      {/* Transfer list */}
      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-16 gap-2 text-gray-400">
            <Loader2 className="animate-spin" size={20} /> Loading…
          </div>
        ) : transfers.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <Truck size={40} className="mx-auto mb-3 opacity-30" />
            <p className="font-medium">No transfers found</p>
            <p className="text-sm mt-1">Click "New Transfer" to record the first one</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100 dark:divide-gray-800">
            {Object.entries(grouped).map(([date, rows]) => (
              <div key={date}>
                {/* Date header */}
                <div className="px-4 py-2 bg-gray-50 dark:bg-gray-800/60 flex items-center gap-2">
                  <CalendarDays size={13} className="text-gray-400" />
                  <span className="text-xs font-semibold text-gray-500 uppercase tracking-wide">{date}</span>
                  <span className="ml-auto text-xs text-gray-400">{rows.length} record{rows.length > 1 ? 's' : ''}</span>
                </div>

                {/* Rows for this date */}
                {rows.map(t => (
                  <div key={t._id}
                    className="flex items-start gap-4 px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors group">

                    {/* Arrow icon */}
                    <div className="mt-1 w-8 h-8 rounded-full bg-blue-50 dark:bg-blue-900/30 flex items-center justify-center flex-shrink-0">
                      <ArrowLeftRight size={14} className="text-blue-500" />
                    </div>

                    {/* Main content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-semibold text-gray-900 dark:text-white text-sm">{t.productName}</span>
                        {t.packSize && <span className="text-xs text-blue-500">{t.packSize}</span>}
                      </div>

                      {/* Route */}
                      <div className="flex items-center gap-1.5 mt-1 flex-wrap">
                        <span className="text-xs font-semibold text-emerald-700 bg-emerald-50 dark:bg-emerald-900/30 px-2 py-0.5 rounded-lg">
                          {t.fromBranch}
                        </span>
                        <ArrowRight size={13} className="text-gray-400" />
                        <span className="text-xs font-semibold text-purple-700 bg-purple-50 dark:bg-purple-900/30 px-2 py-0.5 rounded-lg">
                          {t.toBranch}
                        </span>
                        <span className="text-sm font-bold text-gray-800 dark:text-white">
                          × {t.quantity.toLocaleString()}
                        </span>
                         {t.weightGram != null && (
                          <span className="text-xs bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded-full">
                             {t.weightGram} {t.weightUnit || 'g'}
                          </span>
                        )}
                        {t.pcsCount != null && (
                          <span className="text-xs bg-blue-50 text-blue-700 px-1.5 py-0.5 rounded-full">
                            {t.pcsCount} pcs
                          </span>
                        )}
                      </div>

                      {/* Meta row */}
                      <div className="flex items-center gap-3 mt-1 flex-wrap">
                        {t.time && (
                          <span className="flex items-center gap-1 text-xs text-gray-500">
                            <CalendarDays size={11} /> {t.time}
                          </span>
                        )}
                        {t.transferredBy && (
                          <span className="flex items-center gap-1 text-xs text-gray-500">
                            <User size={11} /> {t.transferredBy}
                          </span>
                        )}
                        {t.notes && (
                          <span className="flex items-center gap-1 text-xs text-gray-400">
                            <StickyNote size={11} /> {t.notes}
                          </span>
                        )}
                        {t.tags && t.tags.length > 0 && (
                          <div className="flex gap-1 flex-wrap">
                            {t.tags.map((tag, ti) => (
                              <span key={ti} className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${tagColor(tag)}`}>
                                <Tag size={7} className="inline mr-0.5" />{tag}
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                      <button onClick={() => openEdit(t)} className="icon-btn">
                        <Edit2 size={14} />
                      </button>
                      <button onClick={() => handleDelete(t)} className="icon-btn text-red-400 hover:text-red-600">
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ── Add / Edit Modal ── */}
      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={
          <span className="flex items-center gap-2">
            <Truck size={18} className="text-blue-500" />
            {editing ? 'Edit Transfer' : 'New Stock Transfer'}
          </span>
        }
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>
              {editing ? 'Update' : 'Save Transfer'}
            </Button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          {/* Product */}
          <div className="col-span-2 grid grid-cols-2 gap-4">
            <div>
              <label className="form-label">Product Name <span className="text-red-500">*</span></label>
              <select
                value={form.productName}
                onChange={e => {
                  const selected = products.find(p => p.name === e.target.value);
                  setForm(current => ({
                    ...current,
                    productId: selected?._id || '',
                    productName: e.target.value,
                    packSize: selected?.packSize || '',
                  }));
                }}
                className="form-input w-full"
              >
                <option value="">Select product</option>
                {productChoices.map(p => <option key={p.name} value={p.name}>{p.name}</option>)}
              </select>
            </div>
            <div>
              <label className="form-label">Pack Size</label>
              {packOptions.length > 0 ? (
                <select value={form.packSize} onChange={set('packSize')} className="form-input w-full">
                  <option value="">Select pack size</option>
                  {packOptions.map(p => <option key={p._id} value={p.packSize}>{p.packSize}</option>)}
                </select>
              ) : (
                <input value={form.packSize} onChange={set('packSize')}
                  className="form-input w-full" placeholder="e.g. 1L, 500ml, 1kg" />
              )}
            </div>
          </div>

          {/* Branches */}
          <div>
            <label className="form-label">From Branch <span className="text-red-500">*</span></label>
            <div className="relative">
              <select value={form.fromBranch} onChange={set('fromBranch')}
                className="form-input w-full appearance-none pr-8">
                <option value="">Select branch</option>
                {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
              <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            </div>
          </div>
          <div>
            <label className="form-label">To Branch <span className="text-red-500">*</span></label>
            <div className="relative">
              <select value={form.toBranch} onChange={set('toBranch')}
                className="form-input w-full appearance-none pr-8">
                <option value="">Select branch</option>
                {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
              <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            </div>
          </div>

          {/* Visual arrow between branches */}
          {(form.fromBranch || form.toBranch) && (
            <div className="col-span-2 flex items-center justify-center gap-3 py-1">
              <span className={`text-sm font-semibold px-3 py-1.5 rounded-xl ${form.fromBranch ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-400'}`}>
                {form.fromBranch || '—'}
              </span>
              <ArrowRight size={18} className="text-gray-400" />
              <span className={`text-sm font-semibold px-3 py-1.5 rounded-xl ${form.toBranch ? 'bg-purple-100 text-purple-700' : 'bg-gray-100 text-gray-400'}`}>
                {form.toBranch || '—'}
              </span>
            </div>
          )}

          {/* Quantities */}
          <div>
            <label className="form-label">Quantity <span className="text-red-500">*</span></label>
            <input type="number" value={form.quantity} onChange={set('quantity')}
              className="form-input w-full" placeholder="0" min="1" />
          </div>
          <div>
            <label className="form-label">Date <span className="text-red-500">*</span></label>
            <input type="date" value={form.date} onChange={set('date')}
              className="form-input w-full" />
          </div>
          <div>
            <label className="form-label">Time <span className="text-emerald-500 text-xs font-normal">(Live)</span></label>
            <div className="form-input w-full bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300 font-mono">
              {liveTime}
            </div>
          </div>
          <div>
            <label className="form-label">Total Weight / Volume</label>
            <div className="flex gap-2">
              <input type="number" value={form.weightGram} onChange={set('weightGram')}
                className="form-input w-full" placeholder="Auto from pack size" min="0" />
              <select value={form.weightUnit} onChange={set('weightUnit')} className="form-input w-24">
                <option value="g">g</option>
                <option value="ml">ml</option>
              </select>
            </div>
            <p className="text-[10px] text-gray-400 mt-1">Auto-calculated from pack size × quantity</p>
          </div>
          <div>
            <label className="form-label">Pcs Count</label>
            <input type="number" value={form.pcsCount} onChange={set('pcsCount')}
              className="form-input w-full" placeholder="0" min="0" />
          </div>

          {/* Who + notes */}
          <div>
            <label className="form-label">Transferred By</label>
            <input value={form.transferredBy} onChange={set('transferredBy')}
              className="form-input w-full" placeholder="Name / vehicle / driver" />
          </div>
          <div>
            <label className="form-label">Tags <span className="text-gray-400 text-xs font-normal">(comma separated)</span></label>
            <input value={form.tags} onChange={set('tags')}
              className="form-input w-full" placeholder="urgent, transfer, return…" />
          </div>
          <div className="col-span-2">
            <label className="form-label">Notes</label>
            <input value={form.notes} onChange={set('notes')}
              className="form-input w-full" placeholder="Optional notes about this transfer" />
          </div>
        </div>
      </Modal>
    </div>
  );
}
