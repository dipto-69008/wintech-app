'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Tag, Loader2, Plus, Edit2, Trash2, Search, Package } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Category {
  _id: string; name: string; description?: string; status: string; legacyId?: number;
}

const COLORS = [
  'from-blue-500 to-blue-600', 'from-emerald-500 to-emerald-600',
  'from-purple-500 to-purple-600', 'from-amber-500 to-amber-600',
  'from-red-500 to-red-600', 'from-indigo-500 to-indigo-600',
  'from-pink-500 to-pink-600', 'from-teal-500 to-teal-600',
];

const emptyForm = () => ({ name: '', description: '', status: 'a' });

export default function CategoriesPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [productCounts, setProductCounts] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [form, setForm] = useState(emptyForm());

  const fetchCategories = useCallback(async () => {
    setLoading(true);
    try {
      const [catR, prodR] = await Promise.all([
        fetch(`/api/categories?search=${encodeURIComponent(search)}`),
        fetch('/api/products?limit=2000'),
      ]);
      const catD = await catR.json();
      const prodD = await prodR.json();

      setCategories(catD.data || []);

      // build product-count map by categoryName
      const counts: Record<string, number> = {};
      for (const p of (prodD.data || [])) {
        const cat = p.categoryName || 'Uncategorized';
        counts[cat] = (counts[cat] || 0) + 1;
      }
      setProductCounts(counts);
    } catch { toast.error('Could not load categories'); }
    finally { setLoading(false); }
  }, [search]);

  useEffect(() => { fetchCategories(); }, [fetchCategories]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (c: Category) => {
    setEditing(c);
    setForm({ name: c.name, description: c.description || '', status: c.status });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name.trim()) return toast.error('Category name required');
    setSaving(true);
    try {
      const url = editing ? `/api/categories/${editing._id}` : '/api/categories';
      const method = editing ? 'PUT' : 'POST';
      const res = await fetch(url, {
        method, headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: form.name.trim(), description: form.description, status: form.status }),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Save failed'); }
      toast.success(editing ? 'Category updated' : 'Category added');
      setShowModal(false);
      fetchCategories();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (c: Category) => {
    if (!confirm(`Delete "${c.name}"? Products in this category will become uncategorized.`)) return;
    try {
      const res = await fetch(`/api/categories/${c._id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Delete failed');
      toast.success('Category deleted');
      fetchCategories();
    } catch { toast.error('Delete failed'); }
  };

  const active = categories.filter(c => c.status === 'a').length;
  const totalProducts = Object.values(productCounts).reduce((a, b) => a + b, 0);

  return (
    <div className="page-wrapper">
      <Topbar
        title="Product Categories"
        subtitle={`${categories.length} categories, ${totalProducts} products`}
        actions={<button onClick={openAdd} className="btn-primary"><Plus size={15} /> Add Category</button>}
      />

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        <div className="card"><p className="text-2xl font-bold text-blue-600">{categories.length}</p><p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Total Categories</p></div>
        <div className="card"><p className="text-2xl font-bold text-emerald-600">{active}</p><p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Active</p></div>
        <div className="card"><p className="text-2xl font-bold text-purple-600">{totalProducts}</p><p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Total Products</p></div>
      </div>

      {/* Search */}
      <div className="card py-3">
        <div className="relative max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={14} />
          <input
            value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search categories…" className="form-input pl-9 text-sm py-2"
          />
        </div>
      </div>

      {/* Grid */}
      {loading ? (
        <div className="card flex items-center justify-center py-16 gap-2 text-gray-400">
          <Loader2 className="animate-spin" size={20} /> Loading categories…
        </div>
      ) : categories.length === 0 ? (
        <div className="card text-center py-16 text-gray-400">
          <Tag size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium">No categories found</p>
          <p className="text-sm mt-1">Add your first category with the button above</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {categories.map((cat, i) => {
            const count = productCounts[cat.name] || 0;
            const maxCount = Math.max(...categories.map(c => productCounts[c.name] || 0), 1);
            return (
              <div key={cat._id} className="card hover:shadow-md transition-all group">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${COLORS[i % COLORS.length]} flex items-center justify-center flex-shrink-0`}>
                      <Tag size={17} className="text-white" />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900 dark:text-white text-sm">{cat.name}</h3>
                      {cat.description && <p className="text-xs text-gray-400 mt-0.5 line-clamp-1">{cat.description}</p>}
                    </div>
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => openEdit(cat)} className="icon-btn"><Edit2 size={13} /></button>
                    <button onClick={() => handleDelete(cat)} className="icon-btn text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"><Trash2 size={13} /></button>
                  </div>
                </div>

                <div className="space-y-2.5">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500 flex items-center gap-1.5"><Package size={12} /> Products</span>
                    <span className="font-bold text-gray-900 dark:text-white">{count}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">Status</span>
                    <span className={`badge ${cat.status === 'a' ? 'badge-green' : 'badge-gray'}`}>{cat.status === 'a' ? 'Active' : 'Inactive'}</span>
                  </div>
                  <div className="mt-3">
                    <div className="bg-gray-100 dark:bg-gray-700 rounded-full h-1.5">
                      <div
                        className={`h-1.5 rounded-full bg-gradient-to-r ${COLORS[i % COLORS.length]} transition-all duration-500`}
                        style={{ width: `${Math.min((count / maxCount) * 100, 100)}%` }}
                      />
                    </div>
                    <p className="text-[10px] text-gray-400 mt-1">{count} of {totalProducts} products</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Category' : 'Add Category'}
        footer={
          <>
            <button className="btn-secondary" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn-primary" onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : editing ? 'Update Category' : 'Add Category'}</button>
          </>
        }
      >
        <div className="space-y-4">
          <div>
            <label className="form-label">Category Name *</label>
            <input className="form-input" placeholder="e.g. Fish Feed, Chemicals…" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} autoFocus />
          </div>
          <div>
            <label className="form-label">Description</label>
            <textarea className="form-input" rows={2} placeholder="Optional description…" value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
          </div>
          <div>
            <label className="form-label">Status</label>
            <select className="form-input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value }))}>
              <option value="a">Active</option>
              <option value="d">Inactive</option>
            </select>
          </div>
        </div>
      </Modal>
    </div>
  );
}
