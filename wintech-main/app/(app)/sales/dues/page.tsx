'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Search, Loader2, MapPin, TrendingDown, TrendingUp, Banknote, Users, X, BarChart2, ArrowLeft } from 'lucide-react';
import toast from 'react-hot-toast';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
  LineChart, Line, Area, AreaChart,
} from 'recharts';

const MONTH_SHORT = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const MONTH_NAMES = ['','January','February','March','April','May','June','July','August','September','October','November','December'];

interface DuesRow {
  _id: string; zone: string; partyName: string; invoiceNos?: string;
  previousDue: number; totalSales: number; commission: number;
  collectionAmount: number; mrNo?: string; cheque?: string;
  returnGoods: number; totalDues: number;
}
interface Period { _id: { year: number; month: number }; count: number; }
interface ZoneSummary {
  _id: string; totalPreviousDue: number; totalSales: number;
  totalCollection: number; totalDues: number; partyCount: number;
}
interface TrendPoint {
  _id: { year: number; month: number };
  totalPreviousDue: number; totalSales: number; totalCollection: number;
  totalDues: number; totalCommission: number; partyCount: number;
}

const fmt = (n: number) => '৳' + Math.round(n).toLocaleString('en-BD');
const fmtK = (n: number) => n >= 1e6 ? `৳${(n/1e6).toFixed(1)}M` : n >= 1e3 ? `৳${(n/1e3).toFixed(0)}K` : `৳${n}`;

function CustomTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ name: string; value: number; color: string }>; label?: string }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-gray-900 text-white rounded-xl p-3 shadow-xl text-xs min-w-[160px]">
      <p className="font-bold mb-1.5 text-gray-300">{label}</p>
      {payload.map(p => (
        <div key={p.name} className="flex justify-between gap-4 py-0.5">
          <span style={{ color: p.color }}>{p.name}</span>
          <span className="font-mono font-bold">{fmt(p.value)}</span>
        </div>
      ))}
    </div>
  );
}

