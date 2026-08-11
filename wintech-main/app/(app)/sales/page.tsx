'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Search, ShoppingCart, Loader2, Eye, CheckCircle, Clock, DollarSign, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import Link from 'next/link';
import { useAuthStore, useBranchStore } from '@/lib/store';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { formatDate } from '@/lib/utils';

interface SaleDetail { productName?: string; quantity: number; rate: number; discount?: number; totalAmount: number; }
interface SaleMaster {
  _id: string; invoiceNo: string; partyName?: string; saleDate: string;
  branchId?: number; branchName?: string;
  paymentType?: string; totalAmount: number; discountAmount: number; taxAmount: number;
  subTotal: number; paidAmount: number; dueAmount: number; previousDue?: number;
  status: string; isOrder?: string; details?: SaleDetail[];
}

type TabType = 'approved' | 'pending';

export default function SalesPage() {
  const { user } = useAuthStore();
  const { selectedBranchLegacyId } = useBranchStore();
  const [tab, setTab] = useState<TabType>('approved');
  const [sales, setSales] = useState<SaleMaster[]>([]);
  const [pendingOrders, setPendingOrders] = useState<SaleMaster[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [viewSale, setViewSale] = useState<SaleMaster | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [approving, setApproving] = useState<string | null>(null);
  const [branches, setBranches] = useState<{ _id: string; name: string; legacyId?: number }[]>([]);
  const [branchFilter, setBranchFilter] = useState('');

  useEffect(() => {
    fetch('/api/branches').then(r => r.json()).then(d => setBranches(d.data || [])).catch(() => setBranches([]));
  }, []);

  const fetchSales = useCallback(async () => {
    setLoading(true);
    try {
      const [approvedRes, pendingRes] = await Promise.all([
        fetch(`/api/sales?search=${encodeURIComponent(search)}&limit=100&status=a${branchFilter ? `&branchId=${branchFilter}` : selectedBranchLegacyId ? `&branchId=${selectedBranchLegacyId}` : ''}`),
        fetch(`/api/sales?search=${encodeURIComponent(search)}&limit=100&status=pending${branchFilter ? `&branchId=${branchFilter}` : selectedBranchLegacyId ? `&branchId=${selectedBranchLegacyId}` : ''}`),
      ]);
      const approvedData = approvedRes.ok ? await approvedRes.json() : { data: [], total: 0 };
      const pendingData = pendingRes.ok ? await pendingRes.json() : { data: [] };
      setSales(approvedData.data || []);
      setTotal(approvedData.total || 0);
      setPendingOrders(pendingData.data || []);
    } catch { toast.error('Could not load orders'); } finally { setLoading(false); }
  }, [search, selectedBranchLegacyId, branchFilter]);

  useEffect(() => { fetchSales(); }, [fetchSales]);

  const openView = async (s: SaleMaster) => {
    setViewSale(s); setLoadingDetail(true);
    try {
      const r = await fetch(`/api/sales/${s._id}`);
      const d = await r.json(); setViewSale(d);
    } catch { } finally { setLoadingDetail(false); }
  };

  const handleDelete = async (s: SaleMaster) => {
    if (!confirm(`Delete invoice ${s.invoiceNo}?`)) return;
    await fetch(`/api/sales/${s._id}`, { method: 'DELETE' });
    toast.success('Deleted'); fetchSales();
  };

  const handleApprove = async (id: string, invoiceNo: string) => {
    if (!confirm(`Approve order ${invoiceNo} and convert to confirmed sale?`)) return;
    setApproving(id);
    try {
      const res = await fetch(`/api/sales/${id}/approve`, { method: 'POST' });
      if (!res.ok) throw new Error('Failed');
      toast.success(`Order ${invoiceNo} approved!`);
      fetchSales();
    } catch { toast.error('Approval failed'); } finally { setApproving(null); }
  };

  const displayedSales = tab === 'approved' ? sales : pendingOrders;
  const totalSales = sales.reduce((a, s) => a + s.subTotal, 0);
  const totalDue = sales.reduce((a, s) => a + s.dueAmount, 0);
  const totalPaid = sales.reduce((a, s) => a + s.paidAmount, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Sale Orders" subtitle={`${total} confirmed orders`}
        actions={<Link href="/sales/orders-entry" className="btn-primary inline-flex items-center gap-2"><ShoppingCart size={15} /> New Order</Link>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Orders', value: total, color: 'blue' },
          { label: 'Total Sales', value: `৳${totalSales.toLocaleString()}`, color: 'emerald' },
          { label: 'Collected', value: `৳${totalPaid.toLocaleString()}`, color: 'purple' },
          { label: 'Due', value: `৳${totalDue.toLocaleString()}`, color: 'red' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="flex gap-1 mb-4 bg-gray-100 dark:bg-gray-800 rounded-xl p-1 w-fit">
          <button onClick={() => setTab('approved')} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${tab === 'approved' ? 'bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 shadow-sm' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'}`}>
            <CheckCircle size={12} /> Approved Sales <span className="bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400 rounded-full px-1.5 text-[10px]">{sales.length}</span>
          </button>
          <button onClick={() => setTab('pending')} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${tab === 'pending' ? 'bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 shadow-sm' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'}`}>
            <Clock size={12} /> Pending Orders {pendingOrders.length > 0 && <span className="bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 rounded-full px-1.5 text-[10px]">{pendingOrders.length}</span>}
          </button>
        </div>

        {tab === 'pending' && pendingOrders.length > 0 && user?.role === 'admin' && (
          <div className="mb-3 p-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl text-xs text-amber-700 dark:text-amber-400 flex items-center gap-2">
            <Clock size={14} />
            <span>{pendingOrders.length} orders awaiting your approval. Click the ✓ button to approve and convert to confirmed sale.</span>
          </div>
        )}

        <div className="section-header">
          <div className="flex flex-wrap items-center gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search by invoice / party..." className="form-input pl-9 w-72" />
            </div>
            <select value={branchFilter} onChange={e => setBranchFilter(e.target.value)} className="form-input w-44">
              <option value="">All Branches</option>
              {branches.map(branch => (
                <option key={branch._id} value={branch.legacyId ?? ''} disabled={branch.legacyId == null}>
                  {branch.name}{branch.legacyId == null ? ' (no ID)' : ''}
                </option>
              ))}
            </select>
          </div>
          <span className="text-sm text-gray-400">{displayedSales.length} shown</span>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} />Loading...</div>
        ) : displayedSales.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <ShoppingCart size={40} className="mx-auto mb-3 opacity-30" />
            <p className="font-medium">{tab === 'pending' ? 'No pending orders' : 'No sale orders yet'}</p>
            {tab === 'approved' && <p className="text-xs mt-2"><Link href="/sales/orders-entry" className="text-blue-500 hover:underline">Create a new order →</Link></p>}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                  {['Invoice No','Party','Branch','Date','Payment','Sub Total','Paid','Due','Status','Actions'].map(h => (
                    <th key={h} className={`py-3 pr-3 font-medium ${['Sub Total','Paid','Due','Actions'].includes(h) ? 'text-right' : h === 'Status' ? 'text-center' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {displayedSales.map(s => (
                  <tr key={s._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-3 pr-3 font-mono text-xs text-blue-600 dark:text-blue-400 font-medium">{s.invoiceNo}</td>
                    <td className="py-3 pr-3 font-medium text-gray-900 dark:text-white">{s.partyName || '—'}</td>
                    <td className="py-3 pr-3 text-gray-500 text-xs">{s.branchName || '—'}</td>
                    <td className="py-3 pr-3 text-gray-500 text-xs">{formatDate(s.saleDate)}</td>
                    <td className="py-3 pr-3 text-gray-500 text-xs">{s.paymentType || '—'}</td>
                    <td className="py-3 pr-3 text-right font-semibold">৳{s.subTotal.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-right text-emerald-600 font-medium">৳{s.paidAmount.toLocaleString()}</td>
                    <td className={`py-3 pr-3 text-right font-medium ${s.dueAmount > 0 ? 'text-red-500' : 'text-gray-400'}`}>৳{s.dueAmount.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-center">
                      {s.status === 'pending'
                        ? <span className="badge badge-yellow">Pending</span>
                        : <span className="badge badge-green">Approved</span>
                      }
                    </td>
                    <td className="py-3 text-right">
                      <div className="flex items-center justify-end gap-1">
                        {s.status === 'pending' && user?.role === 'admin' && (
                          <button onClick={() => handleApprove(s._id, s.invoiceNo)} disabled={approving === s._id}
                            className="text-emerald-500 hover:text-emerald-700 p-1.5 rounded hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-colors" title="Approve">
                            {approving === s._id ? <Loader2 size={14} className="animate-spin" /> : <CheckCircle size={14} />}
                          </button>
                        )}
                        <Link href={`/sales/${s._id}`} className="icon-btn text-blue-400 hover:text-blue-600" title="View Detail"><Eye size={14} /></Link>
                        <button onClick={() => handleDelete(s)} className="icon-btn text-red-400 hover:text-red-600" title="Delete"><Trash2 size={14} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        open={!!viewSale}
        onClose={() => setViewSale(null)}
        title={viewSale?.invoiceNo || ''}
        size="lg"
        footer={<Button variant="outline" onClick={() => setViewSale(null)}>Close</Button>}
      >
        {viewSale && (
          <>
            <p className="text-xs text-slate-500 -mt-2 mb-4">{viewSale.partyName} · {formatDate(viewSale.saleDate)}</p>
            {loadingDetail
              ? <div className="text-center py-8 text-gray-400"><Loader2 className="animate-spin mx-auto" size={24} /></div>
              : (
                <>
                  {viewSale.details && viewSale.details.length > 0 && (
                    <div className="mb-4">
                      <h3 className="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-2">Items</h3>
                      <div className="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-700">
                        <table className="w-full text-xs">
                          <thead className="bg-slate-50 dark:bg-slate-800">
                            <tr className="text-slate-500">
                              <th className="text-left px-3 py-2">Product</th>
                              <th className="text-center px-3 py-2">Qty</th>
                              <th className="text-right px-3 py-2">Rate</th>
                              <th className="text-right px-3 py-2">Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            {viewSale.details.map((d, i) => (
                              <tr key={i} className="border-t border-slate-100 dark:border-slate-700">
                                <td className="px-3 py-2 font-medium">{d.productName}</td>
                                <td className="px-3 py-2 text-center">{d.quantity}</td>
                                <td className="px-3 py-2 text-right">৳{d.rate.toLocaleString()}</td>
                                <td className="px-3 py-2 text-right font-semibold">৳{d.totalAmount.toLocaleString()}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}
                  <div className="grid grid-cols-2 gap-3 text-sm border-t border-slate-100 dark:border-slate-700 pt-3">
                    {[
                      { label: 'Total Amount', value: `৳${viewSale.totalAmount.toLocaleString()}` },
                      { label: 'Commission', value: `-৳${viewSale.discountAmount.toLocaleString()}` },
                      { label: 'Sub Total', value: `৳${viewSale.subTotal.toLocaleString()}`, bold: true },
                      { label: 'Paid', value: `৳${viewSale.paidAmount.toLocaleString()}`, color: 'text-emerald-600' },
                      { label: 'Due', value: `৳${viewSale.dueAmount.toLocaleString()}`, color: 'text-red-500' },
                    ].map(r => (
                      <div key={r.label} className="flex justify-between py-1.5 border-b border-slate-100 dark:border-slate-800">
                        <span className="text-slate-500">{r.label}</span>
                        <span className={`font-medium ${r.color || ''} ${r.bold ? 'font-bold text-slate-800 dark:text-white' : ''}`}>{r.value}</span>
                      </div>
                    ))}
                  </div>
                </>
              )
            }
          </>
        )}
      </Modal>
    </div>
  );
}
