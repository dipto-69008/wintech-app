'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { Input, Field } from '@/components/ui/Input';
import { ImageUpload } from '@/components/ui/ImageUpload';
import {
  Plus, Search, Trash2, Edit2, Loader2, ClipboardList,
  Leaf, Store, Calendar, X, Eye, ChevronDown, ChevronUp
} from 'lucide-react';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';

// ── types ────────────────────────────────────────────────────────────────────
type SurveyType = 'farmer' | 'dealer';

interface Survey {
  _id: string; type: SurveyType; workerName: string; postingId?: string; visitDate: string;
  // farmer
  farmName?: string; farmerMobile?: string; village?: string; diseases?: string;
  wintechProducts?: string[]; prescription?: string;
  // dealer
  shopName?: string; dealerName?: string; dealerMobile?: string; bazarName?: string;
  wintechStock?: string; competitorProduct?: string; collectionAmount?: number; remarks?: string;
  // common
  photo?: string;
}

interface Product { _id: string; name: string; packSize?: string; }

// ── blank forms ──────────────────────────────────────────────────────────────
const emptyFarmer = () => ({
  type: 'farmer' as const,
  workerName: '', postingId: '', visitDate: new Date().toISOString().split('T')[0],
  farmName: '', farmerMobile: '', village: '', diseases: '',
  wintechProducts: [] as string[], prescription: '', photo: '',
});
const emptyDealer = () => ({
  type: 'dealer' as const,
  workerName: '', postingId: '', visitDate: new Date().toISOString().split('T')[0],
  shopName: '', dealerName: '', dealerMobile: '', bazarName: '',
  wintechStock: '', competitorProduct: '', collectionAmount: '', remarks: '', photo: '',
});

// ── helpers ──────────────────────────────────────────────────────────────────
const fmt = (d: string) => formatDate(d);

