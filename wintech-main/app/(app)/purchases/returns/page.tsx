'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';
import { Plus, Trash2, Search, X, Eye, RotateCcw, ChevronDown } from 'lucide-react';

interface Product { _id: string; name: string; code: string; purchaseRate: number; }
interface Supplier { _id: string; name: string; mobile?: string; code: string; }
interface ReturnItem { productId: string; productName: string; productCode: string; quantity: number; rate: number; discount: number; totalAmount: number; }
interface ReturnRecord { _id: string; returnNo: string; supplierName: string; returnDate: string; subTotal: number; reason: string; status: string; createdAt: string; }

const emptyItem = (): ReturnItem => ({ productId: '', productName: '', productCode: '', quantity: 1, rate: 0, discount: 0, totalAmount: 0 });

export default function PurchaseReturnsPage() {
  const [view, setView] = useState<'list' | 'new'>('list');
  const [records, setRecords] = useState<ReturnRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [suppSearch, setSuppSearch] = useState('');
  const [showSuppDrop, setShowSuppDrop] = useState(false);
  const [prodSearches, setProdSearches] = useState<string[]>(['']);
  const [showProdDrop, setShowProdDrop] = useState<number | null>(null);

  const [form, setForm] = useState({
    returnNo: `PR-${Date.now()}`,
    supplierId: '', supplierName: '',
    returnDate: new Date().toISOString().split('T')[0],
    reason: '', discountAmount: 0,
  });
  const [items, setItems] = useState<ReturnItem[]>([emptyItem()]);

  const fetchRecords = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch(`/api/purchase-returns?search=${encodeURIComponent(search)}&limit=100`);
      if (r.ok) { const d = await r.json(); setRecords(d.data || []); }
    } finally { setLoading(false); }
  }, [search]);

  useEffect(() => { fetchRecords(); }, [fetchRecords]);

  const fetchSuppliers = async (s: string) => {
    try {
      const r = await fetch(`/api/suppliers?search=${encodeURIComponent(s)}&limit=20`);
      if (r.ok) { const d = await r.json(); setSuppliers(d.data || []); }
    } catch { setSuppliers([]); }
  };

  const fetchProducts = async (s: string) => {
    try {
      const r = await fetch(`/api/products?search=${encodeURIComponent(s)}&limit=20`);
      if (r.ok) { const d = await r.json(); setProducts(d.data || []); }
    } catch { setProducts([]); }
  };

  useEffect(() => { fetchSuppliers(suppSearch); }, [suppSearch]);

  const calcItem = (item: ReturnItem): ReturnItem => {
    const base = item.quantity * item.rate;
    const disc = (base * item.discount) / 100;
    return { ...item, totalAmount: parseFloat((base - disc).toFixed(2)) };
  };

  const updateItem = (i: number, field: keyof ReturnItem, value: string | number) => {
    setItems(prev => { const next = [...prev]; next[i] = calcItem({ ...next[i], [field]: value }); return next; });
  };

  const selectProduct = (i: number, p: Product) => {
    setItems(prev => {
      const next = [...prev];
      next[i] = calcItem({ ...next[i], productId: p._id, productName: p.name, productCode: p.code, rate: p.purchaseRate });
      return next;
    });
    setProdSearches(prev => { const n = [...prev]; n[i] = p.name; return n; });
    setShowProdDrop(null);
    setProducts([]);
  };

  const subTotal = items.reduce((a, i) => a + i.totalAmount, 0) - form.discountAmount;

  const handleSave = async () => {
    if (!form.supplierName) return toast.error('Select a supplier');
    if (items.every(i => !i.productId)) return toast.error('Add at least one product');
    setSaving(true);
    try {
      const payload = {
        returnNo: form.returnNo,
        supplierId: form.supplierId || undefined,
        supplierName: form.supplierName,
        returnDate: form.returnDate,
        totalAmount: items.reduce((a, i) => a + i.totalAmount, 0),
        discountAmount: form.discountAmount,
        subTotal,
        reason: form.reason,
        status: 'a',
        details: items.filter(i => i.productId).map(i => ({ ...i })),
      };
      const res = await fetch('/api/purchase-returns', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) throw new Error((await res.json()).error || 'Failed');
      toast.success('Purchase return saved!');
      setView('list');
      fetchRecords();
      setForm({ returnNo: `PR-${Date.now()}`, supplierId: '', supplierName: '', returnDate: new Date().toISOString().split('T')[0], reason: '', discountAmount: 0 });
      setSuppSearch('');
      setItems([emptyItem()]);
      setProdSearches(['']);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Save failed');
    } finally { setSaving(false); }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this return?')) return;
    const res = await fetch(`/api/purchase-returns/${id}`, { method: 'DELETE' });
    if (res.ok) { toast.success('Deleted'); fetchRecords(); }
    else toast.error('Delete failed');
  };

  return (
    <div className="page-wrapper">
      <Topbar
        title="Purchase Returns"
        subtitle={view === 'list' ? `${records.length} return records` : 'Create new return'}
        actions={
          view === 'list'
            ? <button className="btn-primary" onClick={() => setView('new')}><Plus size={15} /> New Return</button>
            : <button className="btn-secondary" onClick={() => setView('list')}><X size={15} /> Cancel</button>
        }
      />

      {view === 'list' ? (
        <div className="card">
          <div className="flex gap-3 mb-4">
            <div className="relative flex-1 max-w-xs">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-8" placeholder="Search returns..." value={search} onChange={e => setSearch(e.target.value)} />
            </div>
          </div>
          {loading ? (
            <div className="text-center py-12 text-gray-400">Loading...</div>
          ) : records.length === 0 ? (
            <div className="text-center py-16">
              <RotateCcw size={36} className="mx-auto mb-3 text-gray-300" />
              <p className="text-gray-500 font-medium">No purchase returns found</p>
              <button className="btn-primary mt-4" onClick={() => setView('new')}><Plus size={14} /> Create First Return</button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-200 dark:border-gray-700 text-gray-500 text-xs">
                    <th className="text-left py-3 pr-4">Return No</th>
                    <th className="text-left py-3 pr-4">Supplier</th>
                    <th className="text-left py-3 pr-4">Date</th>
                    <th className="text-left py-3 pr-4">Reason</th>
                    <th className="text-right py-3 pr-4">Amount</th>
                    <th className="text-center py-3">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {records.map(r => (
                    <tr key={r._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                      <td className="py-3 pr-4 font-mono text-xs text-blue-600 dark:text-blue-400 font-medium">{r.returnNo}</td>
                      <td className="py-3 pr-4 font-medium">{r.supplierName}</td>
                      <td className="py-3 pr-4 text-gray-500">{formatDate(r.returnDate)}</td>
                      <td className="py-3 pr-4 text-gray-500 truncate max-w-[150px]">{r.reason || '—'}</td>
                      <td className="py-3 pr-4 text-right font-semibold">৳{Number(r.subTotal).toLocaleString()}</td>
                      <td className="py-3 text-center">
                        <button onClick={() => handleDelete(r._id)} className="text-red-400 hover:text-red-600 p-1 rounded transition-colors" title="Delete">
                          <Trash2 size={14} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
          <div className="xl:col-span-2 space-y-4">
            <div className="card">
              <h3 className="font-semibold text-sm text-gray-700 dark:text-gray-200 mb-3">Return Information</h3>
              <div className="grid grid-cols-2 gap-3">
                <div className="col-span-2 relative">
                  <label className="label">Supplier *</label>
                  <div className="relative">
                    <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input className="input pl-8" placeholder="Search supplier..." value={suppSearch}
                      onChange={e => { setSuppSearch(e.target.value); setShowSuppDrop(true); }}
                      onFocus={() => setShowSuppDrop(true)} onBlur={() => setTimeout(() => setShowSuppDrop(false), 200)} />
                  </div>
                  {showSuppDrop && suppliers.length > 0 && (
                    <div className="absolute z-30 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                      {suppliers.map(s => (
                        <button key={s._id} className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-700 flex justify-between"
                          onMouseDown={() => { setForm(f => ({ ...f, supplierId: s._id, supplierName: s.name })); setSuppSearch(s.name); setShowSuppDrop(false); }}>
                          <span className="font-medium">{s.name}</span>
                          <span className="text-gray-400 text-xs">{s.code}</span>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                <div>
                  <label className="label">Return No</label>
                  <input className="input" value={form.returnNo} onChange={e => setForm(f => ({ ...f, returnNo: e.target.value }))} />
                </div>
                <div>
                  <label className="label">Return Date</label>
                  <input type="date" className="input" value={form.returnDate} onChange={e => setForm(f => ({ ...f, returnDate: e.target.value }))} />
                </div>
                <div className="col-span-2">
                  <label className="label">Reason</label>
                  <textarea className="input" rows={2} placeholder="Reason for return..." value={form.reason} onChange={e => setForm(f => ({ ...f, reason: e.target.value }))} />
                </div>
              </div>
            </div>

            <div className="card">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-semibold text-sm text-gray-700 dark:text-gray-200">Products</h3>
                <button className="btn-primary text-xs py-1.5 px-3" onClick={() => { setItems(p => [...p, emptyItem()]); setProdSearches(p => [...p, '']); }}>
                  <Plus size={13} /> Add Row
                </button>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-xs">
                  <thead>
                    <tr className="border-b border-gray-200 dark:border-gray-700 text-gray-500">
                      <th className="text-left py-2 pr-2 w-[35%]">Product</th>
                      <th className="text-center py-2 px-1 w-[12%]">Qty</th>
                      <th className="text-center py-2 px-1 w-[15%]">Rate</th>
                      <th className="text-center py-2 px-1 w-[12%]">Disc%</th>
                      <th className="text-right py-2 px-1 w-[18%]">Total</th>
                      <th className="w-[8%]"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {items.map((item, i) => (
                      <tr key={i} className="border-b border-gray-100 dark:border-gray-800">
                        <td className="py-1.5 pr-2 relative">
                          <input className="input text-xs py-1" placeholder="Search product..." value={prodSearches[i] || ''}
                            onChange={e => { const v = e.target.value; setProdSearches(p => { const n = [...p]; n[i] = v; return n; }); fetchProducts(v); setShowProdDrop(i); }}
                            onFocus={() => { fetchProducts(prodSearches[i] || ''); setShowProdDrop(i); }}
                            onBlur={() => setTimeout(() => setShowProdDrop(null), 200)} />
                          {showProdDrop === i && products.length > 0 && (
                            <div className="absolute z-30 left-0 mt-1 w-64 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg max-h-40 overflow-y-auto">
                              {products.map(p => (
                                <button key={p._id} className="w-full text-left px-2 py-1.5 hover:bg-gray-50 dark:hover:bg-gray-700 flex justify-between" onMouseDown={() => selectProduct(i, p)}>
                                  <span className="font-medium truncate">{p.name}</span>
                                  <span className="text-gray-400 ml-2 shrink-0">৳{p.purchaseRate}</span>
                                </button>
                              ))}
                            </div>
                          )}
                        </td>
                        <td className="py-1.5 px-1"><input type="number" min="0" className="input text-xs py-1 text-center" value={item.quantity} onChange={e => updateItem(i, 'quantity', parseFloat(e.target.value) || 0)} /></td>
                        <td className="py-1.5 px-1"><input type="number" min="0" className="input text-xs py-1 text-center" value={item.rate} onChange={e => updateItem(i, 'rate', parseFloat(e.target.value) || 0)} /></td>
                        <td className="py-1.5 px-1"><input type="number" min="0" max="100" className="input text-xs py-1 text-center" value={item.discount} onChange={e => updateItem(i, 'discount', parseFloat(e.target.value) || 0)} /></td>
                        <td className="py-1.5 px-1 text-right font-medium">৳{item.totalAmount.toLocaleString()}</td>
                        <td className="py-1.5 pl-1 text-center">
                          {items.length > 1 && <button onClick={() => { setItems(p => p.filter((_, idx) => idx !== i)); setProdSearches(p => p.filter((_, idx) => idx !== i)); }} className="text-red-400 hover:text-red-600"><Trash2 size={13} /></button>}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <div className="card">
            <h3 className="font-semibold text-sm text-gray-700 dark:text-gray-200 mb-4">Return Summary</h3>
            <div className="space-y-3 text-sm">
              <div className="flex justify-between text-gray-500"><span>Items Total</span><span className="font-medium text-gray-700 dark:text-gray-200">৳{items.reduce((a, i) => a + i.totalAmount, 0).toLocaleString()}</span></div>
              <div className="border-t border-gray-200 dark:border-gray-700 pt-3">
                <label className="label">Extra Discount (৳)</label>
                <input type="number" min="0" className="input" value={form.discountAmount} onChange={e => setForm(f => ({ ...f, discountAmount: parseFloat(e.target.value) || 0 }))} />
              </div>
              <div className="flex justify-between font-bold text-base text-gray-800 dark:text-white pt-1">
                <span>Net Return</span><span>৳{subTotal.toLocaleString()}</span>
              </div>
            </div>
            <button onClick={handleSave} disabled={saving} className="btn-primary w-full mt-5 justify-center py-3">
              {saving ? 'Saving...' : <><RotateCcw size={15} /> Save Return</>}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
