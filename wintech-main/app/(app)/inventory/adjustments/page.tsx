'use client';
import { useState, useEffect, useCallback, useRef } from 'react';
import Topbar from '@/components/layout/Topbar';
import { ArrowLeftRight, Plus, TrendingUp, TrendingDown, Package, Search, Loader2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';

const IMAGE_BASE = '/uploads/';

interface Product {
  _id: string; code: string; name: string; unit?: string;
  reorderLevel?: number; stock?: number; image?: string;
}
interface Adjustment {
  _id: string; productName: string; productCode?: string;
  type: 'add' | 'remove'; quantity: number; reason: string;
  previousStock: number; newStock: number; createdAt: string;
}

export default function StockAdjustmentsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [prodSearch, setProdSearch] = useState('');
  const [prodResults, setProdResults] = useState<Product[]>([]);
  const [showProdDrop, setShowProdDrop] = useState(false);
  const [adjustments, setAdjustments] = useState<Adjustment[]>([]);
  const [loadingAdj, setLoadingAdj] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ productId: '', productName: '', type: 'add' as 'add' | 'remove', quantity: 1, reason: '' });
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const searchProducts = useCallback((term: string) => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      try {
        const r = await fetch(`/api/products?search=${encodeURIComponent(term)}&limit=20`);
        const d = await r.json();
        setProdResults(d.data || []);
      } catch { setProdResults([]); }
    }, 200);
  }, []);

  useEffect(() => { searchProducts(prodSearch); }, [prodSearch, searchProducts]);

  const fetchAdjustments = useCallback(async () => {
    setLoadingAdj(true);
    try {
      const r = await fetch('/api/adjustments?limit=200');
      const d = await r.json();
      setAdjustments(d.data || []);
    } catch { toast.error('Could not load adjustments'); }
    finally { setLoadingAdj(false); }
  }, []);

  const fetchAllProducts = useCallback(async () => {
    try {
      const r = await fetch('/api/products?limit=200');
      const d = await r.json();
      setProducts(d.data || []);
    } catch { setProducts([]); }
  }, []);

  useEffect(() => { fetchAdjustments(); fetchAllProducts(); }, [fetchAdjustments, fetchAllProducts]);

  const selectProduct = (p: Product) => {
    setForm(f => ({ ...f, productId: p._id, productName: p.name }));
    setProdSearch(p.name);
    setShowProdDrop(false);
  };

  const openModal = () => {
    setForm({ productId: '', productName: '', type: 'add', quantity: 1, reason: '' });
    setProdSearch('');
    setProdResults([]);
    setShowModal(true);
  };

  const selectedProduct = products.find(p => p._id === form.productId);

  const handleSave = async () => {
    if (!form.productId) return toast.error('Select a product');
    if (!form.reason.trim()) return toast.error('Reason is required');
    setSaving(true);
    try {
      const res = await fetch('/api/adjustments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ productId: form.productId, type: form.type, quantity: form.quantity, reason: form.reason }),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Failed'); }
      toast.success(`Stock ${form.type === 'add' ? 'added' : 'removed'} successfully`);
      setShowModal(false);
      fetchAdjustments();
      fetchAllProducts();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const typeColor = (t: string) => t === 'add' ? 'badge-green' : 'badge-red';
  const typeIcon = (t: string) => t === 'add' ? TrendingUp : TrendingDown;

  return (
    <div className="page-wrapper">
      <Topbar title="Stock Adjustments" subtitle="Add or remove inventory stock"
        actions={<button onClick={openModal} className="btn-primary"><Plus size={15} />New Adjustment</button>} />

      <div className="grid grid-cols-3 gap-4">
        <div className="card"><p className="text-2xl font-bold text-emerald-600">{adjustments.filter(a => a.type === 'add').length}</p><p className="text-sm text-gray-500 mt-1">Stock Added</p></div>
        <div className="card"><p className="text-2xl font-bold text-red-600">{adjustments.filter(a => a.type === 'remove').length}</p><p className="text-sm text-gray-500 mt-1">Stock Removed</p></div>
        <div className="card"><p className="text-2xl font-bold text-blue-600">{adjustments.length}</p><p className="text-sm text-gray-500 mt-1">Total Adjustments</p></div>
      </div>

      {products.length > 0 && (
        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Current Stock Levels <span className="text-xs text-gray-400 font-normal ml-2">(showing first 30)</span></h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3">
            {products.slice(0, 30).map(p => {
              const stock = p.stock || 0;
              const minStock = p.reorderLevel || 0;
              const pct = minStock > 0 ? Math.min((stock / (minStock * 3)) * 100, 100) : Math.min(stock / 10, 100);
              const isLow = minStock > 0 && stock <= minStock;
              return (
                <div key={p._id} className={`p-4 border rounded-xl flex items-start gap-3 ${isLow ? 'border-red-200 bg-red-50/30' : 'border-gray-100'}`}>
                  {p.image ? (
                    <img src={`${IMAGE_BASE}${p.image}`} alt={p.name} className="w-10 h-10 rounded-lg object-cover flex-shrink-0" onError={e => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                  ) : (
                    <div className="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center flex-shrink-0"><Package size={16} className="text-gray-400" /></div>
                  )}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1 mb-1">
                      <p className="font-medium text-gray-900 text-sm truncate">{p.name}</p>
                      {isLow && <span className="badge badge-red text-[10px] flex-shrink-0">Low</span>}
                    </div>
                    <div className="bg-gray-100 rounded-full h-1.5 mb-1">
                      <div className={`h-1.5 rounded-full ${isLow ? 'bg-red-400' : 'bg-emerald-400'}`} style={{ width: `${pct}%` }} />
                    </div>
                    <div className="flex justify-between text-xs text-gray-500">
                      <span>{stock} {p.unit || 'PCS'}</span>
                      {minStock > 0 && <span>Min: {minStock}</span>}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Adjustment History</h3>
        {loadingAdj ? (
          <div className="flex items-center justify-center py-12 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
        ) : adjustments.length === 0 ? (
          <div className="text-center py-12 text-gray-400">
            <ArrowLeftRight size={36} className="mx-auto mb-2 opacity-30" />
            <p>No adjustments yet. Create the first one using &quot;New Adjustment&quot;.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 text-xs text-gray-500">
                  {['Date', 'Product', 'Code', 'Type', 'Qty', 'Previous', 'New Stock', 'Reason'].map(h => (
                    <th key={h} className="py-3 pr-4 font-medium text-left">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {adjustments.map(a => {
                  const Icon = typeIcon(a.type);
                  return (
                    <tr key={a._id} className="border-b border-gray-100 hover:bg-gray-50">
                      <td className="py-3 pr-4 text-gray-500 text-xs">{formatDate(a.createdAt)}</td>
                      <td className="py-3 pr-4 font-medium text-gray-900">{a.productName}</td>
                      <td className="py-3 pr-4 text-gray-400 font-mono text-xs">{a.productCode}</td>
                      <td className="py-3 pr-4"><span className={`badge ${typeColor(a.type)} flex items-center gap-1 w-fit`}><Icon size={10} />{a.type}</span></td>
                      <td className="py-3 pr-4 font-bold">{a.type === 'remove' ? '-' : '+'}{a.quantity}</td>
                      <td className="py-3 pr-4 text-gray-500">{a.previousStock}</td>
                      <td className="py-3 pr-4 font-bold text-gray-900">{a.newStock}</td>
                      <td className="py-3 pr-4 text-gray-500 text-xs max-w-[160px] truncate">{a.reason}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title="New Stock Adjustment"
        footer={
          <>
            <button onClick={() => setShowModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="btn-primary">{saving ? 'Saving...' : 'Apply Adjustment'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div>
            <label className="form-label">Product *</label>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5 pointer-events-none" />
              <input
                value={prodSearch}
                onChange={e => { setProdSearch(e.target.value); setShowProdDrop(true); setForm(f => ({ ...f, productId: '', productName: '' })); }}
                onFocus={() => setShowProdDrop(true)}
                placeholder="Type product name or code..."
                className="form-input pl-9"
              />
              {showProdDrop && prodResults.length > 0 && (
                <div className="absolute z-50 top-full left-0 right-0 bg-white border border-gray-200 rounded-xl shadow-lg mt-1 max-h-52 overflow-y-auto">
                  {prodResults.map(p => (
                    <button key={p._id} onMouseDown={() => selectProduct(p)} className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-blue-50 text-left">
                      {p.image ? (
                        <img src={`${IMAGE_BASE}${p.image}`} alt="" className="w-8 h-8 rounded object-cover flex-shrink-0" onError={e => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                      ) : (
                        <div className="w-8 h-8 bg-gray-100 rounded flex items-center justify-center flex-shrink-0"><Package size={14} className="text-gray-400" /></div>
                      )}
                      <div>
                        <p className="text-sm font-medium text-gray-900">{p.name}</p>
                        <p className="text-xs text-gray-400">{p.code} · Stock: {p.stock ?? 0}</p>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div>
            <label className="form-label">Adjustment Type</label>
            <select value={form.type} onChange={e => setForm({ ...form, type: e.target.value as 'add' | 'remove' })} className="form-input">
              <option value="add">Add Stock (Received / Found)</option>
              <option value="remove">Remove Stock (Damaged / Lost)</option>
            </select>
          </div>
          <div>
            <label className="form-label">Quantity *</label>
            <input type="number" value={form.quantity} min="1" onChange={e => setForm({ ...form, quantity: Number(e.target.value) })} className="form-input" />
          </div>
          {selectedProduct && (
            <div className="bg-blue-50 rounded-xl p-3 text-sm flex items-center gap-3">
              {selectedProduct.image && (
                <img src={`${IMAGE_BASE}${selectedProduct.image}`} alt="" className="w-10 h-10 rounded-lg object-cover flex-shrink-0" onError={e => { (e.target as HTMLImageElement).style.display = 'none'; }} />
              )}
              <div>
                <span className="text-blue-700 font-medium">Current Stock: </span>
                <span className="font-bold text-blue-900">{selectedProduct.stock ?? 0} {selectedProduct.unit || 'PCS'}</span>
                <span className="mx-2 text-blue-400">→</span>
                <span className="font-bold text-blue-900">
                  {form.type === 'add'
                    ? (selectedProduct.stock ?? 0) + form.quantity
                    : Math.max(0, (selectedProduct.stock ?? 0) - form.quantity)
                  } {selectedProduct.unit || 'PCS'}
                </span>
              </div>
            </div>
          )}
          <div>
            <label className="form-label">Reason *</label>
            <input value={form.reason} onChange={e => setForm({ ...form, reason: e.target.value })} placeholder="Damaged goods, inventory count, etc." className="form-input" />
          </div>
        </div>
      </Modal>
    </div>
  );
}
