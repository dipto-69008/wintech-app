'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Topbar from '@/components/layout/Topbar';
import { formatDate } from '@/lib/utils';
import Link from 'next/link';
import {
  ArrowLeft, Package, User, Calendar, Truck, FileText,
  CheckCircle2, Loader2, AlertCircle, Printer,
  BadgeDollarSign, Percent, Anchor
} from 'lucide-react';

interface PurchaseDetail {
  productName?: string; quantity: number; rate: number;
  discount?: number; tax?: number; totalAmount: number;
}
interface Purchase {
  _id: string; invoiceNo: string; supplierName?: string;
  orderDate: string; purchaseFor?: string; description?: string;
  totalAmount: number; discountAmount: number; tax: number;
  freight: number; subTotal: number; paidAmount: number;
  dueAmount: number; status: string;
  details?: PurchaseDetail[];
  createdAt?: string;
}

function fmt(n: number) { return `৳${Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`; }
function fmtDate(d: string) { return formatDate(d); }

export default function PurchaseDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [po, setPo] = useState<Purchase | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(`/api/purchases/${id}`)
      .then(r => r.ok ? r.json() : Promise.reject('Not found'))
      .then(setPo)
      .catch(() => setError('Purchase not found'))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return (
    <div className="page-wrapper">
      <div className="flex items-center justify-center py-32 gap-3 text-gray-400">
        <Loader2 size={22} className="animate-spin" /> Loading purchase…
      </div>
    </div>
  );

  if (error || !po) return (
    <div className="page-wrapper">
      <div className="card text-center py-20 text-gray-400">
        <AlertCircle size={40} className="mx-auto mb-3 opacity-30" />
        <p className="font-semibold text-gray-600 dark:text-gray-300">Purchase record not found</p>
        <Link href="/purchases" className="text-blue-500 text-sm mt-3 inline-block">← Back to Purchases</Link>
      </div>
    </div>
  );

  return (
    <div className="page-wrapper">
      <Topbar
        title={po.invoiceNo}
        subtitle={`${po.supplierName || '—'} · ${fmtDate(po.orderDate)}`}
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

      <div className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-semibold border ${
        po.status === 'a'
          ? 'bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-700/40 text-emerald-700 dark:text-emerald-400'
          : 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-700/40 text-amber-700 dark:text-amber-400'
      }`}>
        <CheckCircle2 size={14} /> Purchase Order
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-4 items-start">
        <div className="space-y-4">

          {/* PO Header */}
          <div className="card p-6">
            <div className="flex items-start justify-between mb-6 pb-5 border-b border-gray-100 dark:border-gray-700">
              <div>
                <p className="text-[10px] font-semibold uppercase tracking-widest text-gray-400 mb-1">Purchase Order</p>
                <p className="text-2xl font-black text-gray-900 dark:text-white font-mono">{po.invoiceNo}</p>
              </div>
              <div className="text-right">
                <p className="text-[10px] font-semibold uppercase tracking-widest text-gray-400 mb-1">Date</p>
                <p className="text-base font-bold text-gray-800 dark:text-gray-200">{fmtDate(po.orderDate)}</p>
              </div>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {[
                { icon: User,     label: 'Supplier',      value: po.supplierName || '—' },
                { icon: Truck,    label: 'Purchase For',  value: po.purchaseFor  || '—' },
                { icon: FileText, label: 'Notes',         value: po.description  || '—' },
              ].map(({ icon: Icon, label, value }) => (
                <div key={label} className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-800/60 rounded-xl">
                  <div className="w-8 h-8 bg-white dark:bg-gray-700 rounded-lg flex items-center justify-center shadow-sm flex-shrink-0">
                    <Icon size={14} className="text-orange-500" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-[10px] text-gray-400 font-medium mb-0.5">{label}</p>
                    <p className="text-sm font-semibold text-gray-800 dark:text-white truncate">{value}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Items table */}
          <div className="card p-0 overflow-hidden">
            <div className="flex items-center gap-2 p-5 border-b border-gray-100 dark:border-gray-700">
              <div className="w-7 h-7 rounded-lg bg-orange-50 dark:bg-orange-900/20 flex items-center justify-center">
                <Package size={14} className="text-orange-500" />
              </div>
              <h3 className="font-bold text-sm text-gray-800 dark:text-white">Items Received</h3>
              {po.details && (
                <span className="text-xs bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400 px-2 py-0.5 rounded-full font-semibold">
                  {po.details.length} lines
                </span>
              )}
            </div>
            {po.details && po.details.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50 dark:bg-gray-800/60 text-xs text-gray-500 font-semibold uppercase tracking-wide">
                      <th className="text-left px-5 py-3">#</th>
                      <th className="text-left px-5 py-3">Product</th>
                      <th className="text-center px-4 py-3">Qty</th>
                      <th className="text-right px-4 py-3">Rate</th>
                      <th className="text-right px-5 py-3">Amount</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                    {po.details.map((d, i) => (
                      <tr key={i} className="hover:bg-orange-50/30 dark:hover:bg-orange-900/10 transition-colors">
                        <td className="px-5 py-3 text-gray-400 text-xs">{i + 1}</td>
                        <td className="px-5 py-3">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 bg-orange-50 dark:bg-orange-900/20 rounded-lg flex items-center justify-center flex-shrink-0">
                              <Package size={11} className="text-orange-400" />
                            </div>
                            <span className="font-medium text-gray-800 dark:text-white">{d.productName || '—'}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-center font-semibold tabular-nums">{d.quantity}</td>
                        <td className="px-4 py-3 text-right text-gray-600 dark:text-gray-400 tabular-nums">{d.rate.toLocaleString()}</td>
                        <td className="px-5 py-3 text-right font-bold tabular-nums">{d.totalAmount.toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr className="bg-gray-50 dark:bg-gray-800/60 font-bold">
                      <td className="px-5 py-3 text-xs text-gray-400 uppercase" colSpan={2}>Total</td>
                      <td className="px-4 py-3 text-center tabular-nums text-gray-700 dark:text-gray-300">
                        {po.details.reduce((a, d) => a + d.quantity, 0)}
                      </td>
                      <td></td>
                      <td className="px-5 py-3 text-right text-lg text-orange-600 dark:text-orange-400 tabular-nums">
                        {po.details.reduce((a, d) => a + d.totalAmount, 0).toLocaleString()}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            ) : (
              <div className="text-center py-12 text-gray-400">
                <Package size={32} className="mx-auto mb-2 opacity-30" />
                <p className="text-sm">No line items</p>
              </div>
            )}
          </div>
        </div>

        {/* Right summary */}
        <div className="xl:sticky xl:top-4 space-y-4">
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-7 h-7 rounded-lg bg-orange-50 dark:bg-orange-900/20 flex items-center justify-center">
                <BadgeDollarSign size={14} className="text-orange-600" />
              </div>
              <h3 className="font-bold text-sm text-gray-800 dark:text-white">Cost Summary</h3>
            </div>
            <div className="space-y-2.5 text-sm">
              <div className="flex justify-between text-gray-600 dark:text-gray-400">
                <span>Total Amount</span>
                <span className="font-semibold tabular-nums">{fmt(po.totalAmount)}</span>
              </div>
              {po.discountAmount > 0 && (
                <div className="flex justify-between text-red-500">
                  <span className="flex items-center gap-1"><Percent size={11} />Discount</span>
                  <span className="tabular-nums">−{fmt(po.discountAmount)}</span>
                </div>
              )}
              {po.tax > 0 && (
                <div className="flex justify-between text-blue-500">
                  <span>Tax</span>
                  <span className="tabular-nums">+{fmt(po.tax)}</span>
                </div>
              )}
              {po.freight > 0 && (
                <div className="flex justify-between text-purple-500">
                  <span className="flex items-center gap-1"><Anchor size={11} />Freight</span>
                  <span className="tabular-nums">+{fmt(po.freight)}</span>
                </div>
              )}
              <div className="border-t border-gray-100 dark:border-gray-700 pt-2.5 flex justify-between font-black text-lg text-gray-900 dark:text-white">
                <span>Net Total</span>
                <span className="tabular-nums">{fmt(po.subTotal)}</span>
              </div>
              <div className="border-t border-gray-100 dark:border-gray-700 pt-2.5 space-y-2">
                <div className="flex justify-between text-emerald-600 font-semibold">
                  <span>Paid</span><span className="tabular-nums">{fmt(po.paidAmount)}</span>
                </div>
                <div className={`flex justify-between font-bold rounded-xl p-2.5 ${
                  po.dueAmount > 0
                    ? 'bg-red-50 dark:bg-red-900/20 text-red-600'
                    : 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600'
                }`}>
                  <span>{po.dueAmount > 0 ? 'Due' : 'Fully Paid ✓'}</span>
                  <span className="tabular-nums">{fmt(Math.abs(po.dueAmount))}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="card p-4 text-xs text-gray-500 dark:text-gray-400 space-y-2">
            <div className="flex justify-between"><span>Supplier</span><span className="font-medium text-gray-700 dark:text-gray-300 truncate max-w-[140px]">{po.supplierName || '—'}</span></div>
            <div className="flex justify-between"><span>Order Date</span><span className="font-medium text-gray-700 dark:text-gray-300">{fmtDate(po.orderDate)}</span></div>
            {po.createdAt && <div className="flex justify-between"><span>Entered</span><span className="font-medium text-gray-700 dark:text-gray-300">{fmtDate(po.createdAt)}</span></div>}
          </div>

          <Link href="/purchases" className="btn-secondary w-full justify-center text-xs print:hidden">
            <ArrowLeft size={13} /> Back to Purchases
          </Link>
        </div>
      </div>
    </div>
  );
}
