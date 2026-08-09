'use client';
import { useState, useEffect, useCallback, useRef } from 'react';
import Topbar from '@/components/layout/Topbar';
import toast from 'react-hot-toast';
import { useAuthStore } from '@/lib/store';
import {
  Plus, Trash2, Save, Search, User, FileText,
  CreditCard, Calendar, Package, CheckCircle2, AlertCircle,
  Hash, ShoppingBag, RefreshCw, Percent, Loader2, X, Lock
} from 'lucide-react';

interface Product { _id: string; name: string; code: string; sellingPrice: number; purchaseRate: number; unit?: string; packSize?: string; stock?: number; bonusTriggerQty?: number; bonusFreeQty?: number; }
interface Party { _id: string; name: string; mobile?: string; code: string; previousDue?: number; creditLimit?: number; }
interface Branch { _id: string; name: string; legacyId?: number; status: string; }
interface CreditStatus { creditLimit: number; currentDue: number; usagePct: number; blocked: boolean; warning: boolean; }
interface PackSizeOption { packSize: string; productId: string; rate: number; code: string; }
interface LineItem { productId: string; productName: string; productCode: string; quantity: number; rate: number; totalAmount: number; packSize: string; packSizeOptions: PackSizeOption[]; hasNoTP?: boolean; isBonus: boolean; bonusTriggerQty: number; bonusFreeQty: number; }

const emptyLine = (): LineItem => ({ productId: '', productName: '', productCode: '', quantity: 1, rate: 0, totalAmount: 0, packSize: '', packSizeOptions: [], hasNoTP: false, isBonus: false, bonusTriggerQty: 0, bonusFreeQty: 0 });
const PAYMENT_TYPES = ['Cash', 'Bank Transfer', 'Cheque', 'Mobile Banking', 'Credit'];
const CASH_COMMISSION_OPTIONS = [1, 2, 3, 4, 5];