export default function SalesDuesPage() {
  const [periods, setPeriods]           = useState<Period[]>([]);
  const [zones, setZones]               = useState<string[]>([]);
  const [zoneSummary, setZoneSummary]   = useState<ZoneSummary[]>([]);
  const [selYear, setSelYear]           = useState('');
  const [selMonth, setSelMonth]         = useState('');
  const [selZone, setSelZone]           = useState('');
  const [search, setSearch]             = useState('');
  const [data, setData]                 = useState<DuesRow[]>([]);
  const [loading, setLoading]           = useState(false);
  const [trendData, setTrendData]       = useState<TrendPoint[]>([]);
  const [trendLoading, setTrendLoading] = useState(false);
  const [view, setView]                 = useState<'overview' | 'detail'>('overview');

  // Fetch meta (periods, zones) + trend on mount
  const fetchMeta = useCallback(async () => {
    try {
      const [metaR, trendR] = await Promise.all([
        fetch('/api/sales-dues?year=2000&month=1'),
        fetch('/api/sales-dues/trend'),
      ]);
      const meta = await metaR.json();
      const trend = await trendR.json();
      setPeriods(meta.periods || []);
      setZones(meta.zones || []);
      setTrendData(trend.monthly || []);
      if (meta.periods?.length) {
        setSelYear(String(meta.periods[0]._id.year));
        setSelMonth(String(meta.periods[0]._id.month));
      }
    } catch { /* ignore */ }
  }, []);

  useEffect(() => { fetchMeta(); }, [fetchMeta]);

  // Fetch monthly detail + zone summary
  const fetchData = useCallback(async () => {
    if (!selYear || !selMonth) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ year: selYear, month: selMonth, search });
      if (selZone) params.set('zone', selZone);
      const r = await fetch(`/api/sales-dues?${params}`);
      const d = await r.json();
      setData(d.data || []);
      setZoneSummary(d.zoneSummary || []);
    } catch { toast.error('Failed to load'); setData([]); }
    finally { setLoading(false); }
  }, [selYear, selMonth, selZone, search]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Refresh trend when zone filter changes
  const fetchTrend = useCallback(async () => {
    setTrendLoading(true);
    try {
      const params = new URLSearchParams();
      if (selZone) params.set('zone', selZone);
      if (selYear) params.set('year', selYear);
      const r = await fetch(`/api/sales-dues/trend?${params}`);
      const d = await r.json();
      setTrendData(d.monthly || []);
    } finally { setTrendLoading(false); }
  }, [selZone, selYear]);

  useEffect(() => { fetchTrend(); }, [fetchTrend]);

  const uniqueYears = [...new Set(periods.map(p => p._id.year))].sort((a, b) => b - a);
  const monthsForYear = periods.filter(p => p._id.year === parseInt(selYear)).map(p => p._id.month).sort((a, b) => a - b);

  const totalPrevDue    = data.reduce((s, r) => s + r.previousDue, 0);
  const totalSales      = data.reduce((s, r) => s + r.totalSales, 0);
  const totalCollection = data.reduce((s, r) => s + r.collectionAmount, 0);
  const totalDues       = data.reduce((s, r) => s + r.totalDues, 0);

  const collectionRate = totalSales > 0 ? Math.round((totalCollection / (totalPrevDue + totalSales)) * 100) : 0;

  // Build chart data
  const chartTrend = trendData.map(t => ({
    name: `${MONTH_SHORT[t._id.month]} '${String(t._id.year).slice(2)}`,
    Sales: t.totalSales,
    Collection: t.totalCollection,
    'Outstanding Due': t.totalDues,
    Parties: t.partyCount,
    year: t._id.year, month: t._id.month,
  }));

  // Zone bar data for current month
  const zoneBarsData = zoneSummary.slice(0, 10).map(z => ({
    name: z._id.length > 10 ? z._id.slice(0, 10) + '…' : z._id,
    fullName: z._id,
    Sales: z.totalSales,
    Collection: z.totalCollection,
    Due: z.totalDues,
  }));

  return (
    <div className="page-wrapper">
      <Topbar
        title="Sales Dues Dashboard"
        subtitle={selZone ? `Branch: ${selZone}` : 'All branches — monthly collection analytics'}
        actions={
          selZone ? (
            <button onClick={() => { setSelZone(''); setView('overview'); }}
              className="btn-secondary flex items-center gap-1.5 text-sm">
              <ArrowLeft size={14} /> All Branches
            </button>
          ) : null
        }
      />

      {/* ── Filters ─────────────────────────────────────────────────── */}
      <div className="card">
        <div className="flex flex-wrap gap-3 items-center">
          <select value={selYear} onChange={e => { setSelYear(e.target.value); setSelMonth(''); }}
            className="form-input w-28 text-sm py-2">
            <option value="">Year</option>
            {uniqueYears.map(y => <option key={y} value={y}>{y}</option>)}
          </select>
          <select value={selMonth} onChange={e => setSelMonth(e.target.value)}
            className="form-input w-36 text-sm py-2">
            <option value="">Month</option>
            {monthsForYear.map(m => <option key={m} value={m}>{MONTH_NAMES[m]}</option>)}
          </select>
          {selZone ? (
            <div className="flex items-center gap-2 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded-xl px-3 py-2 text-sm font-medium">
              <MapPin size={13} /> {selZone}
              <button onClick={() => setSelZone('')} className="ml-1 hover:text-red-500"><X size={13} /></button>
            </div>
          ) : (
            <select value={selZone} onChange={e => setSelZone(e.target.value)}
              className="form-input w-40 text-sm py-2">
              <option value="">All Branches</option>
              {zones.map(z => <option key={z} value={z}>{z}</option>)}
            </select>
          )}
          <div className="relative flex-1 min-w-[180px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={14} />
            <input value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search party…" className="form-input pl-9 w-full text-sm py-2" />
          </div>
          <div className="flex rounded-xl overflow-hidden border border-gray-200 dark:border-gray-700">
            <button onClick={() => setView('overview')}
              className={`px-3 py-2 text-xs font-medium flex items-center gap-1.5 transition-colors ${view === 'overview' ? 'bg-blue-600 text-white' : 'text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
              <BarChart2 size={13} /> Overview
            </button>
            <button onClick={() => setView('detail')}
              className={`px-3 py-2 text-xs font-medium flex items-center gap-1.5 transition-colors ${view === 'detail' ? 'bg-blue-600 text-white' : 'text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
              <Users size={13} /> Parties
            </button>
          </div>
        </div>
      </div>

      {/* ── KPI cards ───────────────────────────────────────────────── */}
      {(data.length > 0 || trendData.length > 0) && (
        <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
          {[
            { label: 'Prev. Due', value: fmt(totalPrevDue), icon: TrendingDown, color: 'amber', sub: `${data.length} parties` },
            { label: 'Total Sales', value: fmt(totalSales), icon: TrendingUp, color: 'emerald', sub: MONTH_NAMES[parseInt(selMonth)] || '' },
            { label: 'Collection', value: fmt(totalCollection), icon: Banknote, color: 'blue', sub: `${collectionRate}% rate` },
            { label: 'Outstanding', value: fmt(totalDues), icon: TrendingDown, color: 'red', sub: 'total dues' },
            { label: 'Branches', value: String(zoneSummary.length), icon: MapPin, color: 'purple', sub: 'zones active' },
          ].map(s => (
            <div key={s.label} className="card flex items-center gap-3 py-3">
              <div className={`w-9 h-9 rounded-xl bg-${s.color}-100 dark:bg-${s.color}-900/30 flex items-center justify-center flex-shrink-0`}>
                <s.icon size={16} className={`text-${s.color}-600 dark:text-${s.color}-400`} />
              </div>
              <div className="min-w-0">
                <p className={`text-base font-bold text-${s.color}-700 dark:text-${s.color}-400 leading-tight truncate`}>{s.value}</p>
                <p className="text-[10px] text-gray-400 leading-tight">{s.label}</p>
                <p className="text-[10px] text-gray-400 leading-tight">{s.sub}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ── Overview view ───────────────────────────────────────────── */}
      {view === 'overview' && (
        <>
          {/* Monthly trend chart */}
          {chartTrend.length > 0 && (
            <div className="card">
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-semibold text-gray-800 dark:text-white text-sm">
                  Monthly Collection Trend {selZone ? `— ${selZone}` : '(All Branches)'}
                </h3>
                {trendLoading && <Loader2 size={14} className="animate-spin text-gray-400" />}
              </div>
              <ResponsiveContainer width="100%" height={260}>
                <AreaChart data={chartTrend} margin={{ top: 5, right: 20, left: 10, bottom: 5 }}>
                  <defs>
                    <linearGradient id="gSales" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="gCollection" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="gDue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" strokeOpacity={0.5} />
                  <XAxis dataKey="name" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                  <YAxis tickFormatter={fmtK} tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} width={60} />
                  <Tooltip content={<CustomTooltip />} />
                  <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: '11px' }} />
                  <Area type="monotone" dataKey="Sales" stroke="#10b981" strokeWidth={2} fill="url(#gSales)" dot={{ r: 3, fill: '#10b981' }} activeDot={{ r: 5 }} />
                  <Area type="monotone" dataKey="Collection" stroke="#3b82f6" strokeWidth={2} fill="url(#gCollection)" dot={{ r: 3, fill: '#3b82f6' }} activeDot={{ r: 5 }} />
                  <Area type="monotone" dataKey="Outstanding Due" stroke="#ef4444" strokeWidth={2} fill="url(#gDue)" dot={{ r: 3, fill: '#ef4444' }} activeDot={{ r: 5 }} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}

          <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
            {/* Branch comparison bar chart for current month */}
            {zoneBarsData.length > 0 && (
              <div className="card">
                <h3 className="font-semibold text-gray-800 dark:text-white text-sm mb-4">
                  Branch Comparison — {MONTH_NAMES[parseInt(selMonth)] || 'Month'} {selYear}
                </h3>
                <ResponsiveContainer width="100%" height={260}>
                  <BarChart data={zoneBarsData} margin={{ top: 5, right: 10, left: 10, bottom: 40 }} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" strokeOpacity={0.4} horizontal={false} />
                    <XAxis type="number" tickFormatter={fmtK} tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                    <YAxis type="category" dataKey="name" tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} width={80} />
                    <Tooltip content={<CustomTooltip />} />
                    <Legend iconType="square" iconSize={8} wrapperStyle={{ fontSize: '11px' }} />
                    <Bar dataKey="Sales" fill="#10b981" radius={[0, 4, 4, 0]} maxBarSize={12} />
                    <Bar dataKey="Collection" fill="#3b82f6" radius={[0, 4, 4, 0]} maxBarSize={12} />
                    <Bar dataKey="Due" fill="#ef4444" radius={[0, 4, 4, 0]} maxBarSize={12} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Zone summary table */}
            {!selZone && zoneSummary.length > 0 && (
              <div className="card p-0 overflow-hidden">
                <div className="px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
                  <h3 className="font-semibold text-gray-800 dark:text-white text-sm flex items-center gap-2">
                    <MapPin size={14} /> Branch Summary
                  </h3>
                  <span className="text-xs text-gray-400">{MONTH_NAMES[parseInt(selMonth)]} {selYear}</span>
                </div>
                <div className="overflow-y-auto max-h-[260px]">
                  <table className="w-full text-xs">
                    <thead className="sticky top-0 bg-gray-50 dark:bg-gray-900">
                      <tr className="text-gray-500 dark:text-gray-400">
                        <th className="text-left py-2.5 px-4 font-medium">Branch</th>
                        <th className="text-right py-2.5 px-3 font-medium">Sales</th>
                        <th className="text-right py-2.5 px-3 font-medium">Collected</th>
                        <th className="text-right py-2.5 px-4 font-medium text-red-500">Due</th>
                      </tr>
                    </thead>
                    <tbody>
                      {zoneSummary.map(z => (
                        <tr key={z._id} className="border-t border-gray-100 dark:border-gray-800 hover:bg-blue-50 dark:hover:bg-blue-900/20 cursor-pointer transition-colors"
                          onClick={() => setSelZone(z._id)}>
                          <td className="py-2.5 px-4">
                            <p className="font-medium text-blue-600 dark:text-blue-400">{z._id}</p>
                            <p className="text-gray-400">{z.partyCount} parties</p>
                          </td>
                          <td className="py-2.5 px-3 text-right tabular-nums text-emerald-600 font-medium">{fmtK(z.totalSales)}</td>
                          <td className="py-2.5 px-3 text-right tabular-nums text-blue-600 font-medium">{fmtK(z.totalCollection)}</td>
                          <td className="py-2.5 px-4 text-right tabular-nums font-bold text-red-600">{fmtK(z.totalDues)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </div>
        </>
      )}

      {/* ── Empty state ─────────────────────────────────────────────── */}
      {!loading && data.length === 0 && periods.length === 0 && (
        <div className="card text-center py-20">
          <Banknote size={48} className="mx-auto mb-3 text-gray-300" />
          <p className="font-semibold text-gray-600 dark:text-gray-300">No dues data yet</p>
          <p className="text-sm text-gray-400 mt-1">Run <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">node scripts/json-to-mongo.js</code> to import monthly XLS data</p>
        </div>
      )}

      {/* ── Detail table (Parties view) ─────────────────────────────── */}
      {view === 'detail' && (
        <div className="card overflow-hidden p-0">
          <div className="px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
            <h3 className="font-semibold text-gray-800 dark:text-white text-sm">
              Party-wise Dues — {MONTH_NAMES[parseInt(selMonth)]} {selYear}
              {selZone && <span className="ml-2 text-blue-500">{selZone}</span>}
            </h3>
            <span className="text-xs text-gray-400">{data.length} parties</span>
          </div>
          {loading ? (
            <div className="flex items-center justify-center py-16 gap-2 text-gray-400">
              <Loader2 className="animate-spin" size={20} /> Loading…
            </div>
          ) : data.length === 0 ? (
            <div className="text-center py-16 text-gray-400">
              <Users size={36} className="mx-auto mb-2 opacity-30" />
              <p>No party data for this selection</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 dark:bg-gray-800 text-xs text-gray-500 dark:text-gray-400">
                    <th className="text-left py-3 px-4 font-medium">Party Name</th>
                    <th className="text-left py-3 px-3 font-medium">Branch</th>
                    <th className="text-left py-3 px-3 font-medium">Inv. No</th>
                    <th className="text-right py-3 px-3 font-medium">Prev Due</th>
                    <th className="text-right py-3 px-3 font-medium">Sales</th>
                    <th className="text-right py-3 px-3 font-medium">Collection</th>
                    <th className="text-right py-3 px-3 font-medium">Return</th>
                    <th className="text-right py-3 px-4 font-medium text-red-600">Total Due</th>
                  </tr>
                </thead>
                <tbody>
                  {data.map((r, i) => (
                    <tr key={r._id}
                      className={`border-b border-gray-100 dark:border-gray-800 ${i % 2 === 0 ? '' : 'bg-gray-50/40 dark:bg-gray-800/20'}`}>
                      <td className="py-2.5 px-4 font-medium text-gray-900 dark:text-white">{r.partyName}</td>
                      <td className="py-2.5 px-3">
                        <button onClick={() => setSelZone(r.zone)}
                          className="badge badge-blue text-xs hover:opacity-80">{r.zone}</button>
                      </td>
                      <td className="py-2.5 px-3 text-gray-500 text-xs font-mono">{r.invoiceNos || '—'}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums text-amber-600">{r.previousDue > 0 ? fmt(r.previousDue) : '—'}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums text-emerald-600">{r.totalSales > 0 ? fmt(r.totalSales) : '—'}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums text-blue-600">{r.collectionAmount > 0 ? fmt(r.collectionAmount) : '—'}</td>
                      <td className="py-2.5 px-3 text-right tabular-nums">{r.returnGoods > 0 ? fmt(r.returnGoods) : '—'}</td>
                      <td className={`py-2.5 px-4 text-right tabular-nums font-bold ${r.totalDues > 0 ? 'text-red-600' : 'text-emerald-600'}`}>
                        {fmt(r.totalDues)}
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="bg-gray-800 dark:bg-gray-900 text-white text-sm font-bold">
                    <td className="py-3 px-4" colSpan={3}>Total ({data.length} parties)</td>
                    <td className="py-3 px-3 text-right tabular-nums text-amber-300">{fmt(totalPrevDue)}</td>
                    <td className="py-3 px-3 text-right tabular-nums text-emerald-300">{fmt(totalSales)}</td>
                    <td className="py-3 px-3 text-right tabular-nums text-blue-300">{fmt(totalCollection)}</td>
                    <td className="py-3 px-3 text-right tabular-nums">—</td>
                    <td className="py-3 px-4 text-right tabular-nums text-red-300">{fmt(totalDues)}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
