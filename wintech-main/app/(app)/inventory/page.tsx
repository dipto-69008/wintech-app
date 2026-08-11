'use client';
import { useState, useEffect, useCallback, useRef } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Plus, Search, Edit2, Trash2, Package, Loader2, LayoutGrid, List, X, Filter, Eye } from 'lucide-react';
import toast from 'react-hot-toast';
import Link from 'next/link';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { ImageUpload } from '@/components/ui/ImageUpload';

function resolveImg(img?: string) {
  if (!img) return '';
  return img.startsWith('http') ? img : `/uploads/${img}`;
}

interface Product {
  _id: string; code: string; name: string; categoryName?: string; brand?: string;
  purchaseRate: number; sellingPrice: number; wholesaleRate?: number;
  unit?: string; status: string; vat?: number; reorderLevel?: number;
  stock?: number; image?: string; size?: string; color?: string; packSize?: string;
  stockCumilla?: number; stockMymensingh?: number; stockBogra?: number; stockJessore?: number; stockFeni?: number;
  bonusTriggerQty?: number; bonusFreeQty?: number;
}

const BRANCHES = [
  { value: '', label: 'All Branches' },
  { value: 'cumilla', label: 'Cumilla' },
  { value: 'mymensingh', label: 'Mymensingh' },
  { value: 'bogra', label: 'Bogra' },
  { value: 'jessore', label: 'Jessore' },
  { value: 'feni', label: 'Feni' },
];

const emptyForm = () => ({
  code: '', name: '', categoryName: '', brand: '', size: '', packSize: '',
  purchaseRate: '', sellingPrice: '', wholesaleRate: '', minSellingPrice: '',
  unit: 'PCS', vat: '0', reorderLevel: '0',
  stock: '0',
  stockCumilla: '0', stockMymensingh: '0', stockBogra: '0', stockJessore: '0', stockFeni: '0',
  status: 'a', image: '',
  bonusTriggerQty: '0', bonusFreeQty: '0',
});

