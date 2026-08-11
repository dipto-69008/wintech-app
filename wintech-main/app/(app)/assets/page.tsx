'use client';
import { useState, useEffect, useCallback } from 'react';
import { useBranchStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import { HardDrive, Plus, Edit2, Trash2, Search, TrendingDown, CheckCircle2, AlertTriangle, Boxes, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

interface Asset {
  _id: string; name: string; category: string; serialNumber?: string;
  purchaseDate: string; purchaseCost: number; currentValue: number;
  depreciationRate: number; location: string; assignedTo?: string;
  status: 'active' | 'disposed' | 'under-maintenance';
}

const statusBadge: Record<string, string> = {
  active: 'badge-green', disposed: 'badge-gray', 'under-maintenance': 'badge-yellow',
};
const CATEGORIES = ['IT Equipment', 'Vehicle', 'Furniture', 'Machinery', 'Building', 'Other'];
const emptyForm = () => ({ name: '', category: 'IT Equipment', serialNumber: '', purchaseDate: '', purchaseCost: '', currentValue: '', depreciationRate: '10', location: '', assignedTo: '', status: 'active' as Asset['status'] });

export default function AssetsPage() {
  const [assets, setAssets] = useState<Asset[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Asset | null>(null);
  const [form, setForm] = useState(emptyForm());

  const { selectedBranchLegacyId } = useBranchStore();

  const fetchAssets = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (search) params.set('search', search);
      if (filterStatus !== 'all') params.set('status', filterStatus);
      if (selectedBranchLegacyId) params.set('branchId', String(selectedBranchLegacyId));
      const r = await fetch(`/api/assets?${params}`);
      const d = await r.json();
      setAssets(d.data || []);
    } catch { toast.error('Could not load assets'); }
    finally { setLoading(false); }
  }, [search, filterStatus, selectedBranchLegacyId]);

  useEffect(() => { fetchAssets(); }, [fetchAssets]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (a: Asset) => {
    setEditing(a);
    setForm({ name: a.name, category: a.category, serialNumber: a.serialNumber || '', purchaseDate: a.purchaseDate, purchaseCost: String(a.purchaseCost), currentValue: String(a.currentValue), depreciationRate: String(a.depreciationRate), location: a.location, assignedTo: a.assignedTo || '', status: a.status });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name || !form.location) return toast.error('Name and location required');
    setSaving(true);
    try {
      const payload = { ...form, purchaseCost: Number(form.purchaseCost) || 0, currentValue: Number(form.currentValue) || 0, depreciationRate: Number(form.depreciationRate) || 10 };
      const url = editing ? `/api/assets/${editing._id}` : '/api/assets';
      const method = editing ? 'PATCH' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) throw new Error('Save failed');
      toast.success(editing ? 'Asset updated' : 'Asset added');
      setShowModal(false);
      fetchAssets();
    } catch { toast.error('Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Delete asset "${name}"?`)) return;
    try {
      await fetch(`/api/assets/${id}`, { method: 'DELETE' });
      toast.success('Deleted');
      fetchAssets();
    } catch { toast.error('Delete failed'); }
  };

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const totalCost = assets.reduce((a, b) => a + b.purchaseCost, 0);
  const totalValue = assets.reduce((a, b) => a + b.currentValue, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Fixed Assets" subtitle="Track, manage and depreciate company assets"
        actions={<Button size="sm" onClick={openAdd}><Plus size={15} />Add Asset</Button>} />

      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Assets', value: assets.length, icon: Boxes, color: 'bg-blue-50 text-blue-600' },
          { label: 'Purchase Cost', value: `৳${(totalCost / 1000).toFixed(1)}K`, icon: HardDrive, color: 'bg-purple-50 text-purple-600' },
          { label: 'Current Value', value: `৳${(totalValue / 1000).toFixed(1)}K`, icon: CheckCircle2, color: 'bg-emerald-50 text-emerald-600' },
          { label: 'Total Depreciation', value: `৳${((totalCost - totalValue) / 1000).toFixed(1)}K`, icon: TrendingDown, color: 'bg-amber-50 text-amber-600' },
        ].map(k => (
          <div key={k.label} className="stat-card flex items-center gap-4">
            <div className={`icon-box ${k.color}`}><k.icon size={20} /></div>
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">{k.label}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white mt-0.5">{k.value}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="section-header">
          <div className="flex items-center gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search assets..." className="form-input pl-9 w-64 py-2" />
            </div>
            <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)} className="form-input w-44 py-2">
              <option value="all">All Status</option>
              <option value="active">Active</option>
              <option value="under-maintenance">Under Maintenance</option>
              <option value="disposed">Disposed</option>
            </select>
          </div>
          <p className="text-sm text-gray-400 font-medium">{assets.length} asset{assets.length !== 1 ? 's' : ''}</p>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-12 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} /> Loading...</div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead>
                <tr>{['Asset', 'Category', 'Purchase Date', 'Cost', 'Current Value', 'Depreciation', 'Location', 'Status', ''].map(h => (<th key={h} className="table-header">{h}</th>))}</tr>
              </thead>
              <tbody>
                {assets.map(a => {
                  const dep = a.purchaseCost - a.currentValue;
                  const depPct = a.purchaseCost > 0 ? ((dep / a.purchaseCost) * 100).toFixed(0) : '0';
                  return (
                    <tr key={a._id} className="table-row">
                      <td className="table-cell"><div><p className="font-semibold text-gray-900 dark:text-white">{a.name}</p>{a.serialNumber && <p className="text-xs text-gray-400">{a.serialNumber}</p>}</div></td>
                      <td className="table-cell"><span className="badge badge-blue">{a.category}</span></td>
                      <td className="table-cell text-gray-500">{a.purchaseDate}</td>
                      <td className="table-cell font-semibold">৳{a.purchaseCost.toLocaleString()}</td>
                      <td className="table-cell font-semibold text-emerald-600">৳{a.currentValue.toLocaleString()}</td>
                      <td className="table-cell"><div><p className="text-xs font-semibold text-amber-600">{depPct}% depreciated</p><div className="mt-1 h-1.5 w-24 bg-gray-100 rounded-full"><div className="h-1.5 bg-amber-400 rounded-full" style={{ width: `${depPct}%` }} /></div></div></td>
                      <td className="table-cell text-gray-500">{a.location}</td>
                      <td className="table-cell"><span className={`badge ${statusBadge[a.status] || 'badge-gray'}`}>{a.status}</span></td>
                      <td className="table-cell">
                        <div className="flex items-center gap-1">
                          <button onClick={() => openEdit(a)} className="p-1.5 hover:bg-blue-50 dark:hover:bg-blue-900/20 text-blue-500 rounded-lg"><Edit2 size={14} /></button>
                          <button onClick={() => handleDelete(a._id, a.name)} className="p-1.5 hover:bg-red-50 dark:hover:bg-red-900/20 text-red-400 rounded-lg"><Trash2 size={14} /></button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
                {assets.length === 0 && (
                  <tr><td colSpan={9} className="text-center py-12 text-gray-400"><AlertTriangle className="w-8 h-8 mx-auto mb-2 text-gray-300" /><p>No assets found</p></td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Asset' : 'Add Fixed Asset'}
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editing ? 'Update' : 'Save Asset'}</Button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          <Field label="Asset Name" required className="col-span-2">
            <Input value={form.name} onChange={set('name')} placeholder="Asset name" />
          </Field>
          <Field label="Category">
            <Select value={form.category} onChange={set('category')}>
              {CATEGORIES.map(c => <option key={c}>{c}</option>)}
            </Select>
          </Field>
          <Field label="Serial Number">
            <Input value={form.serialNumber} onChange={set('serialNumber')} placeholder="S/N" />
          </Field>
          <Field label="Purchase Date">
            <Input type="date" value={form.purchaseDate} onChange={set('purchaseDate')} />
          </Field>
          <Field label="Purchase Cost (৳)">
            <Input type="number" value={form.purchaseCost} onChange={set('purchaseCost')} min="0" />
          </Field>
          <Field label="Current Value (৳)">
            <Input type="number" value={form.currentValue} onChange={set('currentValue')} min="0" />
          </Field>
          <Field label="Depreciation Rate (%)">
            <Input type="number" value={form.depreciationRate} onChange={set('depreciationRate')} min="0" max="100" />
          </Field>
          <Field label="Location" required>
            <Input value={form.location} onChange={set('location')} placeholder="Office / Branch" />
          </Field>
          <Field label="Assigned To">
            <Input value={form.assignedTo} onChange={set('assignedTo')} placeholder="Employee name" />
          </Field>
          <Field label="Status" className="col-span-2">
            <Select value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as Asset['status'] }))}>
              <option value="active">Active</option>
              <option value="under-maintenance">Under Maintenance</option>
              <option value="disposed">Disposed</option>
            </Select>
          </Field>
        </div>
      </Modal>
    </div>
  );
}
