'use client';
import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import Topbar from '@/components/layout/Topbar';
import {
  FlaskConical, Search, Loader2, Info, ArrowRight,
  ArrowLeftRight, ChevronDown, X,
  Edit2, Trash2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';

const MONTH_NAMES = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

const BRANCHES = ['Cumilla','Mymensingh','Bogra','Jessore','Feni','Depot'];

interface ProdRow {
  _id: string; productName: string; packSize: string; zone: string;
  previousBalanceKg: number; receivedKg: number; totalKg: number;
  totalProductPcs: number; pcsTransfer: number; convertKg: number; totalConvertKg: number;
  wastageKg: number; presentBalanceKg: number; remarks?: string;
}
interface Period { _id: { year: number; month: number }; count: number; }

interface Transfer {
  _id: string;
  productName: string;
  packSize?: string;
  fromBranch: string;
  toBranch: string;
  quantity: number;
  weightGram?: number;
  pcsCount?: number;
  transferredBy?: string;
  notes?: string;
  date: string;
  tags?: string[];
}


export default function ProductionPage() {
  const router = useRouter();

  const [periods, setPeriods]   = useState<Period[]>([]);
  const [selYear, setSelYear]   = useState('');
  const [selMonth, setSelMonth] = useState('');
  const [search, setSearch]     = useState('');
  const [data, setData]         = useState<ProdRow[]>([]);
  const [loading, setLoading]   = useState(false);

  // ── branch movement filters ────────────────────────────────
  const [filterFrom, setFilterFrom] = useState('');
  const [filterTo,   setFilterTo]   = useState('');

  // ── transfers (for tags in table) ─────────────────────────
  const [transfers,  setTransfers]  = useState<Transfer[]>([]);
  const [txLoading,  setTxLoading]  = useState(false);

  // ── edit / delete ──────────────────────────────────────────
  const [editRow,   setEditRow]   = useState<ProdRow | null>(null);
  const [editForm,  setEditForm]  = useState<Partial<ProdRow>>({});
  const [savingEdit, setSavingEdit] = useState(false);

  const openEditRow = (r: ProdRow) => {
    setEditRow(r);
    setEditForm({ ...r });
  };

  const handleEditSave = async () => {
    if (!editRow) return;
    setSavingEdit(true);
    try {
      const res = await fetch(`/api/production-reports/${editRow._id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(editForm),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success('Record updated');
      setEditRow(null);
      fetchData();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Update failed'); }
    finally { setSavingEdit(false); }
  };

  const handleDeleteRow = async (r: ProdRow) => {
    if (!confirm(`Delete "${r.productName} ${r.packSize}"? This cannot be undone.`)) return;
    try {
      const res = await fetch(`/api/production-reports/${r._id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Delete failed');
      toast.success('Record deleted');
      fetchData();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Delete failed'); }
  };

  // ── fetch meta ──────────────────────────────────────────────
  const fetchMeta = useCallback(async () => {
    try {
      const r = await fetch('/api/production-reports?year=2000&month=1');
      const d = await r.json();
      setPeriods(d.periods || []);
      if (d.periods?.length) {
        setSelYear(String(d.periods[0]._id.year));
        setSelMonth(String(d.periods[0]._id.month));
      }
    } catch { /* ignore */ }
  }, []);
  useEffect(() => { fetchMeta(); }, [fetchMeta]);

  // ── fetch production data ──────────────────────────────────
  const fetchData = useCallback(async () => {
    if (!selYear || !selMonth) return;
    setLoading(true);
    try {
      const r = await fetch(`/api/production-reports?year=${selYear}&month=${selMonth}&search=${encodeURIComponent(search)}`);
      const d = await r.json();
      setData(d.data || []);
    } catch { toast.error('Failed to load'); setData([]); }
    finally { setLoading(false); }
  }, [selYear, selMonth, search]);
  useEffect(() => { fetchData(); }, [fetchData]);

  // ── fetch transfers ────────────────────────────────────────
  const fetchTransfers = useCallback(async () => {
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
  }, [filterFrom, filterTo]);
  useEffect(() => { fetchTransfers(); }, [fetchTransfers]);

  // ── helpers ────────────────────────────────────────────────
  const uniqueYears   = [...new Set(periods.map(p => p._id.year))].sort((a,b)=>b-a);
  const monthsForYear = periods.filter(p => p._id.year === parseInt(selYear)).map(p => p._id.month).sort((a,b)=>a-b);

  const totalPrevKg      = data.reduce((s,r)=>s+r.previousBalanceKg,0);
  const totalReceivedKg  = data.reduce((s,r)=>s+r.receivedKg,0);
  const totalPcs         = data.reduce((s,r)=>s+r.totalProductPcs,0);
  const totalPcsTransfer = data.reduce((s,r)=>s+(r.pcsTransfer||0),0);
  const totalWastage     = data.reduce((s,r)=>s+r.wastageKg,0);
  const totalBalance     = data.reduce((s,r)=>s+r.presentBalanceKg,0);

  // map productName → transfers
  const txByProduct = transfers.reduce<Record<string, Transfer[]>>((acc, t) => {
    const k = t.productName.trim().toLowerCase();
    if (!acc[k]) acc[k] = [];
    acc[k].push(t);
    return acc;
  }, {});

  // filter rows by branch movement
  const filteredData = (filterFrom || filterTo)
    ? data.filter(row => {
        const list = txByProduct[row.productName.trim().toLowerCase()] || [];
        if (filterFrom && !list.some(t => t.fromBranch === filterFrom)) return false;
        if (filterTo   && !list.some(t => t.toBranch   === filterTo))   return false;
        return true;
      })
    : data;

  return (
    <div className="page-wrapper">
      <Topbar title="Production Unit" subtitle="Big pack → small pack conversion tracking" />

      {/* Info banner */}
      <div className="flex items-start gap-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-2xl px-4 py-3 text-sm text-blue-800 dark:text-blue-300">
        <Info size={16} className="shrink-0 mt-0.5"/>
        <p>পণ্য বড় প্যাকেট থেকে ছোট প্যাকেট/বোতলে প্যাকেজিং করে মূল স্টকে ট্রান্সফার করা হয়। এই রিপোর্টে সেই production unit-এর মাসিক ট্র্যাকিং দেখা যাবে।</p>
      </div>

      {/* Filters */}
      <div className="card space-y-3">
        <div className="flex flex-wrap gap-3 items-center">
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

          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={14}/>
            <input value={search} onChange={e=>setSearch(e.target.value)}
              placeholder="Search product…" className="form-input pl-9 w-full text-sm py-2"/>
          </div>

          <span className="text-sm text-gray-400">{filteredData.length} products</span>
        </div>

        {/* Branch movement dropdowns */}
        <div className="flex flex-wrap gap-3 items-center pt-1 border-t border-gray-100 dark:border-gray-700">
          <span className="text-xs font-semibold text-gray-500 uppercase tracking-wide flex items-center gap-1">
            <ArrowLeftRight size={13}/> Branch Movement
          </span>

          <div className="flex items-center gap-1.5">
            <span className="text-xs text-emerald-600 font-medium whitespace-nowrap">Transfer From:</span>
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
      </div>

      {/* Empty state */}
      {!loading && data.length === 0 && periods.length === 0 && (
        <div className="card text-center py-16">
          <FlaskConical size={48} className="mx-auto mb-3 text-gray-300"/>
          <p className="font-semibold text-gray-600 dark:text-gray-300">No production data yet</p>
          <p className="text-sm text-gray-400 mt-1">Go to Stock Reports and click &quot;Re-import Excel&quot; to load all data</p>
        </div>
      )}

      {/* Table */}
      {(filteredData.length > 0 || loading) && (
        <div className="card overflow-hidden p-0">
          {loading ? (
            <div className="flex items-center justify-center py-16 gap-2 text-gray-400">
              <Loader2 className="animate-spin" size={20}/> Loading…
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-purple-50 dark:bg-purple-900/20 text-xs text-gray-600 dark:text-gray-300">
                    <th className="text-left py-3 px-4 font-semibold">Product</th>
                    <th className="text-left py-3 px-3 font-semibold">Pack</th>
                    <th className="text-right py-3 px-3 font-semibold">Prev Balance (Kg/L)</th>
                    <th className="text-right py-3 px-3 font-semibold">Received (Kg/L)</th>
                    <th className="text-right py-3 px-3 font-semibold">Total (Kg/L)</th>
                    <th className="text-right py-3 px-3 font-semibold">Transfer Qty</th>
                    <th className="text-right py-3 px-3 font-semibold text-orange-600">Pcs Transfer</th>
                    <th className="text-right py-3 px-3 font-semibold">Convert (Kg/L)</th>
                    <th className="text-right py-3 px-3 font-semibold">Wastage (Kg/L)</th>
                    <th className="text-right py-3 px-4 font-semibold text-purple-700 dark:text-purple-400">Balance (Kg/L)</th>
                    <th className="text-left py-3 px-3 font-semibold">Remarks</th>
                    <th className="py-3 px-3"></th>
                  </tr>
                </thead>
                <tbody>
                  {filteredData.map((r,i) => {
                    const key    = r.productName.trim().toLowerCase();
                    const txList = txByProduct[key] || [];
                    const froms  = [...new Set(txList.map(t=>t.fromBranch))];
                    const tos    = [...new Set(txList.map(t=>t.toBranch))];

                    return (
                      <tr key={r._id} className={`border-b border-gray-100 dark:border-gray-800 ${i%2===0?'':'bg-gray-50/40 dark:bg-gray-800/20'}`}>
                        <td className="py-2.5 px-4">
                          {/* Clickable → full detail page */}
                          <button
                            onClick={() => router.push(`/inventory/production/${r._id}`)}
                            className="font-medium text-blue-600 hover:text-blue-800 hover:underline text-left leading-tight"
                          >
                            {r.productName}
                          </button>
                          {txList.length > 0 && (
                            <div className="flex flex-wrap gap-1 mt-1">
                              {froms.slice(0,2).map(b=>(
                                <span key={'f'+b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 font-medium">
                                  <ArrowRight size={8}/>{b}
                                </span>
                              ))}
                              {tos.slice(0,2).map(b=>(
                                <span key={'t'+b} className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-purple-50 text-purple-700 font-medium">
                                  <ArrowRight size={8}/>{b}
                                </span>
                              ))}
                            </div>
                          )}
                        </td>
                        <td className="py-2.5 px-3 text-gray-500 text-xs">{r.packSize}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-gray-500">{r.previousBalanceKg.toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-emerald-600">{r.receivedKg.toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums">{r.totalKg.toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-blue-600 font-semibold">{r.totalProductPcs.toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-orange-600 font-semibold">{(r.pcsTransfer||0).toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-indigo-600">{r.convertKg.toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-red-500">{r.wastageKg.toLocaleString()}</td>
                        <td className="py-2.5 px-4 text-right tabular-nums font-bold text-purple-700 dark:text-purple-400">{r.presentBalanceKg.toLocaleString()}</td>
                        <td className="py-2.5 px-3 text-gray-400 text-xs">{r.remarks}</td>
                        <td className="py-2.5 px-3">
                          <div className="flex items-center gap-1">
                            <button onClick={() => openEditRow(r)} className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors" title="Edit"><Edit2 size={12}/></button>
                            <button onClick={() => handleDeleteRow(r)} className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors" title="Delete"><Trash2 size={12}/></button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
                <tfoot>
                  <tr className="bg-purple-600 text-white text-sm font-bold">
                    <td className="py-3 px-4" colSpan={2}>Total</td>
                    <td className="py-3 px-3 text-right tabular-nums">{totalPrevKg.toLocaleString()}</td>
                    <td className="py-3 px-3 text-right tabular-nums">{totalReceivedKg.toLocaleString()}</td>
                    <td className="py-3 px-3 text-right tabular-nums">{(totalPrevKg+totalReceivedKg).toLocaleString()}</td>
                    <td className="py-3 px-3 text-right tabular-nums">{totalPcs.toLocaleString()}</td>
                    <td className="py-3 px-3 text-right tabular-nums">{totalPcsTransfer.toLocaleString()}</td>
                    <td className="py-3 px-3 text-right tabular-nums">—</td>
                    <td className="py-3 px-3 text-right tabular-nums">{totalWastage.toLocaleString()}</td>
                    <td className="py-3 px-4 text-right tabular-nums">{totalBalance.toLocaleString()}</td>
                    <td className="py-3 px-3"/>
                    <td className="py-3 px-3"/>
                  </tr>
                </tfoot>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ══ Edit Production Record Modal ══ */}
      <Modal
        open={!!editRow}
        onClose={() => setEditRow(null)}
        title={
          <span className="flex items-center gap-2">
            <Edit2 size={16} className="text-blue-500"/>
            Edit: {editRow?.productName} {editRow?.packSize}
          </span>
        }
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setEditRow(null)}>Cancel</Button>
            <Button onClick={handleEditSave} loading={savingEdit}>Save Changes</Button>
          </>
        }
      >
        {editRow && (
          <div className="grid grid-cols-2 gap-4">
            {[
              { key: 'productName',      label: 'Product Name',           type: 'text' },
              { key: 'packSize',         label: 'Pack Size',              type: 'text' },
              { key: 'previousBalanceKg',label: 'Prev Balance (Kg/L)',    type: 'number' },
              { key: 'receivedKg',       label: 'Received (Kg/L)',        type: 'number' },
              { key: 'totalKg',          label: 'Total (Kg/L)',           type: 'number' },
              { key: 'totalProductPcs',  label: 'Transfer Qty (Pcs)',     type: 'number' },
              { key: 'pcsTransfer',      label: 'Pcs Transfer',           type: 'number' },
              { key: 'convertKg',        label: 'Convert (Kg/L)',         type: 'number' },
              { key: 'totalConvertKg',   label: 'Total Convert (Kg/L)',   type: 'number' },
              { key: 'wastageKg',        label: 'Wastage (Kg/L)',         type: 'number' },
              { key: 'presentBalanceKg', label: 'Present Balance (Kg/L)', type: 'number' },
            ].map(f => (
              <div key={f.key}>
                <label className="form-label">{f.label}</label>
                <input
                  type={f.type}
                  className="form-input w-full"
                  value={String(editForm[f.key as keyof ProdRow] ?? '')}
                  onChange={e => setEditForm(prev => ({
                    ...prev,
                    [f.key]: f.type === 'number' ? (parseFloat(e.target.value) || 0) : e.target.value,
                  }))}
                />
              </div>
            ))}
            <div className="col-span-2">
              <label className="form-label">Remarks</label>
              <input
                className="form-input w-full"
                value={editForm.remarks ?? ''}
                onChange={e => setEditForm(prev => ({ ...prev, remarks: e.target.value }))}
              />
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
