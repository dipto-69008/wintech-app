'use client';
import { useState, useEffect, useCallback, useRef } from 'react';
import Topbar from '@/components/layout/Topbar';
import {
  BarChart2, Search, Loader2, RefreshCw, MapPin, Building2,
  ArrowRight, ArrowLeftRight, Plus, X, ChevronDown, Tag,
  CalendarDays, User, StickyNote, Package, AlertTriangle, ShieldAlert,
  Edit3, Check,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { formatDate } from '@/lib/utils';

const MONTH_NAMES = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
type ReportType = 'company' | 'branch';

const BRANCHES = ['Cumilla','Mymensingh','Bogra','Jessore','Feni','Depot'];

interface StockRow {
  _id: string; productName: string; packSize: string;
  cumillaStock?: number; mymensinghStock?: number; bograStock?: number;
  jessoreStock?: number; feniStock?: number; totalQuantity?: number;
  zone?: string; previousStock?: number; receivedQty?: number; returnQty?: number;
  transferQty?: number; salesQty?: number; bonusQty?: number; presentBalance?: number;
  expiryDate?: string;
  damageQty?: number;
}

// ── expiry helpers ──────────────────────────────────────────────────────────
function monthsUntilExpiry(expiryDate?: string): number | null {
  if (!expiryDate) return null;
  const now   = new Date();
  const exp   = new Date(expiryDate);
  const diff  = (exp.getFullYear() - now.getFullYear()) * 12 + (exp.getMonth() - now.getMonth());
  return diff;
}
function expiryStatus(expiryDate?: string): 'expired' | 'critical' | 'warning' | null {
  const m = monthsUntilExpiry(expiryDate);
  if (m === null) return null;
  if (m < 0)  return 'expired';
  if (m <= 2) return 'critical';
  if (m <= 3) return 'warning';
  return null;
}
const EXPIRY_BADGE: Record<string, string> = {
  expired:  'bg-red-100 text-red-700 border border-red-300',
  critical: 'bg-red-50  text-red-600 border border-red-200',
  warning:  'bg-amber-50 text-amber-700 border border-amber-200',
};

interface Transfer {
  _id: string;
  productName: string;
  packSize?: string;
  fromBranch: string;
  toBranch: string;
  quantity: number;
  transferredBy?: string;
  notes?: string;
  date: string;
  tags?: string[];
}

interface Period { _id: { year: number; month: number }; count: number; }

const emptyTxForm = () => ({
  productName: '', packSize: '', fromBranch: '', toBranch: '',
  quantity: '', transferredBy: '', notes: '',
  date: new Date().toISOString().slice(0, 10), tags: '',
});

const TAG_COLORS: Record<string, string> = {
  transfer : 'bg-purple-100 text-purple-700',
  received : 'bg-emerald-100 text-emerald-700',
  return   : 'bg-amber-100  text-amber-700',
  urgent   : 'bg-red-100    text-red-700',
  bonus    : 'bg-blue-100   text-blue-700',
};
function tagColor(t: string) { return TAG_COLORS[t.toLowerCase()] ?? 'bg-gray-100 text-gray-600'; }

export default function StockReportsPage() {
  // ── meta ───────────────────────────────────────────────────
  const [type,       setType]       = useState<ReportType>('company');
  const [periods,    setPeriods]    = useState<Period[]>([]);
  const [zones,      setZones]      = useState<string[]>([]);
  const [selYear,    setSelYear]    = useState('');
  const [selMonth,   setSelMonth]   = useState('');
  const [selZone,    setSelZone]    = useState('');
  const [search,     setSearch]     = useState('');
  const [data,       setData]       = useState<StockRow[]>([]);
  const [loading,    setLoading]    = useState(false);
  const [importing,  setImporting]  = useState(false);

  // ── transfer filters (branch view) ─────────────────────────
  const [filterFrom, setFilterFrom] = useState('');
  const [filterTo,   setFilterTo]   = useState('');

  // ── transfers data (for tags + popup) ──────────────────────
  const [transfers,  setTransfers]  = useState<Transfer[]>([]);
  const [txLoading,  setTxLoading]  = useState(false);

  // ── inline cell editing (expiryDate / damageQty) ──────────
  const [editCell, setEditCell] = useState<{ id: string; field: 'expiryDate' | 'damageQty'; value: string } | null>(null);
  const [savingCell, setSavingCell] = useState(false);

  const startEdit = (row: StockRow, field: 'expiryDate' | 'damageQty') => {
    const value = field === 'expiryDate'
      ? (row.expiryDate ? row.expiryDate.slice(0, 10) : '')
      : String(row.damageQty ?? '');
    setEditCell({ id: row._id, field, value });
  };

  const commitEdit = async () => {
    if (!editCell) return;
    setSavingCell(true);
    try {
      const body: Record<string, unknown> = {};
      if (editCell.field === 'expiryDate') body.expiryDate = editCell.value || null;
      else body.damageQty = editCell.value !== '' ? Number(editCell.value) : 0;

      const res = await fetch(`/api/stock-reports/${editCell.id}`, {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error('Save failed');
      // update local state
      const updated = await res.json();
      setData(prev => prev.map(r => r._id === editCell.id
        ? { ...r, expiryDate: updated.expiryDate, damageQty: updated.damageQty }
        : r
      ));
      toast.success('Saved');
    } catch { toast.error('Could not save'); }
    finally { setSavingCell(false); setEditCell(null); }
  };

  // ── product detail popup ───────────────────────────────────
  const [detailProduct, setDetailProduct] = useState<StockRow | null>(null);
  const [detailTx,      setDetailTx]      = useState<Transfer[]>([]);
  const [detailTxLoad,  setDetailTxLoad]  = useState(false);
  const [showAddTx,     setShowAddTx]     = useState(false);
  const [txForm,        setTxForm]        = useState(emptyTxForm());
  const [savingTx,      setSavingTx]      = useState(false);

  // ── fetch meta ──────────────────────────────────────────────
  const fetchMeta = useCallback(async () => {
    try {
      const r = await fetch('/api/stock-reports?type=company&month=1&year=2000');
      const d = await r.json();
      setPeriods(d.periods || []);
      setZones(d.zones || []);
      if (d.periods?.length) {
        setSelYear(String(d.periods[0]._id.year));
        setSelMonth(String(d.periods[0]._id.month));
      }
    } catch { /* ignore */ }
  }, []);
  useEffect(() => { fetchMeta(); }, [fetchMeta]);

  // ── fetch stock data ─────────────────────────────────────────
  const fetchData = useCallback(async () => {
    if (!selYear || !selMonth) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ type, year: selYear, month: selMonth, search });
      if (type === 'branch' && selZone) params.set('zone', selZone);
      const r = await fetch(`/api/stock-reports?${params}`);
      const d = await r.json();
      setData(d.data || []);
    } catch { toast.error('Failed to load data'); setData([]); }
    finally { setLoading(false); }
  }, [type, selYear, selMonth, selZone, search]);
  useEffect(() => { fetchData(); }, [fetchData]);

  // ── fetch transfers (branch view only) ──────────────────────
  const fetchTransfers = useCallback(async () => {
    if (type !== 'branch') return;
    setTxLoading(true);
    try {
      const params = new URLSearchParams();
      if (filterFrom) params.set('fromBranch', filterFrom);
      if (filterTo)   params.set('toBranch', filterTo);
      const r = await fetch(`/api/stock-transfers?${params}`);
      const d = await r.json();
      setTransfers(d.data || []);
    } catch { setTransfers([]); }
    finally { setTxLoading(false); }
  }, [type, filterFrom, filterTo]);
  useEffect(() => { fetchTransfers(); }, [fetchTransfers]);

  // ── fetch detail transfers for a product ─────────────────────
  const openProductDetail = async (row: StockRow) => {
    setDetailProduct(row);
    setShowAddTx(false);
    setTxForm({ ...emptyTxForm(), productName: row.productName, packSize: row.packSize });
    setDetailTxLoad(true);
    try {
      const r = await fetch(`/api/stock-transfers?productName=${encodeURIComponent(row.productName)}&limit=200`);
      const d = await r.json();
      setDetailTx(d.data || []);
    } catch { setDetailTx([]); }
    finally { setDetailTxLoad(false); }
  };

  // ── save new transfer ──────────────────────────────────────
  const handleSaveTransfer = async () => {
    if (!txForm.productName) return toast.error('Product name required');
    if (!txForm.fromBranch)  return toast.error('From branch required');
    if (!txForm.toBranch)    return toast.error('To branch required');
    if (txForm.fromBranch === txForm.toBranch) return toast.error('From and To branch must differ');
    if (!txForm.quantity || Number(txForm.quantity) <= 0) return toast.error('Enter a valid quantity');
    setSavingTx(true);
    try {
      const payload = {
        ...txForm,
        quantity: Number(txForm.quantity),
        tags: txForm.tags ? txForm.tags.split(',').map((t: string) => t.trim()).filter(Boolean) : [],
      };
      const res = await fetch('/api/stock-transfers', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success('Transfer recorded');
      setShowAddTx(false);
      // refresh detail list
      if (detailProduct) {
        const r = await fetch(`/api/stock-transfers?productName=${encodeURIComponent(detailProduct.productName)}&limit=200`);
        const d = await r.json();
        setDetailTx(d.data || []);
      }
      fetchTransfers();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Failed'); }
    finally { setSavingTx(false); }
  };

  // ── import ────────────────────────────────────────────────────
  const handleImport = async () => {
    setImporting(true);
    try {
      const r = await fetch('/api/import-xlsx', { method: 'POST' });
      const d = await r.json();
      if (d.ok) {
        toast.success('Import complete! ' + (d.summary?.[0] || ''));
        await fetchMeta(); await fetchData();
      } else toast.error(d.error || 'Import failed');
    } catch { toast.error('Import failed'); }
    finally { setImporting(false); }
  };

  // ── helpers ───────────────────────────────────────────────────
  const uniqueYears    = [...new Set(periods.map(p => p._id.year))].sort((a,b)=>b-a);
  const monthsForYear  = periods.filter(p => p._id.year === parseInt(selYear)).map(p => p._id.month).sort((a,b)=>a-b);

  // company totals
  const totalCumilla    = data.reduce((s,r)=>s+(r.cumillaStock||0),0);
  const totalMymensingh = data.reduce((s,r)=>s+(r.mymensinghStock||0),0);
  const totalBogra      = data.reduce((s,r)=>s+(r.bograStock||0),0);
  const totalJessore    = data.reduce((s,r)=>s+(r.jessoreStock||0),0);
  const totalFeni       = data.reduce((s,r)=>s+(r.feniStock||0),0);
  const grandTotal      = data.reduce((s,r)=>s+(r.totalQuantity||0),0);

  // map productName → transfers for quick tag lookup
  const txByProduct = transfers.reduce<Record<string, Transfer[]>>((acc, t) => {
    const k = t.productName.trim().toLowerCase();
    if (!acc[k]) acc[k] = [];
    acc[k].push(t);
    return acc;
  }, {});

  // filtered rows for branch view considering filterFrom / filterTo
  const filteredData = (type === 'branch' && (filterFrom || filterTo))
    ? data.filter(row => {
        const key = row.productName.trim().toLowerCase();
        const list = txByProduct[key] || [];
        if (filterFrom && !list.some(t => t.fromBranch === filterFrom)) return false;
        if (filterTo   && !list.some(t => t.toBranch   === filterTo))   return false;
        return true;
      })
    : data;

  const fmtDate = (d: string) => formatDate(d);

  return (
    <div className="page-wrapper">
      <Topbar
        title="Stock Reports"
        subtitle="Monthly inventory snapshot from Excel data"
        actions={
          <button onClick={handleImport} disabled={importing}
            className="btn-primary gap-2 text-xs py-2 px-3">
            {importing ? <Loader2 size={13} className="animate-spin"/> : <RefreshCw size={13}/>}
            {importing ? 'Importing…' : 'Re-import Excel'}
          </button>
        }
      />

      {/* ── Filters ── */}
      <div className="card space-y-3">
        <div className="flex flex-wrap gap-3 items-center">
          {/* Type toggle */}
          <div className="flex rounded-xl overflow-hidden border border-gray-200 dark:border-gray-700">
            {(['company','branch'] as ReportType[]).map(t => (
              <button key={t} onClick={()=>{ setType(t); setFilterFrom(''); setFilterTo(''); }}
                className={`px-4 py-2 text-sm font-medium transition-colors capitalize
                  ${type===t ? 'bg-emerald-600 text-white' : 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700'}`}>
                {t === 'company'
                  ? <><Building2 size={13} className="inline mr-1"/>Company</>
                  : <><MapPin size={13} className="inline mr-1"/>Branch Zone</>}
              </button>
            ))}
          </div>

          <select value={selYear} onChange={e=>{ setSelYear(e.target.value); setSelMonth(''); }}
            className="form-input w-28 text-sm py-2">
            <option value="">Year</option>
            {uniqueYears.map(y=><option key={y} value={y}>{y}</option>)}
          </select>

          <select value={selMonth} onChange={e=>setSelMonth(e.target.value)}
            className="form-input w-32 text-sm py-2">
            <option value="">Month</option>
            {monthsForYear.map(m=><option key={m} value={m}>{MONTH_NAMES[m]}</option>)}
          </select>

          {type === 'branch' && (
            <select value={selZone} onChange={e=>setSelZone(e.target.value)}
              className="form-input w-36 text-sm py-2">
              <option value="">All Zones</option>
              {zones.map(z=><option key={z} value={z}>{z}</option>)}
            </select>
          )}

          <div className="relative flex-1 min-w-[180px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={14}/>
            <input value={search} onChange={e=>setSearch(e.target.value)}
              placeholder="Search product…" className="form-input pl-9 w-full text-sm py-2"/>
          </div>

          <span className="text-sm text-gray-400">{filteredData.length} products</span>
        </div>

        {/* Branch-specific: receive from / transfer to dropdowns */}
        {type === 'branch' && (
          <div className="flex flex-wrap gap-3 items-center pt-1 border-t border-gray-100 dark:border-gray-700">
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wide flex items-center gap-1">
              <ArrowLeftRight size={13}/> Movement Filter
            </span>

            {/* Received From */}
            <div className="flex items-center gap-1.5">
              <span className="text-xs text-emerald-600 font-medium whitespace-nowrap">Received From:</span>
              <div className="relative">
                <select value={filterFrom} onChange={e=>setFilterFrom(e.target.value)}
                  className="form-input w-36 text-xs py-1.5 pr-7 appearance-none">
                  <option value="">All Branches</option>
                  {BRANCHES.map(b=><option key={b} value={b}>{b}</option>)}
                </select>
                <ChevronDown size={12} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"/>
              </div>
              {filterFrom && <button onClick={()=>setFilterFrom('')} className="text-gray-400 hover:text-red-500"><X size={12}/></button>}
            </div>

            {/* Transfer To */}
            <div className="flex items-center gap-1.5">
              <span className="text-xs text-purple-600 font-medium whitespace-nowrap">Transfer To:</span>
              <div className="relative">
                <select value={filterTo} onChange={e=>setFilterTo(e.target.value)}
                  className="form-input w-36 text-xs py-1.5 pr-7 appearance-none">
                  <option value="">All Branches</option>
                  {BRANCHES.map(b=><option key={b} value={b}>{b}</option>)}
                </select>
                <ChevronDown size={12} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"/>
              </div>
              {filterTo && <button onClick={()=>setFilterTo('')} className="text-gray-400 hover:text-red-500"><X size={12}/></button>}
            </div>

            {txLoading && <Loader2 size={13} className="animate-spin text-gray-400"/>}
            {(filterFrom || filterTo) && (
              <span className="text-xs text-gray-400">
                {filteredData.length} of {data.length} products match
              </span>
            )}
          </div>
        )}
      </div>

      {/* ── Expiry Alarm Banner ── */}
      {(() => {
        const expired  = data.filter(r => expiryStatus(r.expiryDate) === 'expired');
        const critical = data.filter(r => expiryStatus(r.expiryDate) === 'critical');
        const warning  = data.filter(r => expiryStatus(r.expiryDate) === 'warning');
        if (!expired.length && !critical.length && !warning.length) return null;
        return (
          <div className="space-y-2">
            {expired.length > 0 && (
              <div className="flex items-start gap-3 rounded-xl border border-red-300 bg-red-50 dark:bg-red-900/20 px-4 py-3">
                <ShieldAlert size={18} className="text-red-600 mt-0.5 flex-shrink-0"/>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-red-700">⛔ {expired.length} product{expired.length>1?'s':''} EXPIRED</p>
                  <p className="text-xs text-red-600 mt-0.5 truncate">{expired.map(r=>r.productName).join(' · ')}</p>
                </div>
              </div>
            )}
            {critical.length > 0 && (
              <div className="flex items-start gap-3 rounded-xl border border-red-200 bg-red-50/70 dark:bg-red-900/10 px-4 py-3">
                <AlertTriangle size={18} className="text-red-500 mt-0.5 flex-shrink-0"/>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-red-600">🔴 {critical.length} product{critical.length>1?'s':''} expiring within 2 months</p>
                  <p className="text-xs text-red-500 mt-0.5 truncate">{critical.map(r=>r.productName).join(' · ')}</p>
                </div>
              </div>
            )}
            {warning.length > 0 && (
              <div className="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 dark:bg-amber-900/10 px-4 py-3">
                <AlertTriangle size={18} className="text-amber-500 mt-0.5 flex-shrink-0"/>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-amber-700">🟠 {warning.length} product{warning.length>1?'s':''} expiring within 3 months</p>
                  <p className="text-xs text-amber-600 mt-0.5 truncate">{warning.map(r=>r.productName).join(' · ')}</p>
                </div>
              </div>
            )}
          </div>
        );
      })()}

      {/* Empty state */}
      {!loading && data.length === 0 && periods.length === 0 && (
        <div className="card text-center py-16">
          <BarChart2 size={48} className="mx-auto mb-3 text-gray-300"/>
          <p className="font-semibold text-gray-600 dark:text-gray-300">No stock data yet</p>
          <p className="text-sm text-gray-400 mt-1 mb-4">Click &quot;Re-import Excel&quot; to load data from xldata/</p>
          <button onClick={handleImport} disabled={importing} className="btn-primary mx-auto">
            {importing ? <Loader2 size={14} className="animate-spin mr-2"/> : null}
            Import Now
          </button>
        </div>
      )}

      {/* ── Company Stock Table ── */}
      {type === 'company' && (
        <div className="card overflow-hidden p-0">
          {loading ? (
            <div className="flex items-center justify-center py-16 gap-2 text-gray-400">
              <Loader2 className="animate-spin" size={20}/> Loading…
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-emerald-50 dark:bg-emerald-900/20 text-xs text-gray-600 dark:text-gray-300">
                    <th className="text-left py-3 px-4 font-semibold">Product</th>
                    <th className="text-left py-3 px-3 font-semibold">Pack</th>
                    <th className="text-right py-3 px-3 font-semibold">Cumilla</th>
                    <th className="text-right py-3 px-3 font-semibold">Mymensingh</th>
                    <th className="text-right py-3 px-3 font-semibold">Bogra</th>
                    <th className="text-right py-3 px-3 font-semibold">Jessore</th>
                    <th className="text-right py-3 px-3 font-semibold">Feni</th>
                    <th className="text-right py-3 px-4 font-semibold text-emerald-700 dark:text-emerald-400">Total</th>
                    <th className="text-center py-3 px-3 font-semibold text-orange-600">Expiry Date</th>
                    <th className="text-right py-3 px-3 font-semibold text-red-600">Damage</th>
                  </tr>
                </thead>
                <tbody>
                  {data.map((r,i)=>{
                    const status = expiryStatus(r.expiryDate);
                    const isEditingExpiry  = editCell?.id === r._id && editCell.field === 'expiryDate';
                    const isEditingDamage  = editCell?.id === r._id && editCell.field === 'damageQty';
                    return (
                    <tr key={r._id} className={`border-b border-gray-100 dark:border-gray-800 ${i%2===0?'':'bg-gray-50/40 dark:bg-gray-800/20'} ${status === 'expired' ? 'bg-red-50/60 dark:bg-red-900/10' : status === 'critical' ? 'bg-red-50/30' : status === 'warning' ? 'bg-amber-50/30' : ''}`}>
                      <td className="py-2.5 px-4 font-medium text-gray-900 dark:text-white">{r.productName}</td>
                      <td className="py-2.5 px-3 text-gray-500 text-xs">{r.packSize}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums">{(r.cumillaStock||0).toLocaleString()}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums">{(r.mymensinghStock||0).toLocaleString()}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums">{(r.bograStock||0).toLocaleString()}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums">{(r.jessoreStock||0).toLocaleString()}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums">{(r.feniStock||0).toLocaleString()}</td>
                      <td className="py-2.5 px-4 text-right tabular-nums font-bold text-emerald-700 dark:text-emerald-400">{(r.totalQuantity||0).toLocaleString()}</td>
                      {/* Expiry Date */}
                      <td className="py-2 px-3 text-center">
                        {isEditingExpiry ? (
                          <div className="flex items-center gap-1">
                            <input type="date" autoFocus value={editCell.value}
                              onChange={e=>setEditCell(c=>c?{...c,value:e.target.value}:c)}
                              onKeyDown={e=>{ if(e.key==='Enter') commitEdit(); if(e.key==='Escape') setEditCell(null); }}
                              className="form-input text-xs py-1 px-2 w-32"/>
                            <button onClick={commitEdit} disabled={savingCell}
                              className="text-emerald-600 hover:text-emerald-800"><Check size={13}/></button>
                          </div>
                        ) : (
                          <button onClick={()=>startEdit(r,'expiryDate')}
                            className={`inline-flex items-center gap-1 text-xs px-2 py-1 rounded-lg transition-colors ${status ? EXPIRY_BADGE[status] : 'text-gray-400 hover:text-gray-600 hover:bg-gray-100'}`}>
                            {r.expiryDate
                              ? <><CalendarDays size={10}/>{formatDate(r.expiryDate)}</>
                              : <><Edit3 size={10}/> Set date</>}
                          </button>
                        )}
                      </td>
                      {/* Damage */}
                      <td className="py-2 px-3 text-right">
                        {isEditingDamage ? (
                          <div className="flex items-center gap-1 justify-end">
                            <input type="number" autoFocus value={editCell.value} min="0"
                              onChange={e=>setEditCell(c=>c?{...c,value:e.target.value}:c)}
                              onKeyDown={e=>{ if(e.key==='Enter') commitEdit(); if(e.key==='Escape') setEditCell(null); }}
                              className="form-input text-xs py-1 px-2 w-20 text-right"/>
                            <button onClick={commitEdit} disabled={savingCell}
                              className="text-emerald-600 hover:text-emerald-800"><Check size={13}/></button>
                          </div>
                        ) : (
                          <button onClick={()=>startEdit(r,'damageQty')}
                            className={`text-xs tabular-nums px-2 py-1 rounded-lg transition-colors ${(r.damageQty||0)>0 ? 'text-red-600 font-semibold bg-red-50 hover:bg-red-100' : 'text-gray-400 hover:text-gray-600 hover:bg-gray-100'}`}>
                            {(r.damageQty||0)>0 ? (r.damageQty||0).toLocaleString() : <><Edit3 size={10} className="inline"/> 0</>}
                          </button>
                        )}
                      </td>
                    </tr>
                    );
                  })}
                </tbody>
                {data.length > 0 && (
                  <tfoot>
                    <tr className="bg-emerald-600 text-white text-sm font-bold">
                      <td className="py-3 px-4" colSpan={2}>Total</td>
                      <td className="py-3 px-3 text-right tabular-nums">{totalCumilla.toLocaleString()}</td>
                      <td className="py-3 px-3 text-right tabular-nums">{totalMymensingh.toLocaleString()}</td>
                      <td className="py-3 px-3 text-right tabular-nums">{totalBogra.toLocaleString()}</td>
                      <td className="py-3 px-3 text-right tabular-nums">{totalJessore.toLocaleString()}</td>
                      <td className="py-3 px-3 text-right tabular-nums">{totalFeni.toLocaleString()}</td>
                      <td className="py-3 px-4 text-right tabular-nums">{grandTotal.toLocaleString()}</td>
                      <td className="py-3 px-3"/>
                      <td className="py-3 px-3 text-right tabular-nums">
                        {data.reduce((s,r)=>s+(r.damageQty||0),0).toLocaleString()}
                      </td>
                    </tr>
                  </tfoot>
                )}
              </table>
            </div>
          )}
        </div>
      )}

      {/* ── Branch Stock Table ── */}
      {type === 'branch' && (
        <div className="card overflow-hidden p-0">
          {loading ? (
            <div className="flex items-center justify-center py-16 gap-2 text-gray-400">
              <Loader2 className="animate-spin" size={20}/> Loading…
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-blue-50 dark:bg-blue-900/20 text-xs text-gray-600 dark:text-gray-300">
                    <th className="text-left py-3 px-4 font-semibold">Product</th>
                    <th className="text-left py-3 px-3 font-semibold">Pack</th>
                    <th className="text-left py-3 px-3 font-semibold">Zone</th>
                    <th className="text-right py-3 px-3 font-semibold">Prev Stock</th>
                    <th className="py-3 px-3 font-semibold text-emerald-700">Received</th>
                    <th className="text-right py-3 px-3 font-semibold">Return</th>
                    <th className="text-right py-3 px-3 font-semibold">Total</th>
                    <th className="py-3 px-3 font-semibold text-purple-700">Transfer</th>
                    <th className="text-right py-3 px-3 font-semibold">Sales</th>
                    <th className="text-right py-3 px-3 font-semibold">Bonus</th>
                    <th className="text-right py-3 px-4 font-semibold text-blue-700 dark:text-blue-400">Balance</th>
                    <th className="text-center py-3 px-3 font-semibold text-orange-600">Expiry Date</th>
                    <th className="text-right py-3 px-3 font-semibold text-red-600">Damage</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredData.map((r,i) => {
                    const key  = r.productName.trim().toLowerCase();
                    const txList = txByProduct[key] || [];
                    const receives  = txList.filter(t => t.toBranch   === (selZone || ''));
                    const transfers = txList.filter(t => t.fromBranch === (selZone || ''));
                    // unique source branches for received
                    const fromBranches = [...new Set(txList.map(t=>t.fromBranch))];
                    const toBranches   = [...new Set(txList.map(t=>t.toBranch))];

                    return (
                      <tr key={r._id} className={`border-b border-gray-100 dark:border-gray-800 ${i%2===0?'':'bg-gray-50/40 dark:bg-gray-800/20'}`}>
                        {/* Clickable product name */}
                        <td className="py-2.5 px-4">
                          <button
                            onClick={() => openProductDetail(r)}
                            className="font-medium text-blue-600 hover:text-blue-800 hover:underline text-left leading-tight"
                          >
                            {r.productName}
                          </button>
                          {/* Tags */}
                          {txList.length > 0 && (
                            <div className="flex flex-wrap gap-1 mt-1">
                              {fromBranches.slice(0,2).map(b=>(
                                <span key={'f'+b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 font-medium">
                                  <ArrowRight size={8}/>{b}
                                </span>
                              ))}
                              {toBranches.slice(0,2).map(b=>(
                                <span key={'t'+b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-purple-50 text-purple-700 font-medium">
                                  <ArrowRight size={8}/>{b}
                                </span>
                              ))}
                              {txList.flatMap(t=>t.tags||[]).slice(0,2).map((tag,ti)=>(
                                <span key={ti} className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${tagColor(tag)}`}>
                                  <Tag size={7} className="inline mr-0.5"/>{tag}
                                </span>
                              ))}
                            </div>
                          )}
                        </td>
                        <td className="py-2.5 px-3 text-gray-500 text-xs">{r.packSize}</td>
                        <td className="py-2.5 px-3"><span className="badge-blue badge text-xs">{r.zone}</span></td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-gray-500">{(r.previousStock||0).toLocaleString()}</td>

                        {/* Received cell — qty + from-branch tags */}
                        <td className="py-2.5 px-3">
                          <div className="flex flex-col items-end gap-1">
                            <span className="tabular-nums text-emerald-600 font-semibold text-right">{(r.receivedQty||0).toLocaleString()}</span>
                            {receives.length > 0 && (
                              <div className="flex flex-wrap gap-1 justify-end">
                                {[...new Set(receives.map(t=>t.fromBranch))].map(b=>(
                                  <span key={b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                                    From: {b}
                                  </span>
                                ))}
                              </div>
                            )}
                            {fromBranches.length > 0 && receives.length === 0 && (
                              <div className="flex flex-wrap gap-1 justify-end">
                                {fromBranches.slice(0,2).map(b=>(
                                  <span key={b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                                    From: {b}
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        </td>

                        <td className="py-2.5 px-3 text-right tabular-nums text-amber-600">{(r.returnQty||0).toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums">{(r.totalQuantity||0).toLocaleString()}</td>

                        {/* Transfer cell — qty + to-branch tags */}
                        <td className="py-2.5 px-3">
                          <div className="flex flex-col items-end gap-1">
                            <span className="tabular-nums text-purple-600 font-semibold text-right">{(r.transferQty||0).toLocaleString()}</span>
                            {transfers.length > 0 && (
                              <div className="flex flex-wrap gap-1 justify-end">
                                {[...new Set(transfers.map(t=>t.toBranch))].map(b=>(
                                  <span key={b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-purple-50 text-purple-700 border border-purple-200">
                                    To: {b}
                                  </span>
                                ))}
                              </div>
                            )}
                            {toBranches.length > 0 && transfers.length === 0 && (
                              <div className="flex flex-wrap gap-1 justify-end">
                                {toBranches.slice(0,2).map(b=>(
                                  <span key={b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-purple-50 text-purple-700 border border-purple-200">
                                    To: {b}
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        </td>

                        <td className="py-2.5 px-3 text-right tabular-nums text-red-500">{(r.salesQty||0).toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums">{(r.bonusQty||0).toLocaleString()}</td>
                        <td className="py-2.5 px-4 text-right tabular-nums font-bold text-blue-700 dark:text-blue-400">{(r.presentBalance||0).toLocaleString()}</td>
                        {/* Expiry Date */}
                        {(() => {
                          const status = expiryStatus(r.expiryDate);
                          const isEditingExpiry = editCell?.id === r._id && editCell.field === 'expiryDate';
                          return (
                            <td className="py-2 px-3 text-center">
                              {isEditingExpiry ? (
                                <div className="flex items-center gap-1">
                                  <input type="date" autoFocus value={editCell.value}
                                    onChange={e=>setEditCell(c=>c?{...c,value:e.target.value}:c)}
                                    onKeyDown={e=>{ if(e.key==='Enter') commitEdit(); if(e.key==='Escape') setEditCell(null); }}
                                    className="form-input text-xs py-1 px-2 w-32"/>
                                  <button onClick={commitEdit} disabled={savingCell}
                                    className="text-emerald-600 hover:text-emerald-800"><Check size={13}/></button>
                                </div>
                              ) : (
                                <button onClick={()=>startEdit(r,'expiryDate')}
                                  className={`inline-flex items-center gap-1 text-xs px-2 py-1 rounded-lg transition-colors ${status ? EXPIRY_BADGE[status] : 'text-gray-400 hover:text-gray-600 hover:bg-gray-100'}`}>
                                  {r.expiryDate
                                    ? <><CalendarDays size={10}/>{formatDate(r.expiryDate)}</>
                                    : <><Edit3 size={10}/> Set date</>}
                                </button>
                              )}
                            </td>
                          );
                        })()}
                        {/* Damage */}
                        {(() => {
                          const isEditingDamage = editCell?.id === r._id && editCell.field === 'damageQty';
                          return (
                            <td className="py-2 px-3 text-right">
                              {isEditingDamage ? (
                                <div className="flex items-center gap-1 justify-end">
                                  <input type="number" autoFocus value={editCell.value} min="0"
                                    onChange={e=>setEditCell(c=>c?{...c,value:e.target.value}:c)}
                                    onKeyDown={e=>{ if(e.key==='Enter') commitEdit(); if(e.key==='Escape') setEditCell(null); }}
                                    className="form-input text-xs py-1 px-2 w-20 text-right"/>
                                  <button onClick={commitEdit} disabled={savingCell}
                                    className="text-emerald-600 hover:text-emerald-800"><Check size={13}/></button>
                                </div>
                              ) : (
                                <button onClick={()=>startEdit(r,'damageQty')}
                                  className={`text-xs tabular-nums px-2 py-1 rounded-lg transition-colors ${(r.damageQty||0)>0 ? 'text-red-600 font-semibold bg-red-50 hover:bg-red-100' : 'text-gray-400 hover:text-gray-600 hover:bg-gray-100'}`}>
                                  {(r.damageQty||0)>0 ? (r.damageQty||0).toLocaleString() : <><Edit3 size={10} className="inline"/> 0</>}
                                </button>
                              )}
                            </td>
                          );
                        })()}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
              {filteredData.length === 0 && !loading && (
                <div className="text-center py-12 text-gray-400 text-sm">No data for selected filters</div>
              )}
            </div>
          )}
        </div>
      )}

      {/* ══ Product Detail Popup ══ */}
      <Modal
        open={!!detailProduct}
        onClose={() => { setDetailProduct(null); setShowAddTx(false); }}
        title={
          <span className="flex items-center gap-2">
            <Package size={18} className="text-blue-500"/>
            {detailProduct?.productName}
            {detailProduct?.packSize && (
              <span className="text-sm font-normal text-gray-400 ml-1">{detailProduct.packSize}</span>
            )}
          </span>
        }
        size="lg"
      >
        {detailProduct && (
          <div className="space-y-4">
            {/* Stock summary strip */}
            <div className="grid grid-cols-3 sm:grid-cols-6 gap-2">
              {[
                { label: 'Prev Stock', value: detailProduct.previousStock ?? 0, color: 'gray' },
                { label: 'Received',   value: detailProduct.receivedQty   ?? 0, color: 'emerald' },
                { label: 'Transfer',   value: detailProduct.transferQty   ?? 0, color: 'purple' },
                { label: 'Sales',      value: detailProduct.salesQty      ?? 0, color: 'red' },
                { label: 'Return',     value: detailProduct.returnQty     ?? 0, color: 'amber' },
                { label: 'Balance',    value: detailProduct.presentBalance ?? 0, color: 'blue' },
              ].map(s => (
                <div key={s.label} className={`rounded-xl p-2.5 text-center bg-${s.color}-50 dark:bg-${s.color}-900/20`}>
                  <p className={`text-lg font-bold text-${s.color}-600`}>{s.value.toLocaleString()}</p>
                  <p className="text-[10px] text-gray-500 mt-0.5">{s.label}</p>
                </div>
              ))}
            </div>

            {/* Transfer history header */}
            <div className="flex items-center justify-between">
              <h4 className="font-semibold text-gray-800 dark:text-white flex items-center gap-2">
                <ArrowLeftRight size={15} className="text-blue-500"/>
                Transfer History
                {detailTx.length > 0 && (
                  <span className="text-xs font-normal text-gray-400">({detailTx.length} records)</span>
                )}
              </h4>
              <Button size="sm" onClick={() => setShowAddTx(v=>!v)}>
                <Plus size={13}/> {showAddTx ? 'Cancel' : 'Add Transfer'}
              </Button>
            </div>

            {/* Add transfer form */}
            {showAddTx && (
              <div className="border border-blue-200 dark:border-blue-700 rounded-xl p-4 bg-blue-50/40 dark:bg-blue-900/10 space-y-3">
                <p className="text-xs font-semibold text-blue-700 uppercase tracking-wide">New Transfer Record</p>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs text-gray-500 mb-1 block">From Branch *</label>
                    <select value={txForm.fromBranch} onChange={e=>setTxForm(f=>({...f,fromBranch:e.target.value}))}
                      className="form-input w-full text-sm py-2">
                      <option value="">Select branch</option>
                      {BRANCHES.map(b=><option key={b} value={b}>{b}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 block">To Branch *</label>
                    <select value={txForm.toBranch} onChange={e=>setTxForm(f=>({...f,toBranch:e.target.value}))}
                      className="form-input w-full text-sm py-2">
                      <option value="">Select branch</option>
                      {BRANCHES.map(b=><option key={b} value={b}>{b}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 block">Quantity *</label>
                    <input type="number" value={txForm.quantity} onChange={e=>setTxForm(f=>({...f,quantity:e.target.value}))}
                      className="form-input w-full text-sm py-2" placeholder="0" min="1"/>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 block">Date</label>
                    <input type="date" value={txForm.date} onChange={e=>setTxForm(f=>({...f,date:e.target.value}))}
                      className="form-input w-full text-sm py-2"/>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 block">Transferred By</label>
                    <input value={txForm.transferredBy} onChange={e=>setTxForm(f=>({...f,transferredBy:e.target.value}))}
                      className="form-input w-full text-sm py-2" placeholder="Name / vehicle"/>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 block">Tags (comma separated)</label>
                    <input value={txForm.tags} onChange={e=>setTxForm(f=>({...f,tags:e.target.value}))}
                      className="form-input w-full text-sm py-2" placeholder="e.g. urgent, transfer"/>
                  </div>
                  <div className="col-span-2">
                    <label className="text-xs text-gray-500 mb-1 block">Notes</label>
                    <input value={txForm.notes} onChange={e=>setTxForm(f=>({...f,notes:e.target.value}))}
                      className="form-input w-full text-sm py-2" placeholder="Optional notes…"/>
                  </div>
                </div>
                <div className="flex justify-end gap-2">
                  <button onClick={()=>setShowAddTx(false)} className="btn-ghost text-sm py-1.5 px-3">Cancel</button>
                  <Button onClick={handleSaveTransfer} loading={savingTx} size="sm">Save Transfer</Button>
                </div>
              </div>
            )}

            {/* History list */}
            {detailTxLoad ? (
              <div className="flex items-center justify-center py-10 gap-2 text-gray-400">
                <Loader2 className="animate-spin" size={18}/> Loading history…
              </div>
            ) : detailTx.length === 0 ? (
              <div className="text-center py-10 text-gray-400 text-sm">
                <ArrowLeftRight size={32} className="mx-auto mb-2 opacity-30"/>
                No transfer records yet. Click &quot;Add Transfer&quot; to log one.
              </div>
            ) : (
              <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
                {detailTx.map(tx => (
                  <div key={tx._id}
                    className="flex items-start gap-3 p-3 rounded-xl border border-gray-100 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                    {/* Arrow indicator */}
                    <div className="flex items-center gap-1.5 min-w-0 flex-1">
                      <span className="text-sm font-semibold text-emerald-700 bg-emerald-50 px-2 py-1 rounded-lg whitespace-nowrap">
                        {tx.fromBranch}
                      </span>
                      <ArrowRight size={14} className="text-gray-400 flex-shrink-0"/>
                      <span className="text-sm font-semibold text-purple-700 bg-purple-50 px-2 py-1 rounded-lg whitespace-nowrap">
                        {tx.toBranch}
                      </span>
                      <span className="text-base font-bold text-gray-800 dark:text-white ml-2 whitespace-nowrap">
                        ×{tx.quantity.toLocaleString()}
                      </span>
                    </div>
                    {/* Meta */}
                    <div className="text-right flex-shrink-0 space-y-0.5">
                      <div className="flex items-center justify-end gap-1 text-xs text-gray-500">
                        <CalendarDays size={11}/> {fmtDate(tx.date)}
                      </div>
                      {tx.transferredBy && (
                        <div className="flex items-center justify-end gap-1 text-xs text-gray-500">
                          <User size={11}/> {tx.transferredBy}
                        </div>
                      )}
                      {tx.notes && (
                        <div className="flex items-center justify-end gap-1 text-xs text-gray-400">
                          <StickyNote size={11}/> {tx.notes}
                        </div>
                      )}
                      {tx.tags && tx.tags.length > 0 && (
                        <div className="flex gap-1 justify-end flex-wrap mt-1">
                          {tx.tags.map((tag,ti)=>(
                            <span key={ti} className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${tagColor(tag)}`}>
                              {tag}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}
