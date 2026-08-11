'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Tag, Package, TrendingUp, Loader2, Search } from 'lucide-react';

interface Product { _id: string; name: string; sku?: string; category?: string; unit?: string; costPrice?: number; salePrice?: number; stock?: number; minStock?: number; status?: string; }

export default function PriceListPage() {
  const [loading, setLoading] = useState(true);
  const [products, setProducts] = useState<Product[]>([]);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetch('/api/products?limit=1000')
      .then(r => r.ok ? r.json() : { data: [] })
      .then(j => setProducts(j.data || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const activeProducts = products.filter(p =>
    (!p.status || p.status === 'active') &&
    (!search || p.name.toLowerCase().includes(search.toLowerCase()) || (p.sku || '').toLowerCase().includes(search.toLowerCase()))
  );

  const byCategory = activeProducts.reduce((acc, p) => {
    const cat = p.category || 'Uncategorized';
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(p);
    return acc;
  }, {} as Record<string, Product[]>);

  const prices = activeProducts.map(p => p.salePrice || 0).filter(v => v > 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Product Price List" subtitle="Current selling prices for all active products" />

      <div className="grid grid-cols-3 gap-4">
        <div className="card"><p className="text-2xl font-bold text-blue-600">{activeProducts.length}</p><p className="text-sm text-gray-500 mt-1">Active Products</p></div>
        <div className="card"><p className="text-2xl font-bold text-emerald-600">৳{prices.length ? Math.min(...prices).toLocaleString() : 0}</p><p className="text-sm text-gray-500 mt-1">Lowest Price</p></div>
        <div className="card"><p className="text-2xl font-bold text-purple-600">৳{prices.length ? Math.max(...prices).toLocaleString() : 0}</p><p className="text-sm text-gray-500 mt-1">Highest Price</p></div>
      </div>

      <div className="card">
        <div className="section-header mb-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search products…" className="form-input pl-9 w-64" />
          </div>
          <span className="text-sm text-gray-400">{activeProducts.length} products</span>
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
      ) : Object.keys(byCategory).length === 0 ? (
        <div className="card text-center py-12 text-gray-400"><Package className="w-10 h-10 mx-auto mb-2 opacity-30" /><p>No products found</p></div>
      ) : (
        Object.entries(byCategory).map(([cat, prods]) => (
          <div key={cat} className="card">
            <div className="flex items-center gap-2 mb-4">
              <span className="w-8 h-8 bg-blue-50 rounded-lg flex items-center justify-center"><Tag size={15} className="text-blue-500" /></span>
              <h3 className="font-bold text-gray-900 dark:text-white">{cat}</h3>
              <span className="badge badge-blue text-[10px]">{prods.length} items</span>
            </div>
            <div className="table-wrapper">
              <table className="w-full">
                <thead><tr>{['SKU', 'Product Name', 'Unit', 'Cost Price', 'Selling Price', 'Margin', 'Stock'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
                <tbody className="divide-y divide-gray-50">
                  {prods.map(p => {
                    const cost = p.costPrice || 0;
                    const price = p.salePrice || 0;
                    const margin = price > 0 ? (((price - cost) / price) * 100).toFixed(1) : '—';
                    return (
                      <tr key={p._id} className="table-row">
                        <td className="table-cell font-mono text-xs text-gray-400">{p.sku || '—'}</td>
                        <td className="table-cell">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 bg-blue-50 rounded-lg flex items-center justify-center"><Package size={12} className="text-blue-400" /></div>
                            <span className="font-medium text-gray-900 dark:text-white text-sm">{p.name}</span>
                          </div>
                        </td>
                        <td className="table-cell text-gray-500 text-xs">{p.unit || '—'}</td>
                        <td className="table-cell text-gray-500">৳{cost.toLocaleString()}</td>
                        <td className="table-cell font-bold text-gray-900 dark:text-white">৳{price.toLocaleString()}</td>
                        <td className="table-cell">
                          <div className="flex items-center gap-1">
                            <TrendingUp size={12} className="text-emerald-500" />
                            <span className="text-emerald-600 font-semibold text-xs">{margin}%</span>
                          </div>
                        </td>
                        <td className="table-cell">
                          <span className={`badge text-xs ${(p.stock || 0) <= (p.minStock || 0) && (p.stock || 0) >= 0 ? 'badge-red' : 'badge-green'}`}>
                            {p.stock ?? '—'} {p.unit || ''}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
