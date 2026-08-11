'use client';
import { useState, useEffect, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Topbar from '@/components/layout/Topbar';
import {
  FlaskConical, ArrowLeft, ArrowRight, ArrowLeftRight,
  Plus, Loader2, CalendarDays, User, StickyNote, Tag,
  Package, Edit2, ChevronDown, X,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { Button } from '@/components/ui/Button';
import { Modal } from '@/components/ui/Modal';
import { formatDate } from '@/lib/utils';

const BRANCHES = ['Cumilla', 'Mymensingh', 'Bogra', 'Jessore', 'Feni', 'Depot'];

interface ProdRow {
  _id: string; productName: string; packSize: string; zone: string;
  previousBalanceKg: number; receivedKg: number; totalKg: number;
  totalProductPcs: number; pcsTransfer: number; convertKg: number; totalConvertKg: number;
  wastageKg: number; presentBalanceKg: number; remarks?: string;
}

interface Transfer {
  _id: string; productName: string; packSize?: string;
  fromBranch: string; toBranch: string; quantity: number;
  weightGram?: number; pcsCount?: number;
  transferredBy?: string; notes?: string; date: string; tags?: string[];
}

const emptyTxForm = () => ({
  fromBranch: '', toBranch: '',
  quantity: '', weightGram: '', pcsCount: '',
  transferredBy: '', notes: '',
  date: new Date().toISOString().slice(0, 10),
  tags: '',
});

const TAG_COLORS: Record<string, string> = {
  transfer : 'bg-purple-100 text-purple-700',
  received : 'bg-emerald-100 text-emerald-700',
  return   : 'bg-amber-100  text-amber-700',
  urgent   : 'bg-red-100    text-red-700',
  bonus    : 'bg-blue-100   text-blue-700',
};
function tagColor(t: string) { return TAG_COLORS[t.toLowerCase()] ?? 'bg-gray-100 text-gray-600'; }
const fmtDate = (d: string) => formatDate(d);

export default function ProductionDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router  = useRouter();

  const [row,     setRow]     = useState<ProdRow | null>(null);
  const [loading, setLoading] = useState(true);

  // transfers
  const [transfers,  setTransfers]  = useState<Transfer[]>([]);
  const [txLoading,  setTxLoading]  = useState(false);
  const [showAddTx,  setShowAddTx]  = useState(false);
  const [txForm,     setTxForm]     = useState(emptyTxForm());
  const [savingTx,   setSavingTx]   = useState(false);

  // edit modal
  const [showEdit,   setShowEdit]   = useState(false);
  const [editForm,   setEditForm]   = useState<Partial<ProdRow>>({});
  const [savingEdit, setSavingEdit] = useState(false);

  // ── fetch production record ─────────────────────────────────
  const fetchRow = useCallback(async () => {
    setLoading(true);
    try {
      // get all records and find the one matching id
      const r = await fetch(`/api/production-reports?year=2000&month=1`);
      const meta = await r.json();
      // fetch wide search
      const r2 = await fetch(`/api/production-reports?_id=${id}&limit=1000&year=0&month=0`);
      const d2  = await r2.json();
      // Find by _id directly via a broad fetch
      const found = (d2.data || []).find((x: ProdRow) => x._id === id);
      if (found) { setRow(found); setEditForm({ ...found }); }
      else {
        // fallback: fetch without filters
        const r3 = await fetch(`/api/production-reports?limit=2000`);
        const d3  = await r3.json();
        const f2  = (d3.data || []).find((x: ProdRow) => x._id === id);
        if (f2) { setRow(f2); setEditForm({ ...f2 }); }
        else toast.error('Record not found');
      }
      void meta;
    } catch { toast.error('Failed to load record'); }
    finally { setLoading(false); }
  }, [id]);

  useEffect(() => { fetchRow(); }, [fetchRow]);

  // ── fetch transfers ─────────────────────────────────────────
  const fetchTransfers = useCallback(async () => {
    if (!row) return;
    setTxLoading(true);
    try {
      const r = await fetch(`/api/stock-transfers?productName=${encodeURIComponent(row.productName)}&limit=200`);
      const d = await r.json();
      setTransfers(d.data || []);
    } catch { setTransfers([]); }
    finally { setTxLoading(false); }
  }, [row]);

  useEffect(() => { fetchTransfers(); }, [fetchTransfers]);

  // ── save transfer ───────────────────────────────────────────
  const handleSaveTransfer = async () => {
    if (!row) return;
    if (!txForm.fromBranch)  return toast.error('From branch required');
    if (!txForm.toBranch)    return toast.error('To branch required');
    if (txForm.fromBranch === txForm.toBranch) return toast.error('From and To branch must differ');
    if (!txForm.quantity || Number(txForm.quantity) <= 0) return toast.error('Enter a valid quantity');
    setSavingTx(true);
    try {
      const payload = {
        productName:   row.productName,
        packSize:      row.packSize,
        fromBranch:    txForm.fromBranch,
        toBranch:      txForm.toBranch,
        quantity:      Number(txForm.quantity),
        weightGram:    txForm.weightGram    ? Number(txForm.weightGram)    : undefined,
        pcsCount:      txForm.pcsCount      ? Number(txForm.pcsCount)      : undefined,
        transferredBy: txForm.transferredBy,
        notes:         txForm.notes,
        date:          txForm.date,
        tags: txForm.tags ? txForm.tags.split(',').map((t: string) => t.trim()).filter(Boolean) : [],
      };
      const res = await fetch('/api/stock-transfers', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success('Transfer recorded');
      setShowAddTx(false);
      setTxForm(emptyTxForm());
      fetchTransfers();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Failed'); }
    finally { setSavingTx(false); }
  };

  // ── save edit ───────────────────────────────────────────────
  const handleEditSave = async () => {
    if (!row) return;
    setSavingEdit(true);
    try {
      const res = await fetch(`/api/production-reports/${row._id}`, {
        method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(editForm),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      const updated = await res.json();
      setRow(updated);
      setShowEdit(false);
      toast.success('Record updated');
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Update failed'); }
    finally { setSavingEdit(false); }
  };

  // summary totals from transfers
  const totalTxQty  = transfers.reduce((s, t) => s + t.quantity, 0);
  const totalTxPcs  = transfers.reduce((s, t) => s + (t.pcsCount || 0), 0);
  const uniqueFrom  = [...new Set(transfers.map(t => t.fromBranch))];
  const uniqueTo    = [...new Set(transfers.map(t => t.toBranch))];

  if (loading) {
    return (
      <div className="page-wrapper">
        <Topbar title="Production Detail" subtitle="Loading…" />
        <div className="flex items-center justify-center py-32 gap-2 text-gray-400">
          <Loader2 className="animate-spin" size={24}/> Loading…
        </div>
      </div>
    );
  }

  if (!row) {
    return (
      <div className="page-wrapper">
        <Topbar title="Production Detail" subtitle="Not found" />
        <div className="card text-center py-16 text-gray-400">
          <Package size={48} className="mx-auto mb-3 opacity-30"/>
          <p className="font-semibold">Record not found</p>
          <button onClick={() => router.back()} className="btn-ghost mt-4 text-sm">← Go back</button>
        </div>
      </div>
    );
  }

  return (
    <div className="page-wrapper">
      <Topbar
        title={row.productName}
        subtitle={`${row.packSize}${row.zone ? ` · ${row.zone}` : ''} · Production Detail`}
        actions={
          <div className="flex items-center gap-2">
            <button onClick={() => router.push('/inventory/production')}
              className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-800 dark:hover:text-white transition-colors">
              <ArrowLeft size={14}/> Back
            </button>
            <Button size="sm" onClick={() => { setEditForm({ ...row }); setShowEdit(true); }}>
              <Edit2 size={13}/> Edit Record
            </Button>
          </div>
        }
      />

      {/* ── Production Stats Grid ── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 xl:grid-cols-8 gap-3">
        {[
          { label: 'Prev Balance', value: `${row.previousBalanceKg.toLocaleString()}`, unit: 'Kg/L', color: 'gray' },
          { label: 'Received',     value: `${row.receivedKg.toLocaleString()}`,        unit: 'Kg/L', color: 'emerald' },
          { label: 'Total',        value: `${row.totalKg.toLocaleString()}`,            unit: 'Kg/L', color: 'blue' },
          { label: 'Transfer Qty', value: row.totalProductPcs.toLocaleString(),         unit: 'Pcs',  color: 'indigo' },
          { label: 'Pcs Transfer', value: (row.pcsTransfer || 0).toLocaleString(),      unit: 'Pcs',  color: 'orange' },
          { label: 'Convert',      value: `${row.convertKg.toLocaleString()}`,          unit: 'Kg/L', color: 'teal' },
          { label: 'Wastage',      value: `${row.wastageKg.toLocaleString()}`,          unit: 'Kg/L', color: 'red' },
          { label: 'Balance',      value: `${row.presentBalanceKg.toLocaleString()}`,   unit: 'Kg/L', color: 'purple' },
        ].map(s => (
          <div key={s.label} className={`card text-center py-3 px-2 bg-${s.color}-50 dark:bg-${s.color}-900/20 border-0`}>
            <p className={`text-xl font-bold text-${s.color}-600 leading-tight`}>{s.value}</p>
            <p className="text-[10px] text-gray-500 mt-0.5 font-medium">{s.unit}</p>
            <p className="text-[10px] text-gray-400 mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      {/* ── Transfer Summary Cards ── */}
      {transfers.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <div className="card text-center">
            <p className="text-2xl font-bold text-blue-600">{transfers.length}</p>
            <p className="text-xs text-gray-500 mt-0.5">Total Transfers</p>
          </div>
          <div className="card text-center">
            <p className="text-2xl font-bold text-emerald-600">{totalTxQty.toLocaleString()}</p>
            <p className="text-xs text-gray-500 mt-0.5">Total Qty Moved</p>
          </div>
          <div className="card text-center">
            <p className="text-2xl font-bold text-orange-600">{totalTxPcs.toLocaleString()}</p>
            <p className="text-xs text-gray-500 mt-0.5">Total Pcs Moved</p>
          </div>
          <div className="card">
            <p className="text-xs font-semibold text-gray-500 mb-1.5">Active Branches</p>
            <div className="flex flex-wrap gap-1">
              {uniqueFrom.map(b => (
                <span key={'f'+b} className="text-[10px] px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                  From: {b}
                </span>
              ))}
              {uniqueTo.map(b => (
                <span key={'t'+b} className="text-[10px] px-1.5 py-0.5 rounded-full bg-purple-50 text-purple-700 border border-purple-200">
                  To: {b}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}

      {row.remarks && (
        <div className="flex items-start gap-2 px-4 py-3 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 text-sm text-amber-800 dark:text-amber-300">
          <StickyNote size={14} className="shrink-0 mt-0.5"/>
          <span>{row.remarks}</span>
        </div>
      )}

      {/* ── Transfer History ── */}
      <div className="card space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h3 className="font-semibold text-gray-800 dark:text-white flex items-center gap-2 text-base">
            <ArrowLeftRight size={16} className="text-purple-500"/>
            Branch Transfer History
            {txLoading && <Loader2 size={13} className="animate-spin text-gray-400"/>}
            {transfers.length > 0 && (
              <span className="text-xs font-normal text-gray-400">({transfers.length} records)</span>
            )}
          </h3>
          <Button size="sm" onClick={() => setShowAddTx(v => !v)}>
            <Plus size={13}/> {showAddTx ? 'Cancel' : 'Add Transfer'}
          </Button>
        </div>

        {/* Add Transfer Form */}
        {showAddTx && (
          <div className="border border-purple-200 dark:border-purple-700 rounded-xl p-4 bg-purple-50/40 dark:bg-purple-900/10 space-y-3">
            <p className="text-xs font-semibold text-purple-700 dark:text-purple-300 uppercase tracking-wide">New Transfer Record</p>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              <div>
                <label className="text-xs text-gray-500 mb-1 block">From Branch *</label>
                <div className="relative">
                  <select value={txForm.fromBranch} onChange={e => setTxForm(f => ({ ...f, fromBranch: e.target.value }))}
                    className="form-input w-full text-sm py-2 appearance-none pr-8">
                    <option value="">Select branch</option>
                    {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
                  </select>
                  <ChevronDown size={13} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"/>
                </div>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">To Branch *</label>
                <div className="relative">
                  <select value={txForm.toBranch} onChange={e => setTxForm(f => ({ ...f, toBranch: e.target.value }))}
                    className="form-input w-full text-sm py-2 appearance-none pr-8">
                    <option value="">Select branch</option>
                    {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
                  </select>
                  <ChevronDown size={13} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"/>
                </div>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Quantity *</label>
                <input type="number" value={txForm.quantity} min="1"
                  onChange={e => setTxForm(f => ({ ...f, quantity: e.target.value }))}
                  className="form-input w-full text-sm py-2" placeholder="0"/>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Pcs Count</label>
                <input type="number" value={txForm.pcsCount} min="0"
                  onChange={e => setTxForm(f => ({ ...f, pcsCount: e.target.value }))}
                  className="form-input w-full text-sm py-2" placeholder="0"/>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Weight (Gram/Kg)</label>
                <input type="number" value={txForm.weightGram} min="0"
                  onChange={e => setTxForm(f => ({ ...f, weightGram: e.target.value }))}
                  className="form-input w-full text-sm py-2" placeholder="e.g. 500"/>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Date</label>
                <input type="date" value={txForm.date}
                  onChange={e => setTxForm(f => ({ ...f, date: e.target.value }))}
                  className="form-input w-full text-sm py-2"/>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Transferred By</label>
                <input value={txForm.transferredBy}
                  onChange={e => setTxForm(f => ({ ...f, transferredBy: e.target.value }))}
                  className="form-input w-full text-sm py-2" placeholder="Name / vehicle"/>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Tags <span className="font-normal text-gray-400">(comma separated)</span></label>
                <input value={txForm.tags}
                  onChange={e => setTxForm(f => ({ ...f, tags: e.target.value }))}
                  className="form-input w-full text-sm py-2" placeholder="urgent, transfer…"/>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Notes</label>
                <input value={txForm.notes}
                  onChange={e => setTxForm(f => ({ ...f, notes: e.target.value }))}
                  className="form-input w-full text-sm py-2" placeholder="Optional notes…"/>
              </div>
            </div>
            {/* Arrow preview */}
            {(txForm.fromBranch || txForm.toBranch) && (
              <div className="flex items-center justify-center gap-3 py-1">
                <span className={`text-sm font-semibold px-3 py-1.5 rounded-xl ${txForm.fromBranch ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-400'}`}>
                  {txForm.fromBranch || '—'}
                </span>
                <ArrowRight size={16} className="text-gray-400"/>
                <span className={`text-sm font-semibold px-3 py-1.5 rounded-xl ${txForm.toBranch ? 'bg-purple-100 text-purple-700' : 'bg-gray-100 text-gray-400'}`}>
                  {txForm.toBranch || '—'}
                </span>
                {txForm.quantity && (
                  <span className="text-sm font-bold text-gray-700 dark:text-white">× {Number(txForm.quantity).toLocaleString()}</span>
                )}
                {txForm.pcsCount && (
                  <span className="text-xs bg-orange-50 text-orange-700 px-2 py-1 rounded-full font-medium">
                    {Number(txForm.pcsCount).toLocaleString()} pcs
                  </span>
                )}
              </div>
            )}
            <div className="flex justify-end gap-2 pt-1">
              <button onClick={() => { setShowAddTx(false); setTxForm(emptyTxForm()); }}
                className="btn-ghost text-sm py-1.5 px-4">Cancel</button>
              <Button onClick={handleSaveTransfer} loading={savingTx} size="sm">Save Transfer</Button>
            </div>
          </div>
        )}

        {/* History table */}
        {txLoading && !transfers.length ? (
          <div className="flex items-center justify-center py-10 gap-2 text-gray-400">
            <Loader2 className="animate-spin" size={18}/> Loading…
          </div>
        ) : transfers.length === 0 ? (
          <div className="text-center py-12 text-gray-400 text-sm">
            <ArrowLeftRight size={36} className="mx-auto mb-2 opacity-30"/>
            <p>No transfer records yet.</p>
            <p className="text-xs mt-1">Click &quot;Add Transfer&quot; to log the first one.</p>
          </div>
        ) : (
          <div className="overflow-x-auto rounded-xl border border-gray-100 dark:border-gray-800">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 dark:bg-gray-800/60 text-xs text-gray-500 uppercase tracking-wide">
                  <th className="text-left py-2.5 px-4 font-semibold">Route</th>
                  <th className="text-right py-2.5 px-3 font-semibold">Qty</th>
                  <th className="text-right py-2.5 px-3 font-semibold">Pcs</th>
                  <th className="text-right py-2.5 px-3 font-semibold">Weight</th>
                  <th className="text-left py-2.5 px-3 font-semibold">Date</th>
                  <th className="text-left py-2.5 px-3 font-semibold">By</th>
                  <th className="text-left py-2.5 px-3 font-semibold">Notes / Tags</th>
                </tr>
              </thead>
              <tbody>
                {transfers.map((tx, i) => (
                  <tr key={tx._id}
                    className={`border-t border-gray-100 dark:border-gray-800 ${i % 2 === 0 ? '' : 'bg-gray-50/40 dark:bg-gray-800/20'}`}>
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="text-xs font-semibold text-emerald-700 bg-emerald-50 dark:bg-emerald-900/30 px-2 py-1 rounded-lg">
                          {tx.fromBranch}
                        </span>
                        <ArrowRight size={12} className="text-gray-400"/>
                        <span className="text-xs font-semibold text-purple-700 bg-purple-50 dark:bg-purple-900/30 px-2 py-1 rounded-lg">
                          {tx.toBranch}
                        </span>
                      </div>
                    </td>
                    <td className="py-3 px-3 text-right tabular-nums font-semibold text-blue-600">
                      {tx.quantity.toLocaleString()}
                    </td>
                    <td className="py-3 px-3 text-right tabular-nums font-semibold text-orange-600">
                      {tx.pcsCount ? tx.pcsCount.toLocaleString() : <span className="text-gray-300">—</span>}
                    </td>
                    <td className="py-3 px-3 text-right tabular-nums text-amber-600 text-xs">
                      {tx.weightGram ? `${tx.weightGram} g/kg` : <span className="text-gray-300">—</span>}
                    </td>
                    <td className="py-3 px-3 text-gray-500 text-xs whitespace-nowrap">
                      <div className="flex items-center gap-1">
                        <CalendarDays size={11}/> {fmtDate(tx.date)}
                      </div>
                    </td>
                    <td className="py-3 px-3 text-gray-500 text-xs">
                      {tx.transferredBy ? (
                        <div className="flex items-center gap-1">
                          <User size={11}/> {tx.transferredBy}
                        </div>
                      ) : <span className="text-gray-300">—</span>}
                    </td>
                    <td className="py-3 px-3">
                      <div className="flex flex-col gap-1">
                        {tx.notes && (
                          <div className="flex items-center gap-1 text-xs text-gray-400">
                            <StickyNote size={10}/> {tx.notes}
                          </div>
                        )}
                        {tx.tags && tx.tags.length > 0 && (
                          <div className="flex flex-wrap gap-1">
                            {tx.tags.map((tag, ti) => (
                              <span key={ti} className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${tagColor(tag)}`}>
                                <Tag size={7} className="inline mr-0.5"/>{tag}
                              </span>
                            ))}
                          </div>
                        )}
                        {!tx.notes && (!tx.tags || !tx.tags.length) && (
                          <span className="text-gray-300 text-xs">—</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
              {/* Footer totals */}
              <tfoot>
                <tr className="bg-purple-600 text-white text-sm font-bold">
                  <td className="py-2.5 px-4">Total ({transfers.length} transfers)</td>
                  <td className="py-2.5 px-3 text-right tabular-nums">{totalTxQty.toLocaleString()}</td>
                  <td className="py-2.5 px-3 text-right tabular-nums">{totalTxPcs ? totalTxPcs.toLocaleString() : '—'}</td>
                  <td className="py-2.5 px-3"/>
                  <td className="py-2.5 px-3"/>
                  <td className="py-2.5 px-3"/>
                  <td className="py-2.5 px-3"/>
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </div>

      {/* ══ Edit Record Modal ══ */}
      <Modal
        open={showEdit}
        onClose={() => setShowEdit(false)}
        title={
          <span className="flex items-center gap-2">
            <FlaskConical size={16} className="text-purple-500"/>
            Edit: {row.productName} {row.packSize}
          </span>
        }
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowEdit(false)}>Cancel</Button>
            <Button onClick={handleEditSave} loading={savingEdit}>Save Changes</Button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          {[
            { key: 'productName',       label: 'Product Name',            type: 'text'   },
            { key: 'packSize',          label: 'Pack Size',               type: 'text'   },
            { key: 'zone',              label: 'Zone',                    type: 'text'   },
            { key: 'previousBalanceKg', label: 'Prev Balance (Kg/L)',     type: 'number' },
            { key: 'receivedKg',        label: 'Received (Kg/L)',         type: 'number' },
            { key: 'totalKg',           label: 'Total (Kg/L)',            type: 'number' },
            { key: 'totalProductPcs',   label: 'Transfer Qty (Pcs)',      type: 'number' },
            { key: 'pcsTransfer',       label: 'Pcs Transfer',            type: 'number' },
            { key: 'convertKg',         label: 'Convert (Kg/L)',          type: 'number' },
            { key: 'totalConvertKg',    label: 'Total Convert (Kg/L)',    type: 'number' },
            { key: 'wastageKg',         label: 'Wastage (Kg/L)',          type: 'number' },
            { key: 'presentBalanceKg',  label: 'Present Balance (Kg/L)', type: 'number' },
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
      </Modal>
    </div>
  );
}
