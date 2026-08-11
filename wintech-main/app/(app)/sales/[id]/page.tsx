'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Topbar from '@/components/layout/Topbar';
import { formatDate } from '@/lib/utils';
import Link from 'next/link';
import {
  ArrowLeft, Package, User, Calendar, CreditCard, FileText,
  CheckCircle2, Clock, Printer, Percent, TrendingDown, Loader2,
  BadgeDollarSign, AlertCircle
} from 'lucide-react';

interface SaleDetail {
  productId?: string; productName?: string; quantity: number;
  rate: number; discount?: number; tax?: number; totalAmount: number;
}
interface Sale {
  _id: string; invoiceNo: string; partyName?: string; partyId?: string;
  saleDate: string; paymentType?: string; description?: string;
  totalAmount: number; discountAmount: number; commissionPct?: number;
  taxAmount: number; subTotal: number; paidAmount: number; dueAmount: number;
  previousDue?: number; status: string; isOrder?: string;
  details?: SaleDetail[];
  createdAt?: string;
}

function fmt(n: number) { return `৳${Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`; }
function fmtDate(d: string) { return formatDate(d); }

export default function SaleDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [sale, setSale] = useState<Sale | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(`/api/sales/${id}`)
      .then(r => r.ok ? r.json() : Promise.reject('Not found'))
      .then(setSale)
      .catch(() => setError('Sale not found'))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return (
    <div className="page-wrapper">
      <div className="flex items-center justify-center py-32 gap-3 text-gray-400">
        <Loader2 size={22} className="animate-spin" /> Loading sale…
      </div>
    </div>
  );

  if (error || !sale) return (
    <div className="page-wrapper">
      <div className="card text-center py-20 text-gray-400">
        <AlertCircle size={40} className="mx-auto mb-3 opacity-30" />
        <p className="font-semibold text-gray-600 dark:text-gray-300">Sale record not found</p>
        <Link href="/sales" className="text-blue-500 text-sm mt-3 inline-block">← Back to Sales</Link>
      </div>
    </div>
  );

  const isApproved = sale.status === 'a';
  const isPending  = sale.status === 'pending';

  return (
    <div className="page-wrapper">
      <Topbar
        title={sale.invoiceNo}
        subtitle={`${sale.partyName || 'No party'} · ${fmtDate(sale.saleDate)}`}
        actions={
          <div className="flex items-center gap-2">
            <button onClick={() => window.print()} className="btn-secondary text-xs py-2 px-3 gap-1.5 print:hidden">
              <Printer size={13} /> Print
            </button>
            <button onClick={() => router.back()} className="btn-secondary text-xs py-2 px-3 gap-1.5 print:hidden">
              <ArrowLeft size={13} /> Back
            </button>
          </div>
        }
      />

      {/* Status banner */}
      <div className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-semibold border ${
        isApproved
          ? 'bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-700/40 text-emerald-700 dark:text-emerald-400'
          : 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-700/40 text-amber-700 dark:text-amber-400'
      }`}>
        {isApproved ? <CheckCircle2 size={14} /> : <Clock size={14} />}
        {isApproved ? 'Approved Sale' : 'Pending Approval'}
        {sale.isOrder === 'Y' && <span className="ml-2 px-2 py-0.5 bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 rounded-full text-[10px]">Order</span>}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-4 items-start">

        {/* ── LEFT ── */}
        <div className="space-y-4">

          {/* Invoice Header */}
          <div className="card p-6 print:shadow-none">
            <div className="flex items-start justify-between mb-6 pb-5 border-b border-gray-100 dark:border-gray-700">
              <div>
                <p className="text-[10px] font-semibold uppercase tracking-widest text-gray-400 mb-1">Invoice</p>
                <p className="text-2xl font-black text-gray-900 dark:text-white font-mono">{sale.invoiceNo}</p>
              </div>
              <div className="text-right">
                <p className="text-[10px] font-semibold uppercase tracking-widest text-gray-400 mb-1">Date</p>
                <p className="text-base font-bold text-gray-800 dark:text-gray-200">{fmtDate(sale.saleDate)}</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {[
                { icon: User, label: 'Party / Customer', value: sale.partyName || '—' },
                { icon: CreditCard, label: 'Payment Method', value: sale.paymentType || '—' },
                { icon: FileText, label: 'Notes', value: sale.description || '—' },
              ].map(({ icon: Icon, label, value }) => (
                <div key={label} className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-800/60 rounded-xl">
                  <div className="w-8 h-8 bg-white dark:bg-gray-700 rounded-lg flex items-center justify-center shadow-sm flex-shrink-0 mt-0.5">
                    <Icon size={14} className="text-blue-500" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-[10px] text-gray-400 font-medium mb-0.5">{label}</p>
                    <p className="text-sm font-semibold text-gray-800 dark:text-white truncate">{value}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Items Table */}
          <div className="card p-0 overflow-hidden">
            <div className="flex items-center gap-2 p-5 border-b border-gray-100 dark:border-gray-700">
              <div className="w-7 h-7 rounded-lg bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center">
                <Package size={14} className="text-blue-600" />
              </div>
              <h3 className="font-bold text-sm text-gray-800 dark:text-white">Products</h3>
              {sale.details && (
                <span className="text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400 px-2 py-0.5 rounded-full font-semibold">
                  {sale.details.length} items
                </span>
              )}
            </div>
            {sale.details && sale.details.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50 dark:bg-gray-800/60 text-xs text-gray-500 font-semibold uppercase tracking-wide">
                      <th className="text-left px-5 py-3">#</th>
                      <th className="text-left px-5 py-3">Product</th>
                      <th className="text-center px-4 py-3">Qty</th>
                      <th className="text-right px-4 py-3">Rate (৳)</th>
                      {sale.details.some(d => (d.discount || 0) > 0) && <th className="text-right px-4 py-3">Disc %</th>}
                      <th className="text-right px-5 py-3">Amount (৳)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                    {sale.details.map((d, i) => (
                      <tr key={i} className="hover:bg-blue-50/30 dark:hover:bg-blue-900/10 transition-colors">
                        <td className="px-5 py-3 text-gray-400 text-xs">{i + 1}</td>
                        <td className="px-5 py-3">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 bg-blue-50 dark:bg-blue-900/20 rounded-lg flex items-center justify-center flex-shrink-0">
                              <Package size={11} className="text-blue-400" />
                            </div>
                            <span className="font-medium text-gray-800 dark:text-white">{d.productName || '—'}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-center font-semibold text-gray-700 dark:text-gray-300">{d.quantity}</td>
                        <td className="px-4 py-3 text-right text-gray-600 dark:text-gray-400 tabular-nums">{d.rate.toLocaleString()}</td>
                        {sale.details!.some(d => (d.discount || 0) > 0) && (
                          <td className="px-4 py-3 text-right text-red-400 text-xs">{d.discount ? `${d.discount}%` : '—'}</td>
                        )}
                        <td className="px-5 py-3 text-right font-bold text-gray-900 dark:text-white tabular-nums">{d.totalAmount.toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr className="bg-gray-50 dark:bg-gray-800/60 font-bold">
                      <td className="px-5 py-3 text-xs text-gray-400 uppercase" colSpan={2}>Total</td>
                      <td className="px-4 py-3 text-center text-gray-700 dark:text-gray-300">
                        {sale.details.reduce((a, d) => a + d.quantity, 0)}
                      </td>
                      <td colSpan={sale.details.some(d => (d.discount || 0) > 0) ? 2 : 1}></td>
                      <td className="px-5 py-3 text-right text-lg text-blue-600 dark:text-blue-400 tabular-nums">
                        {sale.details.reduce((a, d) => a + d.totalAmount, 0).toLocaleString()}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            ) : (
              <div className="text-center py-12 text-gray-400">
                <Package size={32} className="mx-auto mb-2 opacity-30" />
                <p className="text-sm">No line items recorded</p>
              </div>
            )}
          </div>
        </div>

        {/* ── RIGHT: Summary ── */}
        <div className="xl:sticky xl:top-4 space-y-4">

          {/* Financial Summary */}
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-7 h-7 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 flex items-center justify-center">
                <BadgeDollarSign size={14} className="text-emerald-600" />
              </div>
              <h3 className="font-bold text-sm text-gray-800 dark:text-white">Financial Summary</h3>
            </div>

            <div className="space-y-2.5 text-sm">
              <div className="flex justify-between text-gray-600 dark:text-gray-400">
                <span>Total Amount</span>
                <span className="font-semibold tabular-nums">{fmt(sale.totalAmount)}</span>
              </div>

              {sale.discountAmount > 0 && (
                <div className="flex justify-between text-red-500 dark:text-red-400">
                  <span className="flex items-center gap-1">
                    <Percent size={11} />
                    Commission {sale.commissionPct ? `(${sale.commissionPct}%)` : ''}
                  </span>
                  <span className="tabular-nums">−{fmt(sale.discountAmount)}</span>
                </div>
              )}

              {sale.taxAmount > 0 && (
                <div className="flex justify-between text-blue-500 dark:text-blue-400">
                  <span>Tax / VAT</span>
                  <span className="tabular-nums">+{fmt(sale.taxAmount)}</span>
                </div>
              )}

              <div className="border-t border-gray-100 dark:border-gray-700 pt-2.5 flex justify-between font-black text-lg text-gray-900 dark:text-white">
                <span>Grand Total</span>
                <span className="tabular-nums">{fmt(sale.subTotal)}</span>
              </div>

              {(sale.previousDue || 0) > 0 && (
                <div className="flex justify-between text-orange-500 dark:text-orange-400 text-xs font-semibold">
                  <span><TrendingDown size={11} className="inline mr-1" />Previous Due</span>
                  <span className="tabular-nums">{fmt(sale.previousDue!)}</span>
                </div>
              )}

              <div className="border-t border-gray-100 dark:border-gray-700 pt-2.5 space-y-2">
                <div className="flex justify-between text-emerald-600 dark:text-emerald-400 font-semibold">
                  <span>Paid</span>
                  <span className="tabular-nums">{fmt(sale.paidAmount)}</span>
                </div>
                <div className={`flex justify-between font-bold rounded-xl p-2.5 ${
                  sale.dueAmount > 0
                    ? 'bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400'
                    : 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400'
                }`}>
                  <span>{sale.dueAmount > 0 ? 'Due Amount' : 'Fully Paid ✓'}</span>
                  <span className="tabular-nums">{fmt(Math.abs(sale.dueAmount))}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Quick info */}
          <div className="card p-4 space-y-3 text-xs text-gray-500 dark:text-gray-400">
            <div className="flex justify-between"><span>Status</span>
              <span className={`font-semibold ${isApproved ? 'text-emerald-600' : isPending ? 'text-amber-500' : 'text-gray-500'}`}>
                {isApproved ? 'Approved' : isPending ? 'Pending' : sale.status}
              </span>
            </div>
            <div className="flex justify-between"><span>Payment Type</span><span className="font-medium text-gray-700 dark:text-gray-300">{sale.paymentType || '—'}</span></div>
            {sale.createdAt && <div className="flex justify-between"><span>Created</span><span className="font-medium text-gray-700 dark:text-gray-300">{fmtDate(sale.createdAt)}</span></div>}
          </div>

          {/* Back link */}
          <Link href="/sales" className="btn-secondary w-full justify-center text-xs print:hidden">
            <ArrowLeft size={13} /> Back to Sales
          </Link>
        </div>
      </div>
    </div>
  );
}
