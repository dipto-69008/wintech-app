'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Topbar from '@/components/layout/Topbar';
import { formatDate } from '@/lib/utils';
import Link from 'next/link';
import {
  ArrowLeft, Package, Tag, Layers, BarChart2, DollarSign,
  AlertCircle, Loader2, Edit2, CheckCircle2, XCircle, CalendarDays
} from 'lucide-react';
import toast from 'react-hot-toast';

interface Product {
  _id: string; code: string; name: string; categoryName?: string; brand?: string;
  size?: string; color?: string; packSize?: string; unit?: string;
  purchaseRate: number; sellingPrice: number; wholesaleRate?: number; minSellingPrice?: number;
  vat?: number; reorderLevel?: number; status: string;
  stock?: number;
  stockCumilla?: number; stockMymensingh?: number; stockBogra?: number;
  stockJessore?: number; stockFeni?: number;
  image?: string; addBy?: string; addTime?: string;
  expiryDate?: string; expiryReminderSent?: string[];
  createdAt?: string; updatedAt?: string;
}

function resolveImg(img?: string) {
  if (!img) return '';
  return img.startsWith('http') ? img : `/uploads/${img}`;
}

const BRANCH_KEYS: { key: keyof Product; label: string; color: string }[] = [
  { key: 'stockCumilla',    label: 'Cumilla',    color: 'bg-blue-500' },
  { key: 'stockMymensingh', label: 'Mymensingh', color: 'bg-emerald-500' },
  { key: 'stockBogra',      label: 'Bogra',      color: 'bg-purple-500' },
  { key: 'stockJessore',    label: 'Jessore',    color: 'bg-orange-500' },
  { key: 'stockFeni',       label: 'Feni',       color: 'bg-pink-500' },
];

function fmtDate(d?: string) {
  if (!d) return '—';
  return formatDate(d);
}