export default function SurveyPage() {
  const [tab, setTab] = useState<SurveyType>('farmer');
  const [surveys, setSurveys] = useState<Survey[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');

  const [showModal, setShowModal] = useState(false);
  const [modalType, setModalType] = useState<SurveyType>('farmer');
  const [editing, setEditing] = useState<Survey | null>(null);
  const [saving, setSaving] = useState(false);
  const [viewItem, setViewItem] = useState<Survey | null>(null);

  const [farmerForm, setFarmerForm] = useState(emptyFarmer());
  const [dealerForm, setDealerForm] = useState(emptyDealer());

  const [products, setProducts] = useState<Product[]>([]);
  const [prodSearch, setProdSearch] = useState('');
  const [prodOpen, setProdOpen] = useState(false);
  const [prescriptionOpen, setPrescriptionOpen] = useState(false);

  const [employees, setEmployees] = useState<{ _id: string; name: string }[]>([]);

  // load products and employees for dropdowns
  useEffect(() => {
    fetch('/api/products?limit=200').then(r => r.json()).then(d => setProducts(d.data || [])).catch(() => {});
    fetch('/api/employees?limit=500&status=active').then(r => r.json()).then(d => setEmployees(d.data || [])).catch(() => {});
  }, []);

  // filtered products
  const filteredProds = products.filter(p =>
    !prodSearch || p.name.toLowerCase().includes(prodSearch.toLowerCase())
  );

  const fetchSurveys = useCallback(async () => {
    setLoading(true);
    try {
      const p = new URLSearchParams({ type: tab, limit: '200' });
      if (search) p.set('search', search);
      if (fromDate) p.set('from', fromDate);
      if (toDate) p.set('to', toDate);
      const r = await fetch(`/api/surveys?${p}`);
      const d = await r.json();
      setSurveys(d.data || []);
      setTotal(d.total || 0);
    } catch { toast.error('Could not load surveys'); }
    finally { setLoading(false); }
  }, [tab, search, fromDate, toDate]);

  useEffect(() => { fetchSurveys(); }, [fetchSurveys]);

  // ── open modal ──────────────────────────────────────────────────────────────
  const openAdd = (type: SurveyType) => {
    setEditing(null); setModalType(type);
    if (type === 'farmer') setFarmerForm(emptyFarmer());
    else setDealerForm(emptyDealer());
    setPrescriptionOpen(false); setProdOpen(false);
    setShowModal(true);
  };

  const openEdit = (s: Survey) => {
    setEditing(s); setModalType(s.type);
    if (s.type === 'farmer') {
      setFarmerForm({
        type: 'farmer', workerName: s.workerName, postingId: s.postingId || '',
        visitDate: s.visitDate?.split('T')[0] || '',
        farmName: s.farmName || '', farmerMobile: s.farmerMobile || '',
        village: s.village || '', diseases: s.diseases || '',
        wintechProducts: s.wintechProducts || [], prescription: s.prescription || '',
        photo: s.photo || '',
      });
    } else {
      setDealerForm({
        type: 'dealer', workerName: s.workerName, postingId: s.postingId || '',
        visitDate: s.visitDate?.split('T')[0] || '',
        shopName: s.shopName || '', dealerName: s.dealerName || '',
        dealerMobile: s.dealerMobile || '', bazarName: s.bazarName || '',
        wintechStock: s.wintechStock || '', competitorProduct: s.competitorProduct || '',
        collectionAmount: String(s.collectionAmount ?? ''), remarks: s.remarks || '',
        photo: s.photo || '',
      });
    }
    setPrescriptionOpen(!!s.prescription);
    setShowModal(true);
  };

  // ── save ────────────────────────────────────────────────────────────────────
  const handleSave = async () => {
    const form = modalType === 'farmer' ? farmerForm : dealerForm;
    if (!form.workerName) return toast.error('Employee name required');
    if (!form.visitDate) return toast.error('Visit date required');
    if (modalType === 'farmer' && !(farmerForm.farmName || farmerForm.farmerMobile))
      return toast.error('Farm name or mobile required');
    if (modalType === 'dealer' && !dealerForm.shopName)
      return toast.error('Shop name required');

    setSaving(true);
    try {
      const payload = modalType === 'dealer'
        ? { ...dealerForm, collectionAmount: parseFloat(dealerForm.collectionAmount) || undefined }
        : farmerForm;
      const url = editing ? `/api/surveys/${editing._id}` : '/api/surveys';
      const res = await fetch(url, { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error); }
      toast.success(editing ? 'Updated' : 'Visit recorded');
      setShowModal(false); fetchSurveys();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (s: Survey) => {
    if (!confirm('Delete this visit record?')) return;
    await fetch(`/api/surveys/${s._id}`, { method: 'DELETE' });
    toast.success('Deleted'); fetchSurveys();
  };

  // toggle product in farmer form
  const toggleProduct = (name: string) => {
    setFarmerForm(f => ({
      ...f,
      wintechProducts: f.wintechProducts.includes(name)
        ? f.wintechProducts.filter(p => p !== name)
        : [...f.wintechProducts, name],
    }));
  };

  const farmerCount = tab === 'farmer' ? total : undefined;
  const dealerCount = tab === 'dealer' ? total : undefined;

  return (
    <div className="page-wrapper">
      <Topbar
        title="Survey"
        subtitle="SR field visit reports"
        actions={
          <Button size="sm" onClick={() => openAdd(tab)}>
            <Plus size={14} /> Add {tab === 'farmer' ? 'Farmer' : 'Dealer'} Visit
          </Button>
        }
      />

      {/* ── Summary cards ── */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Farmer Visits', value: tab === 'farmer' ? total : '—', color: 'emerald', icon: Leaf },
          { label: 'Dealer Visits', value: tab === 'dealer' ? total : '—', color: 'blue', icon: Store },
          { label: 'Records Shown', value: surveys.length, color: 'purple', icon: ClipboardList },
          { label: 'This Month', value: surveys.filter(s => {
            const d = new Date(s.visitDate);
            const now = new Date();
            return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
          }).length, color: 'amber', icon: Calendar },
        ].map(c => (
          <div key={c.label} className="card flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl bg-${c.color}-50 dark:bg-${c.color}-900/20 flex items-center justify-center flex-shrink-0`}>
              <c.icon size={18} className={`text-${c.color}-500`} />
            </div>
            <div>
              <p className={`text-xl font-bold text-${c.color}-600`}>{c.value}</p>
              <p className="text-xs text-gray-400">{c.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="card">
        {/* Tabs */}
        <div className="flex gap-1 mb-4 bg-gray-100 dark:bg-gray-800 rounded-xl p-1 w-fit">
          {(['farmer', 'dealer'] as SurveyType[]).map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${tab === t ? 'bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 shadow-sm' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'}`}>
              {t === 'farmer' ? <Leaf size={12} /> : <Store size={12} />}
              {t === 'farmer' ? 'Farmer Visits' : 'Dealer Visits'}
              {((t === 'farmer' && farmerCount !== undefined) || (t === 'dealer' && dealerCount !== undefined)) && (
                <span className={`rounded-full px-1.5 text-[10px] ${tab === t ? 'bg-blue-100 text-blue-700' : 'bg-gray-200 text-gray-500'}`}>
                  {t === 'farmer' ? farmerCount : dealerCount}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Filters */}
        <div className="section-header mb-4">
          <div className="flex flex-wrap gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search employee / name…" className="form-input pl-9 w-56" />
            </div>
            <div className="flex items-center gap-1">
              <Calendar size={14} className="text-gray-400" />
              <input type="date" value={fromDate} onChange={e => setFromDate(e.target.value)} className="form-input w-36" />
              <span className="text-gray-400 text-xs">to</span>
              <input type="date" value={toDate} onChange={e => setToDate(e.target.value)} className="form-input w-36" />
              {(fromDate || toDate) && <button onClick={() => { setFromDate(''); setToDate(''); }} className="text-gray-400 hover:text-red-500"><X size={14} /></button>}
            </div>
          </div>
          <span className="text-sm text-gray-400">{surveys.length} records</span>
        </div>

        {/* Table */}
        {loading ? (
          <div className="flex justify-center py-16"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : surveys.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            {tab === 'farmer' ? <Leaf size={40} className="mx-auto mb-3 opacity-30" /> : <Store size={40} className="mx-auto mb-3 opacity-30" />}
            <p className="font-medium">No {tab === 'farmer' ? 'farmer' : 'dealer'} visits recorded</p>
            <button onClick={() => openAdd(tab)} className="mt-3 text-blue-500 text-sm hover:underline">+ Add first visit</button>
          </div>
        ) : tab === 'farmer' ? (
          /* Farmer table */
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead><tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                {['Employee','Posting/ID','Date','Farm / Farmer','Mobile','Village','Products Used',''].map(h => (
                  <th key={h} className="py-3 pr-3 font-medium text-left">{h}</th>
                ))}
              </tr></thead>
              <tbody>{surveys.map(s => (
                <tr key={s._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                  <td className="py-2.5 pr-3 font-medium text-gray-900 dark:text-white">{s.workerName}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500 font-mono">{s.postingId || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{fmt(s.visitDate)}</td>
                  <td className="py-2.5 pr-3 text-gray-700 dark:text-gray-200">{s.farmName || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{s.farmerMobile || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{s.village || '—'}</td>
                  <td className="py-2.5 pr-3">
                    {s.wintechProducts && s.wintechProducts.length > 0
                      ? <div className="flex flex-wrap gap-1">{s.wintechProducts.slice(0, 2).map(p => <span key={p} className="text-[10px] bg-emerald-50 text-emerald-700 dark:bg-emerald-900/20 dark:text-emerald-400 px-1.5 py-0.5 rounded-full">{p}</span>)}{s.wintechProducts.length > 2 && <span className="text-[10px] text-gray-400">+{s.wintechProducts.length - 2}</span>}</div>
                      : <span className="text-gray-400 text-xs">—</span>}
                  </td>
                  <td className="py-2.5 text-right">
                    <div className="flex items-center justify-end gap-1">
                      <button onClick={() => setViewItem(s)} className="icon-btn text-blue-400"><Eye size={13} /></button>
                      <button onClick={() => openEdit(s)} className="icon-btn"><Edit2 size={13} /></button>
                      <button onClick={() => handleDelete(s)} className="icon-btn text-red-400 hover:text-red-600"><Trash2 size={13} /></button>
                    </div>
                  </td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        ) : (
          /* Dealer table */
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead><tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                {['Employee','Date','Shop','Dealer','Mobile','Bazar','Stock','Collection',''].map(h => (
                  <th key={h} className="py-3 pr-3 font-medium text-left">{h}</th>
                ))}
              </tr></thead>
              <tbody>{surveys.map(s => (
                <tr key={s._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                  <td className="py-2.5 pr-3 font-medium text-gray-900 dark:text-white">{s.workerName}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{fmt(s.visitDate)}</td>
                  <td className="py-2.5 pr-3 text-gray-700 dark:text-gray-200">{s.shopName || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{s.dealerName || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{s.dealerMobile || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{s.bazarName || '—'}</td>
                  <td className="py-2.5 pr-3 text-xs text-gray-500">{s.wintechStock || '—'}</td>
                  <td className="py-2.5 pr-3 font-medium text-emerald-600">{s.collectionAmount ? `৳${s.collectionAmount.toLocaleString()}` : '—'}</td>
                  <td className="py-2.5 text-right">
                    <div className="flex items-center justify-end gap-1">
                      <button onClick={() => setViewItem(s)} className="icon-btn text-blue-400"><Eye size={13} /></button>
                      <button onClick={() => openEdit(s)} className="icon-btn"><Edit2 size={13} /></button>
                      <button onClick={() => handleDelete(s)} className="icon-btn text-red-400 hover:text-red-600"><Trash2 size={13} /></button>
                    </div>
                  </td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </div>

      {/* ── Add/Edit Modal ── */}
      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={`${editing ? 'Edit' : 'Add'} ${modalType === 'farmer' ? 'Farmer Visit' : 'Dealer Visit'}`}
        size="xl"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editing ? 'Update' : 'Save Visit'}</Button>
          </>
        }
      >
        {modalType === 'farmer' ? (
          /* ── Farmer Visit Form ── */
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-3">
              <Field label="Employee Name" required className="col-span-1">
                <select className="form-input w-full" value={farmerForm.workerName}
                  onChange={e => setFarmerForm(f => ({ ...f, workerName: e.target.value }))}>
                  <option value="">— Select employee —</option>
                  {employees.map(emp => (
                    <option key={emp._id} value={emp.name}>{emp.name}</option>
                  ))}
                </select>
              </Field>
              <Field label="Posting / ID">
                <Input value={farmerForm.postingId} onChange={e => setFarmerForm(f => ({ ...f, postingId: e.target.value }))} placeholder="গড়বী/আইডি" />
              </Field>
              <Field label="Visit Date" required>
                <Input type="date" value={farmerForm.visitDate} onChange={e => setFarmerForm(f => ({ ...f, visitDate: e.target.value }))} />
              </Field>
            </div>

            <div className="border border-gray-100 dark:border-gray-700 rounded-xl p-4 space-y-3">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Farm / Farmer Details</p>
              <div className="grid grid-cols-3 gap-3">
                <Field label="Farm / Farmer Name">
                  <Input value={farmerForm.farmName} onChange={e => setFarmerForm(f => ({ ...f, farmName: e.target.value }))} placeholder="খামারের নাম" />
                </Field>
                <Field label="Mobile / WhatsApp">
                  <Input value={farmerForm.farmerMobile} onChange={e => setFarmerForm(f => ({ ...f, farmerMobile: e.target.value }))} placeholder="01XXXXXXXXX" />
                </Field>
                <Field label="Village / Union">
                  <Input value={farmerForm.village} onChange={e => setFarmerForm(f => ({ ...f, village: e.target.value }))} placeholder="গ্রাম/ইউনিয়ন" />
                </Field>
              </div>
              <Field label="New Diseases / Problems (optional)">
                <Input value={farmerForm.diseases} onChange={e => setFarmerForm(f => ({ ...f, diseases: e.target.value }))} placeholder="নতুন রোগ বা সমস্যা…" />
              </Field>

              {/* Wintech Products dropdown */}
              <div>
                <p className="form-label mb-1">Wintech Products Used</p>
                <div className="relative">
                  <button type="button" onClick={() => setProdOpen(o => !o)}
                    className="w-full flex items-center justify-between form-input text-sm text-left">
                    <span className={farmerForm.wintechProducts.length ? 'text-gray-800 dark:text-white' : 'text-gray-400'}>
                      {farmerForm.wintechProducts.length ? farmerForm.wintechProducts.join(', ') : 'Select products…'}
                    </span>
                    {prodOpen ? <ChevronUp size={14} className="text-gray-400" /> : <ChevronDown size={14} className="text-gray-400" />}
                  </button>
                  {prodOpen && (
                    <div className="absolute z-50 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl">
                      <div className="p-2 border-b border-gray-100 dark:border-gray-700">
                        <input value={prodSearch} onChange={e => setProdSearch(e.target.value)} placeholder="Search product…" className="form-input text-xs py-1.5 w-full" />
                      </div>
                      <div className="max-h-48 overflow-y-auto">
                        {filteredProds.map(p => {
                          const label = p.name + (p.packSize ? ` ${p.packSize}` : '');
                          const checked = farmerForm.wintechProducts.includes(label);
                          return (
                            <label key={p._id} className="flex items-center gap-2 px-3 py-2 hover:bg-blue-50 dark:hover:bg-blue-900/20 cursor-pointer text-sm border-b border-gray-50 dark:border-gray-700/40 last:border-0">
                              <input type="checkbox" checked={checked} onChange={() => toggleProduct(label)} className="rounded" />
                              <span className={checked ? 'text-blue-700 dark:text-blue-400 font-medium' : 'text-gray-700 dark:text-gray-300'}>{label}</span>
                            </label>
                          );
                        })}
                        {filteredProds.length === 0 && <p className="text-xs text-gray-400 px-3 py-3">No products found</p>}
                      </div>
                      {farmerForm.wintechProducts.length > 0 && (
                        <div className="p-2 border-t border-gray-100 dark:border-gray-700 flex flex-wrap gap-1">
                          {farmerForm.wintechProducts.map(p => (
                            <span key={p} className="flex items-center gap-1 text-[10px] bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400 px-2 py-0.5 rounded-full">
                              {p} <button onClick={() => toggleProduct(p)} className="ml-0.5 hover:text-red-500"><X size={9} /></button>
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {/* Prescription toggle */}
              <div>
                <button type="button" onClick={() => setPrescriptionOpen(o => !o)}
                  className="flex items-center gap-1.5 text-xs font-medium text-blue-600 hover:text-blue-700">
                  <Plus size={12} /> {prescriptionOpen ? 'Hide' : 'Add'} Prescription / Recommendation
                </button>
                {prescriptionOpen && (
                  <textarea rows={3} className="form-input w-full mt-2 text-sm resize-none"
                    placeholder="Write prescription / recommendation here…"
                    value={farmerForm.prescription}
                    onChange={e => setFarmerForm(f => ({ ...f, prescription: e.target.value }))} />
                )}
              </div>
            </div>

            {/* Photo */}
            <div>
              <p className="form-label mb-2">Photo (optional)</p>
              <ImageUpload value={farmerForm.photo} onChange={url => setFarmerForm(f => ({ ...f, photo: url }))} />
            </div>
          </div>
        ) : (
          /* ── Dealer Visit Form ── */
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-3">
              <Field label="Employee Name" required>
                <select className="form-input w-full" value={dealerForm.workerName}
                  onChange={e => setDealerForm(f => ({ ...f, workerName: e.target.value }))}>
                  <option value="">— Select employee —</option>
                  {employees.map(emp => (
                    <option key={emp._id} value={emp.name}>{emp.name}</option>
                  ))}
                </select>
              </Field>
              <Field label="Posting / ID">
                <Input value={dealerForm.postingId} onChange={e => setDealerForm(f => ({ ...f, postingId: e.target.value }))} placeholder="গড়বী/আইডি" />
              </Field>
              <Field label="Visit Date" required>
                <Input type="date" value={dealerForm.visitDate} onChange={e => setDealerForm(f => ({ ...f, visitDate: e.target.value }))} />
              </Field>
            </div>

            <div className="border border-gray-100 dark:border-gray-700 rounded-xl p-4 space-y-3">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Shop / Dealer Details</p>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Shop Name" required>
                  <Input value={dealerForm.shopName} onChange={e => setDealerForm(f => ({ ...f, shopName: e.target.value }))} placeholder="দোকানের নাম" />
                </Field>
                <Field label="Dealer Name">
                  <Input value={dealerForm.dealerName} onChange={e => setDealerForm(f => ({ ...f, dealerName: e.target.value }))} placeholder="ডিলারের নাম" />
                </Field>
                <Field label="Mobile / WhatsApp">
                  <Input value={dealerForm.dealerMobile} onChange={e => setDealerForm(f => ({ ...f, dealerMobile: e.target.value }))} placeholder="01XXXXXXXXX" />
                </Field>
                <Field label="Bazar / Market Name">
                  <Input value={dealerForm.bazarName} onChange={e => setDealerForm(f => ({ ...f, bazarName: e.target.value }))} placeholder="বাজার/মার্কেটের নাম" />
                </Field>
              </div>

              {/* Wintech Stock dropdown */}
              <div>
                <p className="form-label mb-1">Wintech Product Stock</p>
                <select className="form-input w-full" value={dealerForm.wintechStock}
                  onChange={e => setDealerForm(f => ({ ...f, wintechStock: e.target.value }))}>
                  <option value="">— Select stock level —</option>
                  <option value="High">High (পর্যাপ্ত)</option>
                  <option value="Medium">Medium (মাঝামাঝি)</option>
                  <option value="Low">Low (কম)</option>
                  <option value="Out of Stock">Out of Stock (নেই)</option>
                </select>
              </div>

              {/* Competitor product */}
              <Field label="New Competitor Product (optional)">
                <Input value={dealerForm.competitorProduct} onChange={e => setDealerForm(f => ({ ...f, competitorProduct: e.target.value }))} placeholder="প্রতিযোগী পণ্যের নাম…" />
              </Field>

              <div className="grid grid-cols-2 gap-3">
                <Field label="Collection Amount (optional)">
                  <Input type="number" value={dealerForm.collectionAmount} onChange={e => setDealerForm(f => ({ ...f, collectionAmount: e.target.value }))} placeholder="৳ 0" min="0" />
                </Field>
                <Field label="Remarks (optional)">
                  <Input value={dealerForm.remarks} onChange={e => setDealerForm(f => ({ ...f, remarks: e.target.value }))} placeholder="মন্তব্য…" />
                </Field>
              </div>
            </div>

            {/* Photo */}
            <div>
              <p className="form-label mb-2">Photo (optional)</p>
              <ImageUpload value={dealerForm.photo} onChange={url => setDealerForm(f => ({ ...f, photo: url }))} />
            </div>
          </div>
        )}
      </Modal>

      {/* ── View Modal ── */}
      <Modal open={!!viewItem} onClose={() => setViewItem(null)} title={viewItem ? (viewItem.type === 'farmer' ? 'Farmer Visit Details' : 'Dealer Visit Details') : ''} size="lg">
        {viewItem && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="col-span-2 flex items-center justify-between p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl">
                <div>
                  <p className="font-bold text-gray-900 dark:text-white">{viewItem.workerName}</p>
                  <p className="text-xs text-gray-500">{viewItem.postingId || 'No posting ID'} · {fmt(viewItem.visitDate)}</p>
                </div>
                <span className={`badge ${viewItem.type === 'farmer' ? 'badge-green' : 'badge-blue'}`}>
                  {viewItem.type === 'farmer' ? 'Farmer Visit' : 'Dealer Visit'}
                </span>
              </div>

              {viewItem.type === 'farmer' ? (<>
                {viewItem.farmName && <InfoPair label="Farm / Farmer" value={viewItem.farmName} />}
                {viewItem.farmerMobile && <InfoPair label="Mobile" value={viewItem.farmerMobile} />}
                {viewItem.village && <InfoPair label="Village/Union" value={viewItem.village} />}
                {viewItem.diseases && <InfoPair label="Diseases/Problems" value={viewItem.diseases} />}
                {viewItem.wintechProducts && viewItem.wintechProducts.length > 0 && (
                  <div className="col-span-2">
                    <p className="text-xs text-gray-400 mb-1">Products Used</p>
                    <div className="flex flex-wrap gap-1">
                      {viewItem.wintechProducts.map(p => <span key={p} className="text-xs bg-emerald-50 text-emerald-700 dark:bg-emerald-900/20 dark:text-emerald-400 px-2 py-0.5 rounded-full">{p}</span>)}
                    </div>
                  </div>
                )}
                {viewItem.prescription && <InfoPair label="Prescription" value={viewItem.prescription} span />}
              </>) : (<>
                {viewItem.shopName && <InfoPair label="Shop Name" value={viewItem.shopName} />}
                {viewItem.dealerName && <InfoPair label="Dealer Name" value={viewItem.dealerName} />}
                {viewItem.dealerMobile && <InfoPair label="Mobile" value={viewItem.dealerMobile} />}
                {viewItem.bazarName && <InfoPair label="Bazar/Market" value={viewItem.bazarName} />}
                {viewItem.wintechStock && <InfoPair label="Stock Level" value={viewItem.wintechStock} />}
                {viewItem.competitorProduct && <InfoPair label="Competitor Product" value={viewItem.competitorProduct} />}
                {viewItem.collectionAmount != null && <InfoPair label="Collection" value={`৳${viewItem.collectionAmount.toLocaleString()}`} />}
                {viewItem.remarks && <InfoPair label="Remarks" value={viewItem.remarks} span />}
              </>)}
            </div>

            {viewItem.photo && (
              <div>
                <p className="text-xs text-gray-400 mb-2">Photo</p>
                <img src={viewItem.photo} alt="Visit" className="rounded-xl max-h-64 object-cover w-full border border-gray-100 dark:border-gray-700" />
              </div>
            )}

            <div className="flex gap-2 pt-2">
              <Button variant="outline" className="flex-1" onClick={() => { setViewItem(null); openEdit(viewItem); }}><Edit2 size={13} /> Edit</Button>
              <Button variant="outline" className="flex-1 !text-red-500 !border-red-200 hover:!bg-red-50" onClick={() => { setViewItem(null); handleDelete(viewItem); }}><Trash2 size={13} /> Delete</Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}

function InfoPair({ label, value, span }: { label: string; value: string; span?: boolean }) {
  return (
    <div className={`p-3 bg-gray-50 dark:bg-gray-800 rounded-xl ${span ? 'col-span-2' : ''}`}>
      <p className="text-[10px] text-gray-400 uppercase tracking-wide font-medium mb-0.5">{label}</p>
      <p className="text-sm text-gray-800 dark:text-white">{value}</p>
    </div>
  );
}
