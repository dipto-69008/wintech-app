'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Building2, Plus, Search, Edit2, Trash2, Loader2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import toast from 'react-hot-toast';

interface Supplier {
  _id: string; code: string; name: string; type?: string; phone?: string;
  mobile?: string; email?: string; address?: string; contactPerson?: string;
  previousDue?: number; status: string;
}
const emptyForm = () => ({ code:'', name:'', type:'', phone:'', mobile:'', email:'', address:'', contactPerson:'', previousDue:'0', status:'a' });

export default function SuppliersPage() {
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Supplier | null>(null);
  const [form, setForm] = useState(emptyForm());

  const fetch_ = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch(`/api/suppliers?search=${encodeURIComponent(search)}&limit=100`);
      const d = await r.json(); setSuppliers(d.data||[]); setTotal(d.total||0);
    } catch { toast.error('Could not load suppliers'); } finally { setLoading(false); }
  }, [search]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (s: Supplier) => {
    setEditing(s);
    setForm({ code:s.code, name:s.name, type:s.type||'', phone:s.phone||'', mobile:s.mobile||'',
      email:s.email||'', address:s.address||'', contactPerson:s.contactPerson||'',
      previousDue:String(s.previousDue||0), status:s.status });
    setShowModal(true);
  };
  const handleSave = async () => {
    if (!form.name) return toast.error('Supplier name required');
    setSaving(true);
    try {
      const res = await fetch(editing?`/api/suppliers/${editing._id}`:'/api/suppliers',
        { method:editing?'PUT':'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({...form,previousDue:parseFloat(form.previousDue)||0}) });
      if (!res.ok) { const e=await res.json(); throw new Error(e.error); }
      toast.success(editing?'Updated':'Supplier added'); setShowModal(false); fetch_();
    } catch(err:unknown){ toast.error(err instanceof Error?err.message:'Save failed'); } finally { setSaving(false); }
  };
  const handleDelete = async (s: Supplier) => {
    if (!confirm(`Delete "${s.name}"?`)) return;
    await fetch(`/api/suppliers/${s._id}`,{method:'DELETE'}); toast.success('Deleted'); fetch_();
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Suppliers" subtitle={`${total} suppliers in database`}
        actions={<button onClick={openAdd} className="btn-primary"><Plus size={15}/>Add Supplier</button>} />
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[{label:'Total Suppliers',value:total,color:'blue'},{label:'Active',value:suppliers.filter(s=>s.status==='a').length,color:'emerald'},
          {label:'With Due',value:suppliers.filter(s=>(s.previousDue||0)>0).length,color:'amber'},
          {label:'Total Due',value:`৳${suppliers.reduce((a,s)=>a+(s.previousDue||0),0).toLocaleString()}`,color:'red'}
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
            <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search suppliers..." className="form-input pl-9 w-64"/></div>
          <span className="text-sm text-gray-400">{suppliers.length} shown</span>
        </div>
        {loading ? <div className="flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20}/>Loading...</div>
        : suppliers.length===0 ? <div className="text-center py-16 text-gray-400"><Building2 size={40} className="mx-auto mb-3 opacity-30"/><p className="font-medium">No suppliers found</p><p className="text-xs mt-1">Run SQL migration or add manually</p></div>
        : <div className="overflow-x-auto"><table className="w-full text-sm">
            <thead><tr className="border-b border-gray-200 dark:border-gray-700 text-xs text-gray-500">
              {['Code','Name','Type','Phone','Mobile','Contact Person','Previous Due','Status',''].map(h=><th key={h} className="py-3 pr-4 font-medium text-left">{h}</th>)}
            </tr></thead>
            <tbody>{suppliers.map(s=>(
              <tr key={s._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                <td className="py-3 pr-4 font-mono text-xs text-gray-500">{s.code}</td>
                <td className="py-3 pr-4 font-medium text-gray-900 dark:text-white">{s.name}</td>
                <td className="py-3 pr-4 text-gray-500">{s.type||'—'}</td>
                <td className="py-3 pr-4 text-gray-500">{s.phone||'—'}</td>
                <td className="py-3 pr-4 text-gray-500">{s.mobile||'—'}</td>
                <td className="py-3 pr-4 text-gray-500">{s.contactPerson||'—'}</td>
                <td className="py-3 pr-4 font-medium text-red-500">{(s.previousDue||0)>0?`৳${(s.previousDue||0).toLocaleString()}`:'—'}</td>
                <td className="py-3 pr-4"><span className={`badge ${s.status==='a'?'badge-green':'badge-gray'}`}>{s.status==='a'?'Active':'Inactive'}</span></td>
                <td className="py-3 text-right"><div className="flex items-center justify-end gap-2">
                  <button onClick={()=>openEdit(s)} className="icon-btn"><Edit2 size={14}/></button>
                  <button onClick={()=>handleDelete(s)} className="icon-btn text-red-400 hover:text-red-600"><Trash2 size={14}/></button>
                </div></td>
              </tr>
            ))}</tbody>
          </table></div>}
      </div>
      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Supplier' : 'Add Supplier'}
        size="lg"
        footer={
          <>
            <button className="btn-secondary" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn-primary" onClick={handleSave} disabled={saving}>{saving ? 'Saving...' : editing ? 'Update' : 'Add Supplier'}</button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-3">
          {[{label:'Code',key:'code'},{label:'Name *',key:'name'},{label:'Type',key:'type'},
            {label:'Contact Person',key:'contactPerson'},{label:'Phone',key:'phone'},{label:'Mobile',key:'mobile'},
            {label:'Email',key:'email'},{label:'Previous Due (৳)',key:'previousDue',type:'number'}
          ].map(f => <div key={f.key}><label className="form-label">{f.label}</label>
            <input type={f.type||'text'} className="form-input" value={(form as Record<string,string>)[f.key]} onChange={e=>setForm(p=>({...p,[f.key]:e.target.value}))}/></div>)}
          <div className="col-span-2"><label className="form-label">Address</label>
            <input className="form-input" value={form.address} onChange={e=>setForm(f=>({...f,address:e.target.value}))}/></div>
          <div><label className="form-label">Status</label>
            <select className="form-input" value={form.status} onChange={e=>setForm(f=>({...f,status:e.target.value}))}>
              <option value="a">Active</option><option value="d">Inactive</option></select></div>
        </div>
      </Modal>
    </div>
  );
}