export default function OrdersEntryPage() {
  const currentUser = useAuthStore(s => s.user);
  const isEmployee = currentUser?.role === 'employee';
  const isAdmin = currentUser?.role === 'admin';
  const [parties, setParties] = useState<Party[]>([]);
  const [prodResults, setProdResults] = useState<Product[]>([]);
  const [loadingProds, setLoadingProds] = useState(false);
  const [custSearch, setCustSearch] = useState('');
  const [prodSearches, setProdSearches] = useState<string[]>(['']);
  const [showCustDrop, setShowCustDrop] = useState(false);
  const [activeProdRow, setActiveProdRow] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [creditStatus, setCreditStatus] = useState<CreditStatus | null>(null);
  const [branches, setBranches] = useState<Branch[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const prodInputRefs = useRef<(HTMLInputElement | null)[]>([]);

  const [form, setForm] = useState({
    partyName: '', partyId: '', partyCode: '', previousDue: 0,
    branchId: '',
    invoiceNo: `INV-${Date.now().toString().slice(-8)}`,
    saleDate: new Date().toISOString().split('T')[0],
    paymentType: 'Cash', description: '',
    cashCommissionPct: 3,   // default 3% for Cash
    paidAmount: 0,
    probablePaymentDate: '',
  });
  const [lines, setLines] = useState<LineItem[]>([emptyLine()]);

  const isCash = form.paymentType === 'Cash';

  /* ── Party search ── */
  const fetchParties = useCallback(async (s: string) => {
    try { const r = await fetch(`/api/parties?search=${encodeURIComponent(s)}&limit=15`); if (r.ok) { const d = await r.json(); setParties(d.data || []); } } catch { setParties([]); }
  }, []);
  useEffect(() => { fetchParties(custSearch); }, [custSearch, fetchParties]);

  useEffect(() => {
    fetch('/api/branches')
      .then(r => r.json())
      .then(d => setBranches(d.data || []))
      .catch(() => setBranches([]));
  }, []);

  /* ── Product search (debounced) ── */
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
  const calcLine = (l: LineItem): LineItem => ({
    ...l,
    totalAmount: parseFloat((l.quantity * l.rate).toFixed(2)),
  });

  const updateLine = (i: number, field: keyof LineItem, value: string | number) =>
    setLines(prev => { const n = [...prev]; n[i] = calcLine({ ...n[i], [field]: value }); return n; });

  const selectProduct = async (i: number, p: Product) => {
    const tpPrice = p.sellingPrice;
    const hasNoTP = tpPrice <= 0;
    if (hasNoTP) {
      toast.error(`No TP Price set for "${p.name}". Contact admin to update the price list.`);
    }

    // Fetch all pack-size variants for this product base name
    let packSizeOptions: PackSizeOption[] = [];
    try {
      const r = await fetch(`/api/products?search=${encodeURIComponent(p.name)}&limit=50`);
      if (r.ok) {
        const d = await r.json();
        const variants = (d.data || []).filter((pr: Product) => pr.name === p.name && pr.packSize);
        packSizeOptions = variants.map((pr: Product) => ({
          packSize: pr.packSize || '',
          productId: pr._id,
          rate: pr.sellingPrice,
          code: pr.code,
        }));
      }
    } catch { /* ignore */ }

    // Fallback: at least include the selected product itself
    if (packSizeOptions.length === 0 && p.packSize) {
      packSizeOptions = [{ packSize: p.packSize, productId: p._id, rate: p.sellingPrice, code: p.code }];
    }

    setLines(prev => {
      const n = [...prev];
      n[i] = calcLine({ ...n[i], productId: p._id, productName: p.name, productCode: p.code, rate: tpPrice, packSize: p.packSize || '', packSizeOptions, hasNoTP, bonusTriggerQty: p.bonusTriggerQty || 0, bonusFreeQty: p.bonusFreeQty || 0 });
      // Auto-add a new empty row if this is the last row
      if (i === n.length - 1) n.push(emptyLine());
      return n;
    });
    setProdSearches(prev => {
      const n = [...prev];
      n[i] = p.name; // show only base name
      if (i === n.length - 1) n.push('');
      return n;
    });
    setActiveProdRow(null);
    setProdResults([]);
  };

  const selectPackSize = (i: number, packSize: string) => {
    const opt = lines[i].packSizeOptions.find(o => o.packSize === packSize);
    if (!opt) return;
    const hasNoTP = opt.rate <= 0;
    if (hasNoTP) toast.error('No TP Price set for this pack size. Contact admin.');
    setLines(prev => {
      const n = [...prev];
      n[i] = calcLine({ ...n[i], productId: opt.productId, productCode: opt.code, rate: opt.rate, packSize, hasNoTP });
      return n;
    });
  };

  const clearLine = (i: number) => {
    setLines(prev => { const n = [...prev]; n[i] = emptyLine(); return n; });
    setProdSearches(prev => { const n = [...prev]; n[i] = ''; return n; });
    setProdResults([]);
    setActiveProdRow(null);
  };
  const addRow = () => { setLines(p => [...p, emptyLine()]); setProdSearches(p => [...p, '']); };
  const removeRow = (i: number) => { setLines(p => p.filter((_, idx) => idx !== i)); setProdSearches(p => p.filter((_, idx) => idx !== i)); };

  const selectParty = async (c: Party) => {
    setForm(f => ({ ...f, partyId: c._id, partyName: c.name, partyCode: c.code, previousDue: c.previousDue || 0 }));
    setCustSearch(c.name); setShowCustDrop(false);
    setCreditStatus(null);
    if (c._id) {
      try {
        const r = await fetch(`/api/parties/${c._id}/credit-status`);
        if (r.ok) { const d = await r.json(); setCreditStatus(d); }
      } catch { /* ignore */ }
    }
  };

  /* ── Bonus lines — only for non-Credit & no probable payment date ── */
  const bonusEligible = form.paymentType === 'Cash' && !form.probablePaymentDate;
  const bonusLines: LineItem[] = [];
  if (bonusEligible) {
    for (const line of lines) {
      if (line.productId && line.bonusTriggerQty > 0 && line.bonusFreeQty > 0 && line.quantity > 0) {
        const bonusQty = Math.floor(line.quantity / line.bonusTriggerQty) * line.bonusFreeQty;
        if (bonusQty > 0) {
          bonusLines.push({
            productId: line.productId, productName: line.productName, productCode: line.productCode,
            quantity: bonusQty, rate: 0, totalAmount: 0,
            packSize: line.packSize, packSizeOptions: [], hasNoTP: false,
            isBonus: true, bonusTriggerQty: line.bonusTriggerQty, bonusFreeQty: line.bonusFreeQty,
          });
        }
      }
    }
  }

  /* ── Totals ── */
  const validLines = lines.filter(l => l.productId);
  const subTotal = parseFloat(validLines.reduce((a, l) => a + l.totalAmount, 0).toFixed(2));
  // Commission only applies: admin role + Cash payment + paid in full
  const isFullCashPayment = isAdmin && isCash && subTotal > 0 && form.paidAmount >= subTotal;
  const commissionAmount = isFullCashPayment ? parseFloat((subTotal * form.cashCommissionPct / 100).toFixed(2)) : 0;
  const grandTotal = Math.round(subTotal - commissionAmount); // ≥0.50 → round up, <0.50 → round down
  const dueAmount = Math.round(grandTotal - form.paidAmount);

  const handleReset = () => {
    setForm(f => ({
      ...f,
      invoiceNo: `INV-${Date.now().toString().slice(-8)}`,
      partyName: '', partyId: '', partyCode: '', previousDue: 0,
      description: '', cashCommissionPct: 3, paidAmount: 0,
    }));
    setCustSearch(''); setLines([emptyLine()]); setProdSearches(['']); setSaved(false);
    setForm(f => ({ ...f, probablePaymentDate: '' }));
    setCreditStatus(null);
  };

  const handleSave = async () => {
    if (!form.partyName) return toast.error('Please select a party');
    if (!form.branchId) return toast.error('Please select the branch for this sale');
    if (validLines.length === 0) return toast.error('Add at least one product');
    const missingTP = validLines.filter(l => l.hasNoTP || l.rate <= 0);
    if (missingTP.length > 0) return toast.error(`${missingTP.length} product(s) have no TP Price. Remove them or ask admin to update the price list.`);
    setSaving(true);
    try {
      const res = await fetch('/api/sales', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          invoiceNo: form.invoiceNo,
          partyId: form.partyId || undefined,
          partyName: form.partyName,
          branchId: Number(form.branchId),
          saleDate: form.saleDate,
          paymentType: form.paymentType,
          description: form.description,
          probablePaymentDate: form.probablePaymentDate || undefined,
          totalAmount: subTotal,
          discountAmount: commissionAmount,
          commissionPct: isFullCashPayment ? form.cashCommissionPct : 0,
          taxAmount: 0,
          subTotal: grandTotal,
          paidAmount: form.paidAmount,
          dueAmount,
          previousDue: form.previousDue,
          status: 'pending',
          isOrder: 'Y',
          details: [
            ...validLines.map(l => ({
              productId: l.productId,
              productName: l.productName + (l.packSize ? ` ${l.packSize}` : ''),
              quantity: l.quantity,
              rate: l.rate,
              discount: 0,
              tax: 0,
              totalAmount: l.totalAmount,
              status: 'a',
              isBonus: false,
            })),
            ...bonusLines.map(l => ({
              productId: l.productId,
              productName: l.productName + (l.packSize ? ` ${l.packSize}` : ''),
              quantity: l.quantity,
              rate: 0,
              discount: 0,
              tax: 0,
              totalAmount: 0,
              status: 'a',
              isBonus: true,
            })),
          ],
        }),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Failed'); }
      toast.success('Order saved! Awaiting admin approval.'); setSaved(true); setTimeout(handleReset, 2000);
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  return (
    <div className="page-wrapper">
      <Topbar
        title="Orders Entry"
        subtitle="Create new sale order"
        actions={<button onClick={handleReset} className="btn-secondary text-xs py-2 px-3 gap-1.5"><RefreshCw size={13} /> New Order</button>}
      />

      {/* Pending banner */}
      <div className="flex items-center gap-2 px-4 py-2.5 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/40 rounded-2xl text-amber-700 dark:text-amber-400 text-xs font-medium">
        <AlertCircle size={14} className="flex-shrink-0" />
        Orders saved here appear as <strong className="mx-1">Pending</strong> in the Sales page until an Admin approves them.
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_290px] gap-4 items-start">

        {/* ── LEFT ── */}
        <div className="space-y-4">

          {/* Order Info */}
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-7 h-7 rounded-lg bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center"><FileText size={14} className="text-blue-600" /></div>
              <h3 className="font-bold text-sm text-gray-800 dark:text-white">Order Information</h3>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">

              {/* Party */}
              <div className="md:col-span-2 relative">
                <label className="form-label flex items-center gap-1.5"><User size={11} />Party *</label>
                <div className="relative">
                  <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                  <input className="form-input pl-9" placeholder="Search by name, code, or mobile…" value={custSearch}
                    onChange={e => { setCustSearch(e.target.value); setShowCustDrop(true); }}
                    onFocus={() => setShowCustDrop(true)}
                    onBlur={() => setTimeout(() => setShowCustDrop(false), 200)} />
                  {form.partyName && (
                    <button onClick={() => { setCustSearch(''); setForm(f => ({ ...f, partyName: '', partyId: '', partyCode: '', previousDue: 0 })); }}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500"><X size={14} /></button>
                  )}
                </div>
                {showCustDrop && parties.length > 0 && (
                  <div className="absolute z-50 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-xl shadow-2xl overflow-hidden max-h-52 overflow-y-auto">
                    {parties.map(c => (
                      <button key={c._id} className="w-full text-left px-4 py-2.5 hover:bg-blue-50 dark:hover:bg-blue-900/20 flex items-center justify-between border-b border-gray-50 dark:border-gray-700/40 last:border-0" onMouseDown={() => selectParty(c)}>
                        <div><p className="text-sm font-semibold text-gray-800 dark:text-white">{c.name}</p><p className="text-xs text-gray-400">{c.code}{c.mobile ? ` · ${c.mobile}` : ''}</p></div>
                        {(c.previousDue || 0) > 0 && <span className="text-xs text-red-500 font-bold bg-red-50 dark:bg-red-900/20 px-2 py-0.5 rounded-full shrink-0">Due ৳{(c.previousDue || 0).toLocaleString()}</span>}
                      </button>
                    ))}
                  </div>
                )}
                {form.partyName && (
                  <div className="mt-2 flex items-center gap-2 px-3 py-1.5 bg-blue-50 dark:bg-blue-900/20 rounded-lg text-xs">
                    <CheckCircle2 size={11} className="text-blue-500" />
                    <span className="font-semibold text-blue-700 dark:text-blue-300">{form.partyName}</span>
                    {form.partyCode && <span className="text-blue-400">({form.partyCode})</span>}
                    {form.previousDue > 0 && <span className="ml-auto text-red-500 font-bold">Prev Due: ৳{form.previousDue.toLocaleString()}</span>}
                  </div>
                )}
              </div>

              <div>
                <label className="form-label flex items-center gap-1.5"><Hash size={11} />Invoice No</label>
                <input className="form-input font-mono" value={form.invoiceNo} onChange={e => setForm(f => ({ ...f, invoiceNo: e.target.value }))} />
              </div>
              <div>
                <label className="form-label flex items-center gap-1.5"><ShoppingBag size={11} />Sale Branch *</label>
                <select
                  className="form-input"
                  value={form.branchId}
                  onChange={e => setForm(f => ({ ...f, branchId: e.target.value }))}
                >
                  <option value="">Select branch</option>
                  {branches.map(branch => (
                    <option key={branch._id} value={branch.legacyId ?? ''} disabled={branch.legacyId == null}>
                      {branch.name}{branch.legacyId == null ? ' (legacy ID missing)' : ''}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="form-label flex items-center gap-1.5"><Calendar size={11} />Sale Date</label>
                <input type="date" className="form-input" value={form.saleDate} onChange={e => setForm(f => ({ ...f, saleDate: e.target.value }))} />
              </div>
              <div>
                <label className="form-label flex items-center gap-1.5"><CreditCard size={11} />Payment Type</label>
                <select className="form-input" value={form.paymentType}
                  onChange={e => setForm(f => ({ ...f, paymentType: e.target.value }))}>
                  {PAYMENT_TYPES.map(pt => <option key={pt}>{pt}</option>)}
                </select>
              </div>
              <div>
                <label className="form-label">Notes</label>
                <input className="form-input" placeholder="Delivery instructions, remarks…" value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
              </div>

              {/* Probable Payment Date */}
              <div className="md:col-span-2">
                <label className="form-label flex items-center gap-1.5">
                  <Calendar size={11} className="text-amber-500" />
                  Probable Payment Date
                  <span className="ml-1 text-[10px] text-gray-400 font-normal">(আনুমানিক পেমেন্ট তারিখ — reminder পাঠাবে)</span>
                </label>
                <div className="relative">
                  <input
                    type="date"
                    className="form-input border-amber-200 dark:border-amber-700/50 focus:ring-amber-400/30"
                    value={form.probablePaymentDate}
                    min={new Date().toISOString().split('T')[0]}
                    onChange={e => setForm(f => ({ ...f, probablePaymentDate: e.target.value }))}
                  />
                  {form.probablePaymentDate && (
                    <button
                      onClick={() => setForm(f => ({ ...f, probablePaymentDate: '' }))}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500"
                    >
                      <X size={13} />
                    </button>
                  )}
                </div>
                {form.probablePaymentDate && (
                  <p className="mt-1 text-[10px] text-amber-600 dark:text-amber-400 flex items-center gap-1">
                    ⏰ এই তারিখের আগের দিন ও দিনে reminder notification আসবে
                  </p>
                )}
              </div>
            </div>
          </div>

          {/* ── Products ── */}
          <div className="card p-5">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 flex items-center justify-center"><Package size={14} className="text-emerald-600" /></div>
                <h3 className="font-bold text-sm text-gray-800 dark:text-white">Products</h3>
                {validLines.length > 0 && <span className="text-xs bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 px-2 py-0.5 rounded-full font-semibold">{validLines.length} selected</span>}
              </div>
              <button className="btn-primary text-xs py-1.5 px-3" onClick={addRow}><Plus size={13} /> Add Row</button>
            </div>

            {/* Column headers */}
            <div className="grid grid-cols-[1fr_90px_72px_100px_80px_28px] gap-2 px-3 pb-1.5 border-b border-gray-100 dark:border-gray-700 text-[10px] font-semibold text-gray-400 uppercase tracking-wide">
              <span>Product</span>
              <span className="text-center">Pack Size</span>
              <span className="text-center">Qty</span>
              <span className="text-center flex items-center justify-center gap-1">
                TP Price (৳){isEmployee && <Lock size={9} className="text-gray-300" />}
              </span>
              <span className="text-right">Total</span>
              <span></span>
            </div>

            {/* Rows */}
            <div className="space-y-1.5 mt-1.5">
              {lines.map((line, i) => (
                <div key={i} className={`relative grid grid-cols-[1fr_90px_72px_100px_80px_28px] gap-2 items-center px-3 py-2 rounded-xl transition-colors ${line.productId ? 'bg-emerald-50/50 dark:bg-emerald-900/10 border border-emerald-100 dark:border-emerald-800/30' : 'hover:bg-gray-50 dark:hover:bg-gray-800/30 border border-transparent'}`}>

                  {/* Product search */}
                  <div className="relative">
                    <div className="relative">
                      <Search size={11} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-300 pointer-events-none z-10" />
                      <input
                        ref={el => { prodInputRefs.current[i] = el; }}
                        className={`w-full text-xs py-2 pl-7 pr-6 rounded-lg border bg-white dark:bg-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500/30 transition-colors ${line.productId ? 'border-emerald-300 dark:border-emerald-700 text-gray-800 dark:text-white' : 'border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300'}`}
                        placeholder="Search product…"
                        value={prodSearches[i] || ''}
                        onChange={e => {
                          const v = e.target.value;
                          setProdSearches(p => { const n = [...p]; n[i] = v; return n; });
                          setActiveProdRow(i);
                          searchProducts(v);
                          if (!v) clearLine(i);
                        }}
                        onFocus={() => {
                          setActiveProdRow(i);
                          searchProducts(prodSearches[i] || '');
                        }}
                        onBlur={() => setTimeout(() => { setActiveProdRow(null); setProdResults([]); }, 220)}
                      />
                      {line.productId
                        ? <CheckCircle2 size={11} className="absolute right-2 top-1/2 -translate-y-1/2 text-emerald-500 pointer-events-none" />
                        : prodSearches[i] && (
                          <button className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-300 hover:text-red-400 z-10"
                            onMouseDown={e => { e.preventDefault(); clearLine(i); }}>
                            <X size={10} />
                          </button>
                        )}
                    </div>

                    {/* Product dropdown */}
                    {activeProdRow === i && (
                      <div className="absolute left-0 top-full mt-1 z-[999] w-72 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-xl shadow-2xl overflow-hidden">
                        {loadingProds ? (
                          <div className="flex items-center gap-2 px-4 py-3 text-xs text-gray-400">
                            <Loader2 size={12} className="animate-spin" /> Searching…
                          </div>
                        ) : prodResults.length === 0 ? (
                          (prodSearches[i] || '').length > 0 ? (
                            <div className="px-4 py-3 text-xs text-gray-400">No products found</div>
                          ) : (
                            <div className="px-4 py-3 text-xs text-gray-400">Type to search products…</div>
                          )
                        ) : (
                          <>
                            <div className="px-3 py-1.5 bg-gray-50 dark:bg-gray-700 border-b border-gray-100 dark:border-gray-600 text-[10px] text-gray-400 font-medium">
                              {prodResults.length} result{prodResults.length !== 1 ? 's' : ''}
                            </div>
                            <div className="max-h-48 overflow-y-auto">
                              {prodResults.map(p => {
                                const price = p.sellingPrice > 0 ? p.sellingPrice : p.purchaseRate;
                                return (
                                  <button key={p._id}
                                    className="w-full text-left px-3 py-2 hover:bg-blue-50 dark:hover:bg-blue-900/20 flex items-center justify-between border-b border-gray-50 dark:border-gray-700/40 last:border-0 transition-colors"
                                    onMouseDown={() => selectProduct(i, p)}>
                                    <div className="min-w-0 flex-1 mr-2">
                                      <p className="text-xs font-semibold text-gray-800 dark:text-white truncate">{p.name}{p.packSize ? <span className="ml-1 text-blue-400 font-normal">{p.packSize}</span> : ''}</p>
                                      <p className="text-[10px] text-gray-400 font-mono">{p.code}{p.unit ? ` · ${p.unit}` : ''}{(p.stock ?? 0) > 0 ? <span className="ml-1 text-amber-500">Stock: {p.stock}</span> : ''}</p>
                                    </div>
                                    <div className="text-right shrink-0">
                                      <p className="text-xs font-bold text-blue-600 dark:text-blue-400">
                                        {price > 0 ? `৳${price.toLocaleString()}` : '—'}
                                      </p>
                                      {p.sellingPrice === 0 && p.purchaseRate > 0 && <p className="text-[9px] text-amber-500">buy rate</p>}
                                    </div>
                                  </button>
                                );
                              })}
                            </div>
                          </>
                        )}
                      </div>
                    )}
                  </div>

                  {/* Pack Size dropdown */}
                  {line.packSizeOptions.length > 0 ? (
                    <select
                      className="w-full text-xs py-2 px-1.5 rounded-lg border border-blue-200 dark:border-blue-700 bg-white dark:bg-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500/30 text-gray-800 dark:text-white"
                      value={line.packSize}
                      onChange={e => selectPackSize(i, e.target.value)}>
                      {line.packSizeOptions.map(o => (
                        <option key={o.productId} value={o.packSize}>{o.packSize}</option>
                      ))}
                    </select>
                  ) : (
                    <div className="w-full text-xs py-2 px-2 text-center rounded-lg border border-gray-100 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-400">
                      {line.packSize || '—'}
                    </div>
                  )}

                  {/* Qty */}
                  <input type="number" min="1" step="1"
                    className="w-full text-xs py-2 px-2 text-center rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500/30 text-gray-800 dark:text-white"
                    value={line.quantity} onChange={e => updateLine(i, 'quantity', parseFloat(e.target.value) || 0)} />

                  {/* TP Price — read-only for employees */}
                  <div className="relative">
                    <input type="number" min="0"
                      className={`w-full text-xs py-2 px-2 text-center rounded-lg border focus:outline-none transition-colors
                        ${line.hasNoTP && line.productId
                          ? 'border-red-400 bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400'
                          : isEmployee
                            ? 'border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 cursor-not-allowed'
                            : 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 focus:ring-2 focus:ring-blue-500/30 text-gray-800 dark:text-white'
                        }`}
                      value={line.rate}
                      readOnly={isEmployee}
                      disabled={isEmployee}
                      onChange={e => !isEmployee && updateLine(i, 'rate', parseFloat(e.target.value) || 0)}
                    />
                    {isEmployee && line.productId && (
                      <Lock size={9} className="absolute right-1.5 top-1/2 -translate-y-1/2 text-gray-300 pointer-events-none" />
                    )}
                    {line.hasNoTP && line.productId && (
                      <div className="absolute -bottom-4 left-0 right-0 text-[9px] text-red-500 text-center font-semibold whitespace-nowrap">No TP Price!</div>
                    )}
                  </div>

                  {/* Total */}
                  <div className="text-right">
                    <span className={`text-sm font-bold tabular-nums ${line.totalAmount > 0 ? 'text-gray-900 dark:text-white' : 'text-gray-300 dark:text-gray-600'}`}>
                      {line.totalAmount > 0 ? line.totalAmount.toLocaleString() : '—'}
                    </span>
                  </div>

                  {/* Delete */}
                  <div className="flex justify-center">
                    {lines.length > 1 && (
                      <button onClick={() => removeRow(i)} className="w-6 h-6 flex items-center justify-center text-gray-300 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors">
                        <Trash2 size={11} />
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {/* Bonus lines */}
            {bonusLines.length > 0 && (
              <div className="mt-3 border-t border-amber-200 dark:border-amber-700/40 pt-3 space-y-1.5">
                <p className="text-[10px] font-bold text-amber-600 uppercase tracking-wide flex items-center gap-1">🎁 Bonus Items (Free — not charged)</p>
                {bonusLines.map((bl, bi) => (
                  <div key={bi} className="grid grid-cols-[1fr_90px_72px_100px_80px_28px] gap-2 items-center px-3 py-2 rounded-xl bg-amber-50/60 dark:bg-amber-900/10 border border-amber-200 dark:border-amber-700/30">
                    <div className="flex items-center gap-2">
                      <span className="text-[9px] font-bold bg-amber-400 text-white px-1.5 py-0.5 rounded-full uppercase">BONUS</span>
                      <span className="text-xs font-medium text-amber-800 dark:text-amber-300 truncate">{bl.productName}{bl.packSize ? ` ${bl.packSize}` : ''}</span>
                    </div>
                    <div className="text-xs text-center text-amber-600 font-medium">{bl.packSize || '—'}</div>
                    <div className="text-xs text-center font-bold text-amber-700">{bl.quantity}</div>
                    <div className="text-xs text-center text-amber-500 font-semibold">FREE</div>
                    <div className="text-xs text-right text-amber-500">৳0</div>
                    <div></div>
                  </div>
                ))}
              </div>
            )}

            {/* Footer summary */}
            {validLines.length > 0 && (
              <div className="mt-3 pt-3 border-t border-gray-100 dark:border-gray-700 flex justify-between text-xs">
                <span className="text-gray-500">
                  <strong className="text-gray-700 dark:text-gray-300">{validLines.length}</strong> product{validLines.length > 1 ? 's' : ''} · <strong className="text-gray-700 dark:text-gray-300">{validLines.reduce((a, l) => a + l.quantity, 0)}</strong> qty
                  {bonusLines.length > 0 && <span className="ml-2 text-amber-600">+ {bonusLines.reduce((a, l) => a + l.quantity, 0)} bonus free</span>}
                </span>
                <span className="font-bold text-gray-800 dark:text-white tabular-nums">৳{subTotal.toLocaleString()}</span>
              </div>
            )}
          </div>
        </div>

        {/* ── RIGHT: Summary ── */}
        <div className="xl:sticky xl:top-4">
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-5">
              <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center shadow">
                <ShoppingBag size={15} className="text-white" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-gray-800 dark:text-white">Order Summary</h3>
                <p className="text-[10px] text-gray-400 font-mono">#{form.invoiceNo}</p>
              </div>
            </div>

            <div className="space-y-2.5 text-sm">

              {/* Subtotal */}
              <div className="flex justify-between text-gray-500 dark:text-gray-400">
                <span>Subtotal</span>
                <span className="font-semibold tabular-nums">৳{subTotal.toLocaleString()}</span>
              </div>

              {/* Cash Commission — Admin only, Cash payment only */}
              {isAdmin && isCash && !isFullCashPayment && subTotal > 0 && (
                <div className="text-[10px] text-gray-400 text-center italic py-1">
                  Commission applies when paid in full (Cash)
                </div>
              )}
              {isAdmin && isFullCashPayment && (
                <>
                  <div className="bg-orange-50 dark:bg-orange-900/20 rounded-xl p-3 space-y-2">
                    <label className="text-[11px] font-semibold text-orange-600 dark:text-orange-400 uppercase tracking-wide flex items-center gap-1.5">
                      <Percent size={11} /> Cash Commission (%)
                    </label>
                    {/* Dropdown + custom input side by side */}
                    <div className="flex gap-2">
                      <select
                        className="form-input text-sm py-1.5 flex-1"
                        value={CASH_COMMISSION_OPTIONS.includes(form.cashCommissionPct) ? form.cashCommissionPct : ''}
                        onChange={e => {
                          if (e.target.value !== '') setForm(f => ({ ...f, cashCommissionPct: parseInt(e.target.value) }));
                        }}>
                        <option value="">Custom</option>
                        {CASH_COMMISSION_OPTIONS.map(pct => (
                          <option key={pct} value={pct}>{pct}%</option>
                        ))}
                      </select>
                      <div className="relative w-24">
                        <input
                          type="number"
                          min="0"
                          max="100"
                          step="0.5"
                          className="form-input text-sm py-1.5 pr-6 w-full"
                          placeholder="0"
                          value={form.cashCommissionPct}
                          onChange={e => setForm(f => ({ ...f, cashCommissionPct: parseFloat(e.target.value) || 0 }))}
                        />
                        <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400 pointer-events-none">%</span>
                      </div>
                    </div>
                    {commissionAmount > 0 && (
                      <div className="flex justify-between font-semibold text-orange-700 dark:text-orange-400 text-sm pt-1 border-t border-orange-200 dark:border-orange-800/40">
                        <span>Commission saved</span>
                        <span className="tabular-nums">৳{commissionAmount.toLocaleString()}</span>
                      </div>
                    )}
                  </div>
                  {commissionAmount > 0 && (
                    <div className="flex justify-between text-red-500 text-xs">
                      <span className="flex items-center gap-1"><Percent size={10} />Commission ({form.cashCommissionPct}%)</span>
                      <span className="tabular-nums">−৳{commissionAmount.toLocaleString()}</span>
                    </div>
                  )}
                </>
              )}

              {/* Grand Total */}
              <div className="bg-gradient-to-r from-blue-500/10 to-indigo-500/10 dark:from-blue-900/30 dark:to-indigo-900/30 rounded-xl p-3">
                <div className="flex justify-between font-black text-xl text-gray-900 dark:text-white tabular-nums">
                  <span>Grand Total</span><span>৳{grandTotal.toLocaleString()}</span>
                </div>
                {form.previousDue > 0 && (
                  <div className="flex justify-between text-red-500 text-xs font-semibold mt-1">
                    <span>+ Prev Due</span><span className="tabular-nums">৳{form.previousDue.toLocaleString()}</span>
                  </div>
                )}
              </div>

              {/* Paid Amount */}
              <div className="bg-gray-50 dark:bg-gray-800/60 rounded-xl p-3">
                <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">Paid Amount (৳)</label>
                <input type="number" min="0" className="form-input text-sm py-1.5"
                  value={form.paidAmount} onChange={e => setForm(f => ({ ...f, paidAmount: parseFloat(e.target.value) || 0 }))} />
              </div>

              {/* Due Amount */}
              <div className={`flex justify-between font-bold text-base rounded-xl p-3 ${dueAmount > 0 ? 'bg-red-50 dark:bg-red-900/20 text-red-600' : dueAmount < 0 ? 'bg-amber-50 dark:bg-amber-900/20 text-amber-600' : 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600'}`}>
                <span>{dueAmount < 0 ? 'Change' : dueAmount === 0 ? 'Fully Paid' : 'Due Amount'}</span>
                <span className="tabular-nums">৳{Math.abs(dueAmount).toLocaleString()}</span>
              </div>
            </div>

            {/* Credit Limit Status */}
            {creditStatus && creditStatus.creditLimit > 0 && (
              <div className={`mt-4 rounded-xl p-3 text-xs space-y-2 ${
                creditStatus.blocked
                  ? 'bg-red-50 dark:bg-red-900/20 border border-red-300 dark:border-red-700/50'
                  : creditStatus.usagePct >= 90
                  ? 'bg-orange-50 dark:bg-orange-900/20 border border-orange-300 dark:border-orange-700/50'
                  : 'bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/40'
              }`}>
                <div className="flex items-center justify-between font-semibold">
                  <span className={creditStatus.blocked ? 'text-red-600' : creditStatus.usagePct >= 90 ? 'text-orange-600' : 'text-amber-600'}>
                    {creditStatus.blocked ? '🛑 Credit Limit Full' : creditStatus.usagePct >= 90 ? '🚨 Credit Critical' : '⚠️ Credit Warning'}
                  </span>
                  <span className={`font-bold tabular-nums ${creditStatus.blocked ? 'text-red-600' : 'text-amber-700'}`}>
                    {creditStatus.usagePct}%
                  </span>
                </div>
                {/* Progress bar */}
                <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-1.5 overflow-hidden">
                  <div
                    className={`h-1.5 rounded-full transition-all ${creditStatus.blocked ? 'bg-red-500' : creditStatus.usagePct >= 90 ? 'bg-orange-500' : 'bg-amber-400'}`}
                    style={{ width: `${Math.min(creditStatus.usagePct, 100)}%` }}
                  />
                </div>
                <div className={`flex justify-between ${creditStatus.blocked ? 'text-red-500' : 'text-amber-600 dark:text-amber-400'}`}>
                  <span>Due: ৳{creditStatus.currentDue.toLocaleString()}</span>
                  <span>Limit: ৳{creditStatus.creditLimit.toLocaleString()}</span>
                </div>
                {creditStatus.blocked && (
                  <p className="text-red-600 dark:text-red-400 font-semibold text-center">
                    New invoice blocked until dues are cleared
                  </p>
                )}
              </div>
            )}

            <button onClick={handleSave} disabled={saving || saved || !!creditStatus?.blocked}
              className={`w-full mt-5 py-3 rounded-2xl font-bold text-sm flex items-center justify-center gap-2 transition-all ${
                creditStatus?.blocked
                  ? 'bg-red-200 dark:bg-red-900/40 text-red-400 cursor-not-allowed'
                  : saved ? 'bg-emerald-500 text-white'
                  : 'bg-gradient-to-r from-blue-600 to-indigo-600 text-white hover:opacity-90 shadow-lg shadow-blue-500/25'
              } disabled:opacity-60`}>
              {saving ? <><Loader2 size={15} className="animate-spin" />Saving…</>
                : saved ? <><CheckCircle2 size={15} />Saved!</>
                : creditStatus?.blocked ? <><AlertCircle size={15} />Credit Limit Full — Blocked</>
                : <><Save size={15} />Save Order</>}
            </button>

            <div className="mt-3 grid grid-cols-2 gap-2 text-center text-[10px] text-gray-400">
              <div className="bg-gray-50 dark:bg-gray-800 rounded-xl py-2">
                <p className="font-bold text-gray-700 dark:text-gray-200 text-sm">{validLines.length}</p>
                <p>Items</p>
              </div>
              <div className="bg-gray-50 dark:bg-gray-800 rounded-xl py-2">
                <p className="font-bold text-gray-700 dark:text-gray-200 text-sm">{validLines.reduce((a, l) => a + l.quantity, 0)}</p>
                <p>Total Qty</p>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