function expiryStatus(d?: string): 'expired' | 'critical' | 'warning' | 'ok' | null {
  if (!d) return null;
  const now = new Date();
  const exp = new Date(d);
  const days = Math.ceil((exp.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  if (days < 0)   return 'expired';
  if (days <= 60) return 'critical';
  if (days <= 92) return 'warning';
  return 'ok';
}

export default function ProductDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState('');

  useEffect(() => {
    fetch(`/api/products/${id}`)
      .then(r => r.ok ? r.json() : Promise.reject('Not found'))
      .then(setProduct)
      .catch(() => setError('Product not found'))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return (
    <div className="page-wrapper">
      <div className="flex items-center justify-center py-32 gap-3 text-gray-400">
        <Loader2 size={22} className="animate-spin" /> Loading product…
      </div>
    </div>
  );

  if (error || !product) return (
    <div className="page-wrapper">
      <div className="card text-center py-20 text-gray-400">
        <AlertCircle size={40} className="mx-auto mb-3 opacity-30" />
        <p className="font-semibold text-gray-600 dark:text-gray-300">Product not found</p>
        <Link href="/inventory" className="text-blue-500 text-sm mt-3 inline-block">← Back to Inventory</Link>
      </div>
    </div>
  );

  const totalStock = BRANCH_KEYS.reduce((a, b) => a + ((product[b.key] as number) || 0), 0);
  const maxStock   = Math.max(...BRANCH_KEYS.map(b => (product[b.key] as number) || 0), 1);
  const expStatus  = expiryStatus(product.expiryDate);
  const isActive   = product.status === 'a';
  const imgSrc     = resolveImg(product.image);

  return (
    <div className="page-wrapper">
      <Topbar
        title={product.name}
        subtitle={`${product.code}${product.packSize ? ' · ' + product.packSize : ''}`}
        actions={
          <div className="flex items-center gap-2">
            <Link href={`/inventory?edit=${product._id}`} className="btn-primary text-xs py-2 px-3 gap-1.5">
              <Edit2 size={13} /> Edit Product
            </Link>
            <button onClick={() => router.back()} className="btn-secondary text-xs py-2 px-3 gap-1.5">
              <ArrowLeft size={13} /> Back
            </button>
          </div>
        }
      />

      {/* Expiry alert */}
      {expStatus && expStatus !== 'ok' && (
        <div className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-semibold border ${
          expStatus === 'expired'  ? 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-700/40 text-red-700 dark:text-red-400'
          : expStatus === 'critical' ? 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-700/40 text-red-600 dark:text-red-400'
                                     : 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-700/40 text-amber-700 dark:text-amber-400'
        }`}>
          <AlertCircle size={14} />
          {expStatus === 'expired'  ? `⚠️ This product EXPIRED on ${fmtDate(product.expiryDate)}`
           : expStatus === 'critical' ? `🚨 Expires in under 2 months — ${fmtDate(product.expiryDate)}`
                                      : `⚠️ Expiring soon — ${fmtDate(product.expiryDate)}`}
        </div>
      )}

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-4 items-start">

        {/* ── LEFT ── */}
        <div className="space-y-4">

          {/* Product Identity */}
          <div className="card p-6">
            <div className="flex items-start gap-5">
              {/* Image */}
              <div className="w-24 h-24 flex-shrink-0 rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 flex items-center justify-center">
                {imgSrc
                  ? <img src={imgSrc} alt={product.name} className="w-full h-full object-cover" />
                  : <Package size={32} className="text-gray-300" />
                }
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2 flex-wrap">
                  <div>
                    <h2 className="text-xl font-black text-gray-900 dark:text-white">{product.name}</h2>
                    <p className="text-sm text-gray-500 mt-0.5 font-mono">{product.code}</p>
                  </div>
                  <span className={`inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full ${
                    isActive
                      ? 'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400'
                      : 'bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400'
                  }`}>
                    {isActive ? <CheckCircle2 size={11} /> : <XCircle size={11} />}
                    {isActive ? 'Active' : 'Inactive'}
                  </span>
                </div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {product.categoryName && <span className="inline-flex items-center gap-1 text-xs bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400 px-2 py-0.5 rounded-full"><Tag size={9} />{product.categoryName}</span>}
                  {product.brand        && <span className="inline-flex items-center gap-1 text-xs bg-purple-50 dark:bg-purple-900/20 text-purple-700 dark:text-purple-400 px-2 py-0.5 rounded-full"><Layers size={9} />{product.brand}</span>}
                  {product.packSize     && <span className="inline-flex items-center gap-1 text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 px-2 py-0.5 rounded-full">{product.packSize}</span>}
                  {product.size         && <span className="text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 px-2 py-0.5 rounded-full">{product.size}</span>}
                  {product.unit         && <span className="text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 px-2 py-0.5 rounded-full">{product.unit}</span>}
                </div>
              </div>
            </div>
          </div>

          {/* Pricing */}
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-7 h-7 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 flex items-center justify-center">
                <DollarSign size={14} className="text-emerald-600" />
              </div>
              <h3 className="font-bold text-sm text-gray-800 dark:text-white">Pricing</h3>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {[
                { label: 'Purchase Rate',     value: product.purchaseRate,    color: 'text-orange-600' },
                { label: 'Selling Price (TP)', value: product.sellingPrice,   color: 'text-blue-600' },
                { label: 'Wholesale Rate',    value: product.wholesaleRate || 0, color: 'text-purple-600' },
                { label: 'Min Selling Price', value: product.minSellingPrice || 0, color: 'text-gray-600' },
              ].map(p => (
                <div key={p.label} className="bg-gray-50 dark:bg-gray-800/60 rounded-xl p-3 text-center">
                  <p className="text-[10px] text-gray-400 font-medium mb-1">{p.label}</p>
                  <p className={`text-lg font-black tabular-nums ${p.color}`}>
                    ৳{Number(p.value || 0).toLocaleString()}
                  </p>
                </div>
              ))}
            </div>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <div className="bg-gray-50 dark:bg-gray-800/60 rounded-xl p-3 flex justify-between items-center">
                <span className="text-xs text-gray-400">VAT %</span>
                <span className="font-semibold text-gray-700 dark:text-gray-300">{product.vat || 0}%</span>
              </div>
              <div className="bg-gray-50 dark:bg-gray-800/60 rounded-xl p-3 flex justify-between items-center">
                <span className="text-xs text-gray-400">Reorder Level</span>
                <span className="font-semibold text-gray-700 dark:text-gray-300">{product.reorderLevel || 0}</span>
              </div>
            </div>
          </div>

          {/* Stock by Branch */}
          <div className="card p-5">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center">
                  <BarChart2 size={14} className="text-blue-600" />
                </div>
                <h3 className="font-bold text-sm text-gray-800 dark:text-white">Stock by Branch</h3>
              </div>
              <div className="text-right">
                <p className="text-[10px] text-gray-400 font-medium">Total</p>
                <p className="text-xl font-black text-gray-900 dark:text-white tabular-nums">{totalStock.toLocaleString()}</p>
              </div>
            </div>
            <div className="space-y-3">
              {BRANCH_KEYS.map(({ key, label, color }) => {
                const val = (product[key] as number) || 0;
                const pct = maxStock > 0 ? Math.round((val / maxStock) * 100) : 0;
                return (
                  <div key={label}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="font-medium text-gray-700 dark:text-gray-300">{label}</span>
                      <span className="font-bold tabular-nums text-gray-900 dark:text-white">{val.toLocaleString()}</span>
                    </div>
                    <div className="h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                      <div
                        className={`h-full ${color} rounded-full transition-all duration-500`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* ── RIGHT ── */}
        <div className="xl:sticky xl:top-4 space-y-4">

          {/* Quick stats */}
          <div className="card p-5 space-y-3">
            <h3 className="font-bold text-sm text-gray-800 dark:text-white mb-1">Product Details</h3>
            {[
              { label: 'Product Code',  value: product.code },
              { label: 'Category',      value: product.categoryName || '—' },
              { label: 'Brand',         value: product.brand     || '—' },
              { label: 'Pack Size',     value: product.packSize  || '—' },
              { label: 'Size',          value: product.size      || '—' },
              { label: 'Color',         value: product.color     || '—' },
              { label: 'Unit',          value: product.unit      || '—' },
            ].map(({ label, value }) => (
              <div key={label} className="flex justify-between text-xs">
                <span className="text-gray-400">{label}</span>
                <span className="font-semibold text-gray-700 dark:text-gray-300 max-w-[140px] text-right truncate">{value}</span>
              </div>
            ))}
          </div>

          {/* Expiry */}
          {product.expiryDate && (
            <div className={`card p-4 space-y-2 border-2 ${
              expStatus === 'expired'  ? 'border-red-300 dark:border-red-700'
              : expStatus === 'critical' ? 'border-red-200 dark:border-red-800'
              : expStatus === 'warning'  ? 'border-amber-200 dark:border-amber-800'
                                         : 'border-emerald-200 dark:border-emerald-800'
            }`}>
              <div className="flex items-center gap-2">
                <CalendarDays size={14} className={
                  expStatus === 'expired' || expStatus === 'critical' ? 'text-red-500' :
                  expStatus === 'warning' ? 'text-amber-500' : 'text-emerald-500'
                } />
                <h3 className="font-bold text-sm text-gray-800 dark:text-white">Expiry Date</h3>
              </div>
              <p className={`text-lg font-black tabular-nums ${
                expStatus === 'expired' || expStatus === 'critical' ? 'text-red-600 dark:text-red-400'
                : expStatus === 'warning' ? 'text-amber-600 dark:text-amber-400'
                                          : 'text-emerald-600 dark:text-emerald-400'
              }`}>{fmtDate(product.expiryDate)}</p>
              {expStatus === 'expired'  && <p className="text-xs text-red-500 font-semibold">Product has expired!</p>}
              {expStatus === 'critical' && <p className="text-xs text-red-500">Expiring in under 2 months</p>}
              {expStatus === 'warning'  && <p className="text-xs text-amber-500">Expiring in under 3 months</p>}
              {expStatus === 'ok'       && <p className="text-xs text-emerald-500">Good — more than 3 months left</p>}
            </div>
          )}

          {/* Low stock warning */}
          {(product.reorderLevel || 0) > 0 && totalStock <= (product.reorderLevel || 0) && (
            <div className="card p-4 border-2 border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-900/20">
              <div className="flex items-center gap-2 text-amber-700 dark:text-amber-400 text-sm font-semibold">
                <AlertCircle size={15} />
                Low Stock Alert
              </div>
              <p className="text-xs text-amber-600 dark:text-amber-500 mt-1">
                Total stock ({totalStock}) is at or below reorder level ({product.reorderLevel}).
              </p>
            </div>
          )}

          {/* Timestamps */}
          <div className="card p-4 text-xs text-gray-500 dark:text-gray-400 space-y-2">
            {product.addBy   && <div className="flex justify-between"><span>Added By</span><span className="font-medium text-gray-700 dark:text-gray-300">{product.addBy}</span></div>}
            {product.createdAt && <div className="flex justify-between"><span>Created</span><span className="font-medium text-gray-700 dark:text-gray-300">{fmtDate(product.createdAt)}</span></div>}
            {product.updatedAt && <div className="flex justify-between"><span>Last Updated</span><span className="font-medium text-gray-700 dark:text-gray-300">{fmtDate(product.updatedAt)}</span></div>}
          </div>

          <Link href="/inventory" className="btn-secondary w-full justify-center text-xs">
            <ArrowLeft size={13} /> Back to Inventory
          </Link>
        </div>
      </div>
    </div>
  );
}