export default function InventoryPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [branchFilter, setBranchFilter] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [viewMode, setViewMode] = useState<'card' | 'table'>('table');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Product | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [categories, setCategories] = useState<{ _id: string; name: string }[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // load categories for dropdown
  useEffect(() => {
    fetch('/api/categories').then(r => r.json()).then(d => setCategories(d.data || [])).catch(() => {});
  }, []);

  const fetchProducts = useCallback(async (q: string, branch: string, category: string) => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ search: q, limit: '200' });
      if (branch) params.set('branch', branch);
      if (category) params.set('category', category);
      const r = await fetch(`/api/products?${params}`);
      if (!r.ok) throw new Error('Failed');
      const d = await r.json();
      setProducts(d.data || []);
      setTotal(d.total || 0);
    } catch {
      toast.error('Could not load products — check MongoDB connection');
      setProducts([]);
    } finally { setLoading(false); }
  }, []);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => fetchProducts(search, branchFilter, categoryFilter), 300);
  }, [search, branchFilter, categoryFilter, fetchProducts]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (p: Product) => {
    setEditing(p);
    setForm({
      code: p.code, name: p.name, categoryName: p.categoryName || '', brand: p.brand || '',
      size: p.size || '', packSize: p.packSize || '',
      purchaseRate: String(p.purchaseRate), sellingPrice: String(p.sellingPrice),
      wholesaleRate: String(p.wholesaleRate || ''), minSellingPrice: '',
      unit: p.unit || 'PCS', vat: String(p.vat || 0), reorderLevel: String(p.reorderLevel || 0),
      stock: String(p.stock || 0),
      stockCumilla: String(p.stockCumilla || 0),
      stockMymensingh: String(p.stockMymensingh || 0),
      stockBogra: String(p.stockBogra || 0),
      stockJessore: String(p.stockJessore || 0),
      stockFeni: String(p.stockFeni || 0),
      status: p.status, image: p.image || '',
      bonusTriggerQty: String(p.bonusTriggerQty || 0),
      bonusFreeQty: String(p.bonusFreeQty || 0),
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name) return toast.error('Product name required');
    if (!form.code) return toast.error('Product code required');
    setSaving(true);
    try {
      const sc = parseFloat(form.stockCumilla) || 0;
      const sm = parseFloat(form.stockMymensingh) || 0;
      const sb = parseFloat(form.stockBogra) || 0;
      const sj = parseFloat(form.stockJessore) || 0;
      const sf = parseFloat(form.stockFeni) || 0;
      const totalStock = sc + sm + sb + sj + sf;
      const payload = {
        code: form.code, name: form.name, categoryName: form.categoryName, brand: form.brand,
        size: form.size, packSize: form.packSize,
        purchaseRate: parseFloat(form.purchaseRate) || 0,
        sellingPrice: parseFloat(form.sellingPrice) || 0,
        wholesaleRate: parseFloat(form.wholesaleRate) || 0,
        unit: form.unit, vat: parseFloat(form.vat) || 0,
        reorderLevel: parseInt(form.reorderLevel) || 0,
        stock: totalStock,
        stockCumilla: sc, stockMymensingh: sm, stockBogra: sb, stockJessore: sj, stockFeni: sf,
        status: form.status, image: form.image || undefined,
        bonusTriggerQty: parseInt(form.bonusTriggerQty) || 0,
        bonusFreeQty: parseInt(form.bonusFreeQty) || 0,
      };
      const res = await fetch(editing ? `/api/products/${editing._id}` : '/api/products',
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success(editing ? 'Product updated' : 'Product added');
      setShowModal(false);
      fetchProducts(search, branchFilter, categoryFilter);
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (p: Product) => {
    if (!confirm(`Delete "${p.name}"?`)) return;
    await fetch(`/api/products/${p._id}`, { method: 'DELETE' });
    toast.success('Deleted');
    fetchProducts(search, branchFilter, categoryFilter);
  };

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const branchStock = (p: Product) => {
    if (branchFilter === 'cumilla') return p.stockCumilla ?? 0;
    if (branchFilter === 'mymensingh') return p.stockMymensingh ?? 0;
    if (branchFilter === 'bogra') return p.stockBogra ?? 0;
    if (branchFilter === 'jessore') return p.stockJessore ?? 0;
    if (branchFilter === 'feni') return p.stockFeni ?? 0;
    return p.stock ?? 0;
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Inventory" subtitle={`${total} products in database`}
        actions={<Button size="sm" onClick={openAdd}><Plus size={15} />Add Product</Button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Products', value: total, color: 'blue' },
          { label: 'Active', value: products.filter(p => p.status === 'a').length, color: 'emerald' },
          { label: 'With Stock', value: products.filter(p => (p.stock || 0) > 0).length, color: 'amber' },
          { label: 'Avg Sell Price', value: products.length ? `৳${(products.reduce((a, p) => a + p.sellingPrice, 0) / products.length).toFixed(0)}` : '—', color: 'purple' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-3xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm font-medium text-gray-700 dark:text-gray-200 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="flex items-center flex-wrap gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search products..." className="form-input pl-9 w-56" />
            </div>
            {/* Branch filter */}
            <div className="flex items-center gap-1">
              <Filter size={14} className="text-gray-400" />
              <select value={branchFilter} onChange={e => setBranchFilter(e.target.value)} className="form-input w-40">
                {BRANCHES.map(b => <option key={b.value} value={b.value}>{b.label}</option>)}
              </select>
              {branchFilter && (
                <button onClick={() => setBranchFilter('')} className="text-gray-400 hover:text-red-500"><X size={14} /></button>
              )}
            </div>
            {/* Category filter */}
            <div className="flex items-center gap-1">
              <select value={categoryFilter} onChange={e => setCategoryFilter(e.target.value)} className="form-input w-44">
                <option value="">All Categories</option>
                {categories.map(c => <option key={c._id} value={c.name}>{c.name}</option>)}
              </select>
              {categoryFilter && (
                <button onClick={() => setCategoryFilter('')} className="text-gray-400 hover:text-red-500"><X size={14} /></button>
              )}
            </div>
            <span className="text-sm text-gray-400">{products.length} shown</span>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={() => setViewMode('table')} className={`p-2 rounded-lg transition-colors ${viewMode === 'table' ? 'bg-blue-100 text-blue-600' : 'text-gray-400 hover:bg-gray-100'}`}><List size={16} /></button>
            <button onClick={() => setViewMode('card')} className={`p-2 rounded-lg transition-colors ${viewMode === 'card' ? 'bg-blue-100 text-blue-600' : 'text-gray-400 hover:bg-gray-100'}`}><LayoutGrid size={16} /></button>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
        ) : products.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <Package size={40} className="mx-auto mb-3 opacity-30" />
            <p className="font-medium">No products found</p>
          </div>
        ) : viewMode === 'card' ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-4 gap-4">
            {products.map(p => (
              <div key={p._id} className="group border border-gray-100 dark:border-gray-700 rounded-2xl overflow-hidden hover:shadow-md transition-all">
                <div className="relative bg-gray-50 dark:bg-gray-800 aspect-square">
                  {p.image ? (
                    <img src={resolveImg(p.image)} alt={p.name} className="w-full h-full object-cover" onError={e => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center"><Package size={36} className="text-gray-300" /></div>
                  )}
                  <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Link href={`/inventory/${p._id}`} className="p-1.5 bg-white rounded-lg shadow text-emerald-500 hover:bg-emerald-50" title="View Detail"><Eye size={12} /></Link>
                    <button onClick={() => openEdit(p)} className="p-1.5 bg-white rounded-lg shadow text-blue-500 hover:bg-blue-50"><Edit2 size={12} /></button>
                    <button onClick={() => handleDelete(p)} className="p-1.5 bg-white rounded-lg shadow text-red-400 hover:bg-red-50"><Trash2 size={12} /></button>
                  </div>
                </div>
                <div className="p-3">
                  <p className="text-xs text-gray-400 font-mono mb-0.5">{p.code}</p>
                  <p className="font-semibold text-gray-900 dark:text-white text-sm leading-tight line-clamp-2 mb-1">{p.name}</p>
                  {p.packSize && <p className="text-xs text-blue-500 mb-1">{p.packSize}</p>}
                  <div className="flex items-center gap-1 flex-wrap mb-2">
                    {p.categoryName && <span className="text-[10px] bg-blue-50 text-blue-600 px-1.5 py-0.5 rounded-md">{p.categoryName}</span>}
                    <span className={`text-[10px] px-1.5 py-0.5 rounded-md ${p.status === 'a' ? 'bg-emerald-50 text-emerald-600' : 'bg-gray-100 text-gray-500'}`}>{p.status === 'a' ? 'Active' : 'Inactive'}</span>
                    {branchStock(p) > 0 && <span className="text-[10px] bg-amber-50 text-amber-600 px-1.5 py-0.5 rounded-md">Stock: {branchStock(p)}</span>}
                  </div>
                  <p className="text-base font-bold text-emerald-600">৳{p.sellingPrice.toLocaleString()}</p>
                </div>
              </div>
            ))}
          </div>
        ) : branchFilter ? (
          /* ── Single-branch view ── */
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                  <th className="py-3 pr-3 font-medium text-left">Code</th>
                  <th className="py-3 pr-3 font-medium text-left">Product Name</th>
                  <th className="py-3 pr-3 font-medium text-left">Category</th>
                  <th className="py-3 pr-3 font-medium text-left">Pack Size</th>
                  <th className="py-3 pr-3 font-medium text-right text-emerald-600">
                    {BRANCHES.find(b => b.value === branchFilter)?.label} Stock
                  </th>
                  <th className="py-3 pr-3 font-medium text-right">Purchase ৳</th>
                  <th className="py-3 pr-3 font-medium text-right">Sell ৳</th>
                  <th className="py-3 pr-3 font-medium text-center">Status</th>
                  <th className="py-3 font-medium text-right"></th>
                </tr>
              </thead>
              <tbody>
                {products.map(p => (
                  <tr key={p._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-2.5 pr-3 font-mono text-xs text-gray-500">{p.code}</td>
                    <td className="py-2.5 pr-3 font-medium text-gray-900 dark:text-white max-w-[200px] truncate">{p.name}</td>
                    <td className="py-2.5 pr-3 text-xs text-gray-500">{p.categoryName || '—'}</td>
                    <td className="py-2.5 pr-3 text-xs text-blue-500">{p.packSize || '—'}</td>
                    <td className="py-2.5 pr-3 text-right font-bold text-emerald-600 text-base">{branchStock(p)}</td>
                    <td className="py-2.5 pr-3 text-right text-xs text-gray-600">৳{p.purchaseRate.toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-right font-semibold text-emerald-600">৳{p.sellingPrice.toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-center"><span className={`badge ${p.status === 'a' ? 'badge-green' : 'badge-gray'}`}>{p.status === 'a' ? 'Active' : 'Inactive'}</span></td>
                    <td className="py-2.5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Link href={`/inventory/${p._id}`} className="icon-btn text-emerald-500 hover:text-emerald-700" title="View Detail"><Eye size={14} /></Link>
                        <button onClick={() => openEdit(p)} className="icon-btn"><Edit2 size={14} /></button>
                        <button onClick={() => handleDelete(p)} className="icon-btn text-red-400 hover:text-red-600"><Trash2 size={14} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          /* ── All-branches view ── */
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                  <th className="py-3 pr-3 font-medium text-left">Code</th>
                  <th className="py-3 pr-3 font-medium text-left">Product Name</th>
                  <th className="py-3 pr-3 font-medium text-left">Pack Size</th>
                  <th className="py-3 pr-3 font-medium text-right">Cumilla</th>
                  <th className="py-3 pr-3 font-medium text-right">Mymensingh</th>
                  <th className="py-3 pr-3 font-medium text-right">Bogra</th>
                  <th className="py-3 pr-3 font-medium text-right">Jessore</th>
                  <th className="py-3 pr-3 font-medium text-right">Feni</th>
                  <th className="py-3 pr-3 font-medium text-right">Total</th>
                  <th className="py-3 pr-3 font-medium text-right">Sell ৳</th>
                  <th className="py-3 pr-3 font-medium text-center">Status</th>
                  <th className="py-3 font-medium text-right"></th>
                </tr>
              </thead>
              <tbody>
                {products.map(p => (
                  <tr key={p._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-2.5 pr-3 font-mono text-xs text-gray-500">{p.code}</td>
                    <td className="py-2.5 pr-3 font-medium text-gray-900 dark:text-white max-w-[180px] truncate">{p.name}</td>
                    <td className="py-2.5 pr-3 text-xs text-blue-500">{p.packSize || '—'}</td>
                    <td className="py-2.5 pr-3 text-right text-xs font-medium text-gray-600">{p.stockCumilla ?? 0}</td>
                    <td className="py-2.5 pr-3 text-right text-xs font-medium text-gray-600">{p.stockMymensingh ?? 0}</td>
                    <td className="py-2.5 pr-3 text-right text-xs font-medium text-gray-600">{p.stockBogra ?? 0}</td>
                    <td className="py-2.5 pr-3 text-right text-xs font-medium text-gray-600">{p.stockJessore ?? 0}</td>
                    <td className="py-2.5 pr-3 text-right text-xs font-medium text-gray-600">{p.stockFeni ?? 0}</td>
                    <td className="py-2.5 pr-3 text-right font-bold text-gray-800 dark:text-white">{p.stock ?? 0}</td>
                    <td className="py-2.5 pr-3 text-right font-semibold text-emerald-600">৳{p.sellingPrice.toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-center"><span className={`badge ${p.status === 'a' ? 'badge-green' : 'badge-gray'}`}>{p.status === 'a' ? 'Active' : 'Inactive'}</span></td>
                    <td className="py-2.5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Link href={`/inventory/${p._id}`} className="icon-btn text-emerald-500 hover:text-emerald-700" title="View Detail"><Eye size={14} /></Link>
                        <button onClick={() => openEdit(p)} className="icon-btn"><Edit2 size={14} /></button>
                        <button onClick={() => handleDelete(p)} className="icon-btn text-red-400 hover:text-red-600"><Trash2 size={14} /></button>
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
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Product' : 'Add Product'}
        size="xl"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editing ? 'Update' : 'Add Product'}</Button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          <Field label="Product Code" required>
            <Input value={form.code} onChange={set('code')} placeholder="P001" />
          </Field>
          <Field label="Pack Size">
            <Input value={form.packSize} onChange={set('packSize')} placeholder="e.g. 100gm, 500ml, 1kg" />
          </Field>
          <Field label="Product Name" required className="col-span-2">
            <Input value={form.name} onChange={set('name')} placeholder="Product name" />
          </Field>
          <Field label="Category">
            <select className="form-input w-full" value={form.categoryName} onChange={set('categoryName')}>
              <option value="">— Select category —</option>
              {categories.map(c => <option key={c._id} value={c.name}>{c.name}</option>)}
            </select>
          </Field>
          <Field label="Unit">
            <Input value={form.unit} onChange={set('unit')} placeholder="PCS" />
          </Field>
          <Field label="Purchase Rate (৳)">
            <Input type="number" value={form.purchaseRate} onChange={set('purchaseRate')} min="0" />
          </Field>
          <Field label="Selling Price (৳)">
            <Input type="number" value={form.sellingPrice} onChange={set('sellingPrice')} min="0" />
          </Field>

          {/* Branch Stock */}
          <div className="col-span-2">
            <p className="form-label font-semibold text-gray-700 dark:text-gray-200 mb-2">Stock by Branch</p>
            <div className="grid grid-cols-5 gap-2">
              {[
                { key: 'stockCumilla', label: 'Cumilla' },
                { key: 'stockMymensingh', label: 'Mymensingh' },
                { key: 'stockBogra', label: 'Bogra' },
                { key: 'stockJessore', label: 'Jessore' },
                { key: 'stockFeni', label: 'Feni' },
              ].map(b => (
                <div key={b.key}>
                  <label className="text-xs text-gray-500 font-medium block mb-1">{b.label}</label>
                  <Input type="number" value={form[b.key as keyof typeof form]} onChange={set(b.key)} min="0" />
                </div>
              ))}
            </div>
          </div>

          <Field label="VAT %">
            <Input type="number" value={form.vat} onChange={set('vat')} min="0" />
          </Field>
          <Field label="Reorder Level">
            <Input type="number" value={form.reorderLevel} onChange={set('reorderLevel')} min="0" />
          </Field>
          <div className="col-span-2">
            <p className="form-label mb-2">Product Image</p>
            <ImageUpload
              value={form.image}
              onChange={url => setForm(f => ({ ...f, image: url }))}
            />
          </div>
          <Field label="Status">
            <Select value={form.status} onChange={set('status')}>
              <option value="a">Active</option>
              <option value="d">Inactive</option>
            </Select>
          </Field>

          {/* Bonus System */}
          <div className="col-span-2 border border-amber-200 dark:border-amber-700/40 rounded-xl p-4 bg-amber-50/40 dark:bg-amber-900/10">
            <p className="text-xs font-bold text-amber-700 dark:text-amber-400 uppercase tracking-wide mb-3">🎁 Bonus System</p>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="form-label">Buy (Qty trigger) <span className="text-gray-400 font-normal">— buy this many</span></label>
                <Input type="number" min="0" value={form.bonusTriggerQty} onChange={set('bonusTriggerQty')} placeholder="0 = no bonus" />
              </div>
              <div>
                <label className="form-label">Get Free (Qty) <span className="text-gray-400 font-normal">— free items given</span></label>
                <Input type="number" min="0" value={form.bonusFreeQty} onChange={set('bonusFreeQty')} placeholder="0" />
              </div>
            </div>
            {parseInt(form.bonusTriggerQty) > 0 && parseInt(form.bonusFreeQty) > 0 && (
              <p className="text-xs text-amber-700 dark:text-amber-400 mt-2 font-medium">
                ✓ Buy {form.bonusTriggerQty} → get {form.bonusFreeQty} free (auto-adds in order entry)
              </p>
            )}
          </div>
        </div>
      </Modal>
    </div>
  );
}
