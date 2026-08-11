'use client';
import { useState, useEffect, useCallback } from 'react';
import { useBranchStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import { Truck, Plus, Search, Loader2, Eye } from 'lucide-react';
import Link from 'next/link';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { formatDate } from '@/lib/utils';

interface PurchaseDetail { productName?: string; quantity: number; rate: number; totalAmount: number; }
interface PurchaseMaster {
  _id: string; invoiceNo: string; supplierName?: string; orderDate: string;
  purchaseFor?: string; totalAmount: number; discountAmount: number; tax: number;
  freight: number; subTotal: number; paidAmount: number; dueAmount: number;
  status: string; details?: PurchaseDetail[];
}

export default function PurchasesPage() {
  const [purchases, setPurchases] = useState<PurchaseMaster[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [viewPO, setViewPO] = useState<PurchaseMaster | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const { selectedBranchLegacyId } = useBranchStore();

  const fetch_ = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch(`/api/purchases?search=${encodeURIComponent(search)}&limit=100${selectedBranchLegacyId ? `&branchId=${selectedBranchLegacyId}` : ''}`);
      const d = await r.json(); setPurchases(d.data||[]); setTotal(d.total||0);
    } catch { toast.error('Could not load purchases'); } finally { setLoading(false); }
  }, [search, selectedBranchLegacyId]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const openView = async (p: PurchaseMaster) => {
    setViewPO(p); setLoadingDetail(true);
    try {
      const r = await fetch(`/api/purchases/${p._id}`);
      const d = await r.json(); setViewPO(d);
    } catch { } finally { setLoadingDetail(false); }
  };

  const totalPurchases = purchases.reduce((a,p)=>a+p.subTotal,0);
  const totalDue = purchases.reduce((a,p)=>a+p.dueAmount,0);
  const totalPaid = purchases.reduce((a,p)=>a+p.paidAmount,0);

  return (
    <div className="page-wrapper">
      <Topbar title="Purchase Orders" subtitle={`${total} purchase orders in database`}
        actions={<Button size="sm" onClick={() => toast('Use supplier invoices to create purchases')}><Plus size={15}/>New Purchase</Button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[{label:'Total Orders',value:total,color:'blue'},{label:'Total Purchases',value:`৳${totalPurchases.toLocaleString()}`,color:'orange'},
          {label:'Paid',value:`৳${totalPaid.toLocaleString()}`,color:'emerald'},{label:'Due',value:`৳${totalDue.toLocaleString()}`,color:'red'}
        ].map(s=>(
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="relative"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5"/>
            <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search by invoice / supplier..." className="form-input pl-9 w-72"/></div>
          <span className="text-sm text-gray-400">{purchases.length} shown</span>
        </div>
        {loading
          ? <div className="flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20}/>Loading...</div>
          : purchases.length===0
            ? <div className="text-center py-16 text-gray-400"><Truck size={40} className="mx-auto mb-3 opacity-30"/>
                <p className="font-medium">No purchase orders</p>
                <p className="text-xs mt-1">Run SQL migration to import from old ERP</p></div>
            : <div className="overflow-x-auto"><table className="w-full text-sm">
                <thead><tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                  {['Invoice','Supplier','Date','Purchase For','Total','Discount','Tax','Sub Total','Paid','Due',''].map(h=><th key={h} className={`py-3 pr-3 font-medium ${h===''?'text-right':'text-left'}`}>{h}</th>)}
                </tr></thead>
                <tbody>{purchases.map(p=>(
                  <tr key={p._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-3 pr-3 font-mono text-xs text-orange-600 font-semibold">{p.invoiceNo}</td>
                    <td className="py-3 pr-3 font-medium text-gray-900 dark:text-white max-w-[140px] truncate">{p.supplierName||'—'}</td>
                    <td className="py-3 pr-3 text-gray-500">{formatDate(p.orderDate)}</td>
                    <td className="py-3 pr-3 text-gray-500 max-w-[100px] truncate">{p.purchaseFor||'—'}</td>
                    <td className="py-3 pr-3 text-right">৳{p.totalAmount.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-right text-red-500">৳{p.discountAmount.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-right text-blue-500">৳{p.tax.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-right font-semibold text-gray-800 dark:text-white">৳{p.subTotal.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-right text-emerald-600">৳{p.paidAmount.toLocaleString()}</td>
                    <td className="py-3 pr-3 text-right font-semibold text-red-500">{p.dueAmount>0?`৳${p.dueAmount.toLocaleString()}`:'—'}</td>
                    <td className="py-3 text-right"><Link href={`/purchases/${p._id}`} className="icon-btn text-blue-400 hover:text-blue-600" title="View Detail"><Eye size={14}/></Link></td>
                  </tr>
                ))}</tbody>
              </table></div>
        }
      </div>

      <Modal
        open={!!viewPO}
        onClose={() => setViewPO(null)}
        title={viewPO ? `PO: ${viewPO.invoiceNo}` : ''}
        size="lg"
        footer={<Button variant="outline" onClick={() => setViewPO(null)}>Close</Button>}
      >
        {viewPO && (
          <>
            <p className="text-xs text-slate-500 -mt-2 mb-4">{viewPO.supplierName} · {formatDate(viewPO.orderDate)}</p>
            {loadingDetail
              ? <div className="flex justify-center py-8"><Loader2 className="animate-spin text-gray-400" size={20}/></div>
              : viewPO.details && viewPO.details.length > 0
                ? <div className="overflow-x-auto mb-4 rounded-xl border border-slate-200 dark:border-slate-700">
                    <table className="w-full text-sm">
                      <thead className="bg-slate-50 dark:bg-slate-800">
                        <tr className="text-xs text-slate-500">
                          <th className="py-2 px-3 text-left">Product</th>
                          <th className="py-2 px-3 text-center">Qty</th>
                          <th className="py-2 px-3 text-right">Rate</th>
                          <th className="py-2 px-3 text-right">Total</th>
                        </tr>
                      </thead>
                      <tbody>{viewPO.details.map((d,i)=>(
                        <tr key={i} className="border-t border-slate-100 dark:border-slate-700">
                          <td className="py-2 px-3">{d.productName||'Product'}</td>
                          <td className="py-2 px-3 text-center">{d.quantity}</td>
                          <td className="py-2 px-3 text-right">৳{d.rate.toLocaleString()}</td>
                          <td className="py-2 px-3 text-right font-semibold">৳{d.totalAmount.toLocaleString()}</td>
                        </tr>
                      ))}</tbody>
                    </table>
                  </div>
                : <p className="text-slate-400 text-sm py-4 text-center mb-4">No line items</p>
            }
            <div className="grid grid-cols-2 gap-2 text-sm border-t border-slate-100 dark:border-slate-700 pt-3">
              {[['Total',`৳${viewPO.totalAmount.toLocaleString()}`],['Discount',`-৳${viewPO.discountAmount.toLocaleString()}`],
                ['Tax',`+৳${viewPO.tax.toLocaleString()}`],['Freight',`+৳${viewPO.freight.toLocaleString()}`],
                ['Sub Total',`৳${viewPO.subTotal.toLocaleString()}`],['Paid',`৳${viewPO.paidAmount.toLocaleString()}`],
                ['Due',`৳${viewPO.dueAmount.toLocaleString()}`]].map(([k,v])=>(
                <div key={k} className="flex justify-between">
                  <span className="text-slate-500">{k}</span>
                  <span className={`font-semibold ${k==='Due'&&viewPO.dueAmount>0?'text-red-500':''}`}>{v}</span>
                </div>
              ))}
            </div>
          </>
        )}
      </Modal>
    </div>
  );
}
