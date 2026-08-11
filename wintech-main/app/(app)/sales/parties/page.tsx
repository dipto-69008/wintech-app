'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import Link from 'next/link';
import { Users2, Plus, Search, Edit2, Trash2, Loader2, Eye, EyeOff } from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { PARTY_CODE_RANGES } from '@/lib/party-code-ranges';

interface Party {
  _id: string; code: string; name: string; type?: string; phone?: string;
  mobile?: string; email?: string; address?: string; area?: string;
  contactPerson?: string; ownerName?: string;
  creditLimit?: number; previousDue?: number; status: string;
}

const emptyForm = () => ({
  code: '', name: '', type: '', phone: '', mobile: '', email: '',
  address: '', area: '', contactPerson: '', ownerName: '',
  creditLimit: '0', previousDue: '0', status: 'a',
});

export default function SalesPartiesPage() {
  const [parties, setParties] = useState<Party[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Party | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [showCode, setShowCode] = useState(true);

  const fetch_ = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch(`/api/parties?search=${encodeURIComponent(search)}&limit=200`);
      const d = await r.json();
      setParties(d.data || []);
      setTotal(d.total || 0);
    } catch { toast.error('Could not load parties'); } finally { setLoading(false); }
  }, [search]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (c: Party) => {
    setEditing(c);
    setForm({
      code: c.code, name: c.name, type: c.type || '', phone: c.phone || '',
      mobile: c.mobile || '', email: c.email || '', address: c.address || '',
      area: c.area || '', contactPerson: c.contactPerson || '', ownerName: c.ownerName || '',
      creditLimit: String(c.creditLimit || 0), previousDue: String(c.previousDue || 0),
      status: c.status,
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name) return toast.error('Party name required');
    setSaving(true);
    try {
      const payload = {
        ...form,
        creditLimit: parseFloat(form.creditLimit) || 0,
        previousDue: parseFloat(form.previousDue) || 0,
      };
      const res = await fetch(editing ? `/api/parties/${editing._id}` : '/api/parties', {
        method: editing ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error); }
      toast.success(editing ? 'Updated' : 'Party added');
      setShowModal(false);
      fetch_();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (c: Party) => {
    if (!confirm(`Delete "${c.name}"?`)) return;
    await fetch(`/api/parties/${c._id}`, { method: 'DELETE' });
    toast.success('Deleted');
    fetch_();
  };

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const totalDue = parties.reduce((a, c) => a + (c.previousDue || 0), 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Parties" subtitle={`${total} parties in database`}
        actions={<Button onClick={openAdd} size="sm"><Plus size={15} />Add Party</Button>} />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Parties', value: total, color: 'blue' },
          { label: 'Active', value: parties.filter(c => c.status === 'a').length, color: 'emerald' },
          { label: 'With Due', value: parties.filter(c => (c.previousDue || 0) > 0).length, color: 'amber' },
          { label: 'Total Due', value: `৳${totalDue.toLocaleString()}`, color: 'red' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="font-bold text-sm text-gray-800 dark:text-white">Zone-wise Party Code Allocation</h2>
            <p className="text-xs text-gray-400 mt-1">Assigned ranges for new and existing party records</p>
          </div>
          <span className="text-xs text-blue-500 font-semibold">{PARTY_CODE_RANGES.length} ranges</span>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-2">
          {PARTY_CODE_RANGES.map(range => (
            <div key={`${range.zone}-${range.codeRange}`} className="rounded-xl border border-gray-100 dark:border-gray-700 bg-gray-50/70 dark:bg-gray-800/50 px-3 py-2">
              <p className="text-xs font-semibold text-gray-800 dark:text-gray-100">{range.zone}</p>
              <p className="text-[11px] font-mono text-blue-600 dark:text-blue-400 mt-0.5">{range.codeRange}</p>
              <p className="text-[10px] text-gray-500 mt-1">{range.assignedOfficer || 'Officer not assigned'}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="card">
        <div className="section-header">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
              <input value={search} onChange={e => setSearch(e.target.value)}
                placeholder="Search name, code, mobile…" className="form-input pl-9 w-64" />
            </div>
            <span className="text-sm text-gray-400">{parties.length} shown</span>
          </div>
          {/* Toggle party code column */}
          <button
            onClick={() => setShowCode(v => !v)}
            className="flex items-center gap-1.5 text-xs font-medium px-3 py-1.5 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            title={showCode ? 'Hide party code column' : 'Show party code column'}
          >
            {showCode ? <EyeOff size={13} /> : <Eye size={13} />}
            {showCode ? 'Hide Code' : 'Show Code'}
          </button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-16 gap-2 text-gray-400">
            <Loader2 className="animate-spin" size={20} />Loading...
          </div>
        ) : parties.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <Users2 size={40} className="mx-auto mb-3 opacity-30" />
            <p className="font-medium">No parties found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
                  <th className="py-3 pr-4 font-medium text-left">Name</th>
                  {showCode && <th className="py-3 pr-4 font-medium text-left">Code</th>}
                  <th className="py-3 pr-4 font-medium text-left">Area / Address</th>
                  <th className="py-3 pr-4 font-medium text-left">Type</th>
                  <th className="py-3 pr-4 font-medium text-left">Mobile</th>
                  <th className="py-3 pr-4 font-medium text-left">Owner</th>
                  <th className="py-3 pr-4 font-medium text-left">Credit Limit</th>
                  <th className="py-3 pr-4 font-medium text-left">Due</th>
                  <th className="py-3 pr-4 font-medium text-left">Status</th>
                  <th className="py-3 font-medium text-left"></th>
                </tr>
              </thead>
              <tbody>
                {parties.map(c => (
                  <tr key={c._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-3 pr-4 font-medium">
                      <Link href={`/sales/parties/${c._id}`} className="text-blue-600 hover:underline dark:text-blue-400">
                        {c.name}
                      </Link>
                    </td>
                    {showCode && (
                      <td className="py-3 pr-4 font-mono text-xs text-gray-500">{c.code || '—'}</td>
                    )}
                    <td className="py-3 pr-4 text-xs text-gray-500">
                      {c.area
                        ? <span className="font-medium text-gray-700 dark:text-gray-300">{c.area}</span>
                        : null}
                      {c.area && c.address ? <span className="text-gray-400"> · </span> : null}
                      {c.address || (!c.area ? '—' : null)}
                    </td>
                    <td className="py-3 pr-4 text-gray-500">{c.type || '—'}</td>
                    <td className="py-3 pr-4 text-gray-500">{c.mobile || c.phone || '—'}</td>
                    <td className="py-3 pr-4 text-gray-500">{c.ownerName || '—'}</td>
                    <td className="py-3 pr-4 text-gray-700 dark:text-gray-200">৳{(c.creditLimit || 0).toLocaleString()}</td>
                    <td className="py-3 pr-4 font-medium text-red-500">
                      {(c.previousDue || 0) > 0 ? `৳${(c.previousDue || 0).toLocaleString()}` : '—'}
                    </td>
                    <td className="py-3 pr-4">
                      <span className={`badge ${c.status === 'a' ? 'badge-green' : 'badge-gray'}`}>
                        {c.status === 'a' ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="py-3 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button onClick={() => openEdit(c)} className="icon-btn"><Edit2 size={14} /></button>
                        <button onClick={() => handleDelete(c)} className="icon-btn text-red-400 hover:text-red-600"><Trash2 size={14} /></button>
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
        title={editing ? 'Edit Party' : 'Add Party'}
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editing ? 'Update' : 'Add Party'}</Button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          <Field label="Party Name" required>
            <Input value={form.name} onChange={set('name')} placeholder="Enter party name" />
          </Field>
          <Field label="Party Code">
            <Input value={form.code} onChange={set('code')} placeholder="e.g. Com-1001" />
          </Field>
          <Field label="Area" className="col-span-2">
            <Input value={form.area} onChange={set('area')} placeholder="e.g. Cumilla Zone, Bogura, Jessore…" />
          </Field>
          <Field label="Address" className="col-span-2">
            <Input value={form.address} onChange={set('address')} placeholder="Full address" />
          </Field>
          <Field label="Type">
            <Select value={form.type} onChange={set('type')}>
              <option value="">— Select —</option>
              <option value="retail">Retail</option>
              <option value="wholesale">Wholesale</option>
              <option value="dealer">Dealer</option>
            </Select>
          </Field>
          <Field label="Owner Name">
            <Input value={form.ownerName} onChange={set('ownerName')} placeholder="Owner" />
          </Field>
          <Field label="Phone">
            <Input value={form.phone} onChange={set('phone')} placeholder="Phone number" />
          </Field>
          <Field label="Mobile">
            <Input value={form.mobile} onChange={set('mobile')} placeholder="Mobile number" />
          </Field>
          <Field label="Email">
            <Input type="email" value={form.email} onChange={set('email')} placeholder="email@example.com" />
          </Field>
          <Field label="Contact Person">
            <Input value={form.contactPerson} onChange={set('contactPerson')} placeholder="Contact name" />
          </Field>
          <Field label="Credit Limit (৳)">
            <Input type="number" value={form.creditLimit} onChange={set('creditLimit')} min="0" />
          </Field>
          <Field label="Previous Due (৳)">
            <Input type="number" value={form.previousDue} onChange={set('previousDue')} min="0" />
          </Field>
          <Field label="Status">
            <Select value={form.status} onChange={set('status')}>
              <option value="a">Active</option>
              <option value="d">Inactive</option>
            </Select>
          </Field>
        </div>
      </Modal>
    </div>
  );
}
