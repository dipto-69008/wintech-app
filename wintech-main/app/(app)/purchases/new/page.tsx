'use client';
import { useState, useCallback, useRef } from 'react';
import Topbar from '@/components/layout/Topbar';
import toast from 'react-hot-toast';
import {
  Plus, Trash2, Save, Search, User, RefreshCw,
  X, Loader2, CheckCircle2, Package,
} from 'lucide-react';
import { useRouter } from 'next/navigation';

interface Supplier { _id: string; name: string; mobile?: string; code: string; previousDue?: number; }
interface Product  { _id: string; name: string; code: string; purchaseRate: number; sellingPrice: number; unit?: string; }
interface LineItem  {
  productId: string; productName: string; productCode: string;
  quantity: number; rate: number; discount: number; tax: number; totalAmount: number; unit: string;
}

const emptyLine = (): LineItem => ({
  productId: '', productName: '', productCode: '',
  quantity: 1, rate: 0, discount: 0, tax: 0, totalAmount: 0, unit: 'PCS',
});

export default function PurchaseOrderEntryPage() {
  const router = useRouter();
  const [suppliers, setSuppliers]           = useState<Supplier[]>([]);
  const [prodResults, setProdResults]       = useState<Product[]>([]);
  const [loadingProds, setLoadingProds]     = useState(false);
  const [supplierSearch, setSupplierSearch] = useState('');
  const [prodSearches, setProdSearches]     = useState<string[]>(['']);
  const [showSupDrop, setShowSupDrop]       = useState(false);
  const [activeProdRow, setActiveProdRow]   = useState<number | null>(null);
  const [saving, setSaving]                 = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const [form, setForm] = useState({
    supplierName: '', supplierId: '', supplierCode: '', previousDue: 0,
    invoiceNo: `PO-${Date.now().toString().slice(-8)}`,
    orderDate: new Date().toISOString().split('T')[0],
    purchaseFor: 'Cumilla Depot',
    paymentType: 'Cash', description: '',
    discountAmount: 0, paidAmount: 0, freight: 0,
  });
  const [lines, setLines] = useState<LineItem[]>([emptyLine()]);

  /* ── Supplier search ── */
  const fetchSuppliers = useCallback(async (s: string) => {
    try {
      const r = await fetch(`/api/suppliers?search=${encodeURIComponent(s)}&limit=15`);
      if (r.ok) { const d = await r.json(); setSuppliers(d.data || []); }
    } catch { setSuppliers([]); }
  }, []);

  const handleSupplierInput = (v: string) => {
    setSupplierSearch(v);
    setShowSupDrop(true);
    fetchSuppliers(v);
  };

  /* ── Product search ── */
  const searchProducts = useCallback((term: string) => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    setLoadingProds(true);
    debounceRef.current = setTimeout(async () => {
      try {
        const r = await fetch(`/api/products?search=${encodeURIComponent(term)}&limit=30`);
        if (r.ok) { const d = await r.json(); setProdResults(d.data || []); }
      } catch { setProdResults([]); }
      finally { setLoadingProds(false); }
    }, 250);
  }, []);

  /* ── Line helpers ── */
  const calcLine = (l: LineItem): LineItem => {
    const base = l.quantity * l.rate;
    const disc = (base * l.discount) / 100;
    return { ...l, totalAmount: parseFloat((base - disc + ((base - disc) * l.tax) / 100).toFixed(2)) };
  };
  const updateLine = (i: number, field: keyof LineItem, value: string | number) =>
    setLines(prev => { const n = [...prev]; n[i] = calcLine({ ...n[i], [field]: value }); return n; });

  const selectProduct = (i: number, p: Product) => {
    setLines(prev => {
      const n = [...prev];
      n[i] = calcLine({ ...n[i], productId: p._id, productName: p.name, productCode: p.code, rate: p.purchaseRate || 0, unit: p.unit || 'PCS' });
      return n;
    });
    setProdSearches(prev => { const n = [...prev]; n[i] = p.name; return n; });
    setActiveProdRow(null); setProdResults([]);
  };
  const clearLine = (i: number) => {
    setLines(prev => { const n = [...prev]; n[i] = emptyLine(); return n; });
    setProdSearches(prev => { const n = [...prev]; n[i] = ''; return n; });
  };
  const addRow    = () => { setLines(p => [...p, emptyLine()]); setProdSearches(p => [...p, '']); };
  const removeRow = (i: number) => { setLines(p => p.filter((_,idx)=>idx!==i)); setProdSearches(p=>p.filter((_,idx)=>idx!==i)); };

  const selectSupplier = (s: Supplier) => {
    setForm(f => ({ ...f, supplierId: s._id, supplierName: s.name, supplierCode: s.code, previousDue: s.previousDue || 0 }));
    setSupplierSearch(s.name); setShowSupDrop(false);
  };

  /* ── Totals ── */
  const totalBeforeDisc = lines.reduce((a,l)=>a+l.quantity*l.rate,0);
  const lineDiscount    = lines.reduce((a,l)=>a+(l.quantity*l.rate*l.discount)/100,0);
  const totalTax        = lines.reduce((a,l)=>{
    const b=l.quantity*l.rate-(l.quantity*l.rate*l.discount)/100; return a+(b*l.tax)/100;
  },0);
  const subTotal  = parseFloat((totalBeforeDisc-lineDiscount-form.discountAmount+totalTax+form.freight).toFixed(2));
  const dueAmount = parseFloat((subTotal-form.paidAmount).toFixed(2));
  const validLines = lines.filter(l=>l.productId);

  const handleReset = () => {
    setForm(f=>({ ...f, invoiceNo:`PO-${Date.now().toString().slice(-8)}`, supplierName:'', supplierId:'', supplierCode:'', previousDue:0, description:'', discountAmount:0, paidAmount:0, freight:0 }));
    setSupplierSearch(''); setLines([emptyLine()]); setProdSearches(['']);
  };

  const handleSave = async () => {
    if (!form.supplierName) return toast.error('Please select a supplier');
    if (validLines.length === 0) return toast.error('Add at least one product');
    setSaving(true);
    try {
      const res = await fetch('/api/purchases', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          invoiceNo: form.invoiceNo, supplierId: form.supplierId || undefined,
          supplierName: form.supplierName, orderDate: form.orderDate,
          purchaseFor: form.purchaseFor, paymentType: form.paymentType,
          description: form.description, totalAmount: totalBeforeDisc,
          discountAmount: lineDiscount + form.discountAmount,
          tax: totalTax, freight: form.freight, subTotal,
          paidAmount: form.paidAmount, dueAmount, previousDue: form.previousDue,
          status: 'a',
          details: validLines.map(l => ({
            productId: l.productId, productName: l.productName,
            quantity: l.quantity, rate: l.rate, discount: l.discount,
            tax: l.tax, totalAmount: l.totalAmount, status: 'a',
          })),
        }),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Failed'); }
      toast.success('Purchase order saved!');
      setTimeout(() => router.push('/purchases'), 1500);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Save failed');
    } finally { setSaving(false); }
  };

  const PAYMENT_TYPES = ['Cash','Bank Transfer','Cheque','Mobile Banking','Credit'];

  return (
    <div className="page-wrapper">
      <Topbar
        title="New Purchase Order"
        subtitle="Enter supplier invoice details"
        actions={
          <button onClick={handleReset} className="btn-secondary text-xs py-2 px-3 gap-1.5">
            <RefreshCw size={13}/> Reset
          </button>
        }
      />

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-5">
        {/* ── Left: Form ── */}
        <div className="space-y-4">
          {/* Header fields */}
          <div className="card grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Supplier */}
            <div className="md:col-span-2">
              <label className="label">Supplier *</label>
              <div className="relative">
                <User size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"/>
                <input
                  className="form-input pl-9 w-full"
                  placeholder="Search supplier…"
                  value={supplierSearch}
                  onChange={e => handleSupplierInput(e.target.value)}
                  onFocus={() => { setShowSupDrop(true); fetchSuppliers(supplierSearch); }}
                  onBlur={() => setTimeout(() => setShowSupDrop(false), 200)}
                />
                {showSupDrop && suppliers.length > 0 && (
                  <div className="absolute left-0 top-full mt-1 z-50 w-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-xl shadow-2xl overflow-hidden">
                    <div className="max-h-48 overflow-y-auto">
                      {suppliers.map(s => (
                        <button key={s._id} onMouseDown={() => selectSupplier(s)}
                          className="w-full text-left px-4 py-2.5 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 flex items-center justify-between border-b border-gray-50 dark:border-gray-700/40 last:border-0 text-sm">
                          <span className="font-medium text-gray-900 dark:text-white">{s.name}</span>
                          <span className="text-xs text-gray-400 font-mono">{s.code}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>

            <div>
              <label className="label">Invoice No</label>
              <input className="form-input w-full font-mono" value={form.invoiceNo}
                onChange={e=>setForm(f=>({...f,invoiceNo:e.target.value}))}/>
            </div>
            <div>
              <label className="label">Order Date</label>
              <input type="date" className="form-input w-full" value={form.orderDate}
                onChange={e=>setForm(f=>({...f,orderDate:e.target.value}))}/>
            </div>
            <div>
              <label className="label">Purchase For</label>
              <input className="form-input w-full" value={form.purchaseFor}
                onChange={e=>setForm(f=>({...f,purchaseFor:e.target.value}))}
                placeholder="e.g. Cumilla Depot"/>
            </div>
            <div>
              <label className="label">Payment Type</label>
              <select className="form-input w-full" value={form.paymentType}
                onChange={e=>setForm(f=>({...f,paymentType:e.target.value}))}>
                {PAYMENT_TYPES.map(t=><option key={t}>{t}</option>)}
              </select>
            </div>
          </div>

          {/* Products table */}
          <div className="card overflow-hidden p-0">
            <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-semibold text-gray-700 dark:text-gray-200">
                <Package size={15}/> Products
              </div>
              <button onClick={addRow} className="btn-primary text-xs py-1.5 px-3 gap-1">
                <Plus size={12}/> Add Row
              </button>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-xs">
                <thead>
                  <tr className="bg-gray-50 dark:bg-gray-800 text-gray-500">
                    <th className="text-left py-2.5 px-4 w-[35%] font-medium">Product</th>
                    <th className="text-center py-2.5 px-2 w-16 font-medium">Qty</th>
                    <th className="text-center py-2.5 px-2 w-24 font-medium">Rate (৳)</th>
                    <th className="text-center py-2.5 px-2 w-16 font-medium">Comm%</th>
                    <th className="text-right py-2.5 px-4 w-24 font-medium">Total</th>
                    <th className="w-8"/>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line, i) => (
                    <tr key={i} className="border-t border-gray-100 dark:border-gray-800">
                      <td className="px-4 py-2 relative">
                        <div className="relative">
                          <Search size={11} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"/>
                          <input
                            className="form-input pl-7 py-1.5 text-xs w-full pr-7"
                            placeholder="Search product…"
                            value={prodSearches[i]}
                            onChange={e => { const v=[...prodSearches]; v[i]=e.target.value; setProdSearches(v); searchProducts(e.target.value); setActiveProdRow(i); }}
                            onFocus={() => { setActiveProdRow(i); searchProducts(prodSearches[i]||''); }}
                            onBlur={() => setTimeout(() => { setActiveProdRow(null); setProdResults([]); }, 220)}
                          />
                          {line.productId
                            ? <CheckCircle2 size={11} className="absolute right-2 top-1/2 -translate-y-1/2 text-emerald-500 pointer-events-none"/>
                            : prodSearches[i] && (
                              <button className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-300 hover:text-red-400"
                                onMouseDown={e=>{e.preventDefault();clearLine(i);}}>
                                <X size={10}/>
                              </button>
                            )}
                        </div>
                        {activeProdRow === i && (
                          <div className="absolute left-4 top-full mt-1 z-[999] w-72 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-xl shadow-2xl overflow-hidden">
                            {loadingProds ? (
                              <div className="flex items-center gap-2 px-4 py-3 text-xs text-gray-400"><Loader2 size={12} className="animate-spin"/> Searching…</div>
                            ) : prodResults.length === 0 ? (
                              <div className="px-4 py-3 text-xs text-gray-400">{(prodSearches[i]||'').length>0 ? 'No products found' : 'Type to search products…'}</div>
                            ) : (
                              <div className="max-h-48 overflow-y-auto">
                                {prodResults.map(p => (
                                  <button key={p._id} onMouseDown={()=>selectProduct(i,p)}
                                    className="w-full text-left px-3 py-2 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 flex items-center justify-between border-b border-gray-50 dark:border-gray-700/40 last:border-0">
                                    <div>
                                      <p className="text-xs font-semibold text-gray-800 dark:text-white">{p.name}</p>
                                      <p className="text-[10px] text-gray-400 font-mono">{p.code}{p.unit?` · ${p.unit}`:''}</p>
                                    </div>
                                    <p className="text-xs font-bold text-emerald-600">৳{p.purchaseRate}</p>
                                  </button>
                                ))}
                              </div>
                            )}
                          </div>
                        )}
                      </td>
                      <td className="px-2 py-2">
                        <input type="number" min="1" className="form-input py-1.5 text-xs text-center w-full"
                          value={line.quantity} onChange={e=>updateLine(i,'quantity',parseFloat(e.target.value)||0)}/>
                      </td>
                      <td className="px-2 py-2">
                        <input type="number" min="0" className="form-input py-1.5 text-xs text-center w-full"
                          value={line.rate} onChange={e=>updateLine(i,'rate',parseFloat(e.target.value)||0)}/>
                      </td>
                      <td className="px-2 py-2">
                        <input type="number" min="0" max="100" className="form-input py-1.5 text-xs text-center w-full"
                          value={line.discount} onChange={e=>updateLine(i,'discount',parseFloat(e.target.value)||0)}/>
                      </td>
                      <td className="px-4 py-2 text-right font-semibold text-gray-900 dark:text-white tabular-nums">
                        {line.totalAmount > 0 ? `৳${line.totalAmount.toLocaleString()}` : '—'}
                      </td>
                      <td className="pr-2">
                        {lines.length > 1 && (
                          <button onClick={()=>removeRow(i)} className="text-gray-300 hover:text-red-500 transition-colors p-1">
                            <Trash2 size={13}/>
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="px-4 py-3 border-t border-gray-100 dark:border-gray-700">
              <button onClick={addRow} className="text-xs text-emerald-600 hover:text-emerald-700 font-medium flex items-center gap-1">
                <Plus size={12}/> Add another item
              </button>
            </div>
          </div>

          {/* Notes */}
          <div className="card">
            <label className="label">Notes / Description</label>
            <textarea rows={2} className="form-input w-full resize-none" placeholder="Optional notes…"
              value={form.description} onChange={e=>setForm(f=>({...f,description:e.target.value}))}/>
          </div>
        </div>

        {/* ── Right: Summary ── */}
        <div className="space-y-3">
          <div className="card sticky top-4 space-y-3">
            <h3 className="font-semibold text-gray-800 dark:text-white text-sm">Order Summary</h3>

            <div className="space-y-2 text-sm">
              {[
                { label: 'Sub Total', value: `৳${totalBeforeDisc.toLocaleString()}` },
                { label: 'Commission', value: `-৳${lineDiscount.toLocaleString()}`, color: 'text-amber-600' },
              ].map(r=>(
                <div key={r.label} className="flex justify-between text-gray-600 dark:text-gray-300">
                  <span>{r.label}</span>
                  <span className={`tabular-nums font-medium ${r.color||''}`}>{r.value}</span>
                </div>
              ))}
            </div>

            <div className="grid grid-cols-2 gap-2 pt-2 border-t border-gray-100 dark:border-gray-700">
              <div>
                <label className="label text-[10px]">Extra Commission (৳)</label>
                <input type="number" min="0" className="form-input text-sm py-1.5 w-full"
                  value={form.discountAmount} onChange={e=>setForm(f=>({...f,discountAmount:parseFloat(e.target.value)||0}))}/>
              </div>
              <div>
                <label className="label text-[10px]">Freight (৳)</label>
                <input type="number" min="0" className="form-input text-sm py-1.5 w-full"
                  value={form.freight} onChange={e=>setForm(f=>({...f,freight:parseFloat(e.target.value)||0}))}/>
              </div>
            </div>

            <div className="bg-gradient-to-r from-emerald-500/10 to-teal-500/10 dark:from-emerald-900/30 dark:to-teal-900/30 rounded-xl p-3">
              <div className="flex justify-between font-black text-xl text-gray-900 dark:text-white tabular-nums">
                <span>Grand Total</span><span>৳{subTotal.toLocaleString()}</span>
              </div>
              {form.previousDue > 0 && (
                <div className="flex justify-between text-red-500 text-xs font-semibold mt-1">
                  <span>+ Prev Due</span><span>৳{form.previousDue.toLocaleString()}</span>
                </div>
              )}
            </div>

            <div className="bg-gray-50 dark:bg-gray-800/60 rounded-xl p-3">
              <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Paid Amount (৳)</label>
              <input type="number" min="0" className="form-input text-sm py-1.5 w-full"
                value={form.paidAmount} onChange={e=>setForm(f=>({...f,paidAmount:parseFloat(e.target.value)||0}))}/>
            </div>

            <div className={`flex justify-between font-bold text-base rounded-xl p-3
              ${dueAmount > 0 ? 'bg-red-50 dark:bg-red-900/20 text-red-600'
              : dueAmount < 0 ? 'bg-amber-50 dark:bg-amber-900/20 text-amber-600'
              : 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600'}`}>
              <span>{dueAmount < 0 ? 'Change' : dueAmount === 0 ? 'Fully Paid' : 'Due Amount'}</span>
              <span className="tabular-nums">৳{Math.abs(dueAmount).toLocaleString()}</span>
            </div>

            <button onClick={handleSave} disabled={saving}
              className="w-full mt-2 py-3 rounded-2xl font-bold text-sm flex items-center justify-center gap-2 bg-gradient-to-r from-emerald-600 to-teal-600 text-white hover:opacity-90 shadow-lg shadow-emerald-500/25 disabled:opacity-60 transition-all">
              {saving ? <><Loader2 size={15} className="animate-spin"/>Saving…</>
                       : <><Save size={15}/>Save Purchase Order</>}
            </button>

            <div className="grid grid-cols-2 gap-2 text-center text-[10px] text-gray-400">
              <div className="bg-gray-50 dark:bg-gray-800 rounded-xl py-2">
                <p className="font-bold text-gray-700 dark:text-gray-200 text-sm">{validLines.length}</p>
                <p>Items</p>
              </div>
              <div className="bg-gray-50 dark:bg-gray-800 rounded-xl py-2">
                <p className="font-bold text-gray-700 dark:text-gray-200 text-sm">{validLines.reduce((a,l)=>a+l.quantity,0)}</p>
                <p>Total Qty</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
