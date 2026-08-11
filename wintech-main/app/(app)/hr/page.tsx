'use client';
import { useState, useEffect, useCallback } from 'react';
import { useBranchStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import { Plus, Search, Edit2, Trash2, Users, Loader2, Mail, Phone, MapPin, Key } from 'lucide-react';
import toast from 'react-hot-toast';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Field } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

interface Employee {
  _id: string; employeeCode: string; name: string; designation?: string; department?: string;
  areaName?: string; contactNo?: string; email?: string; salary?: number; joinDate?: string;
  gender?: string; status: string; role?: string;
}

const emptyForm = () => ({
  employeeCode: '', name: '', designation: '', department: '', areaName: '',
  contactNo: '', email: '', password: '', role: 'employee',
  salary: '0', joinDate: new Date().toISOString().split('T')[0], gender: 'Male', status: 'a',
});

const ROLE_COLORS: Record<string, string> = {
  admin: 'bg-violet-100 text-violet-700',
  manager: 'bg-emerald-100 text-emerald-700',
  employee: 'bg-amber-100 text-amber-700',
};

const AVATAR_COLORS = [
  'from-blue-400 to-blue-600', 'from-emerald-400 to-emerald-600', 'from-purple-400 to-purple-600',
  'from-amber-400 to-amber-600', 'from-red-400 to-red-600', 'from-teal-400 to-teal-600',
  'from-pink-400 to-pink-600', 'from-indigo-400 to-indigo-600',
];

export default function HRPage() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Employee | null>(null);
  const [form, setForm] = useState(emptyForm());
  const { selectedBranchLegacyId } = useBranchStore();

  const fetch_ = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch(`/api/employees?search=${encodeURIComponent(search)}&limit=200${selectedBranchLegacyId ? `&branchId=${selectedBranchLegacyId}` : ''}`);
      const d = await r.json();
      setEmployees(d.data || []);
      setTotal(d.total || 0);
    } catch { toast.error('Could not load employees'); }
    finally { setLoading(false); }
  }, [search, selectedBranchLegacyId]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const openAdd = () => { setEditing(null); setForm(emptyForm()); setShowModal(true); };
  const openEdit = (e: Employee) => {
    setEditing(e);
    setForm({
      employeeCode: e.employeeCode, name: e.name, designation: e.designation || '',
      department: e.department || '', areaName: e.areaName || '',
      contactNo: e.contactNo || '', email: e.email || '', password: '',
      role: e.role || 'employee', salary: String(e.salary || 0),
      joinDate: e.joinDate ? e.joinDate.split('T')[0] : new Date().toISOString().split('T')[0],
      gender: e.gender || 'Male', status: e.status,
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.name) return toast.error('Employee name required');
    setSaving(true);
    try {
      const payload: Record<string, unknown> = {
        ...form, salary: parseFloat(form.salary) || 0, joinDate: form.joinDate || undefined,
      };
      // Don't overwrite password if editing and field left blank
      if (editing && !form.password) delete payload.password;
      const res = await fetch(editing ? `/api/employees/${editing._id}` : '/api/employees',
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error); }
      toast.success(editing ? 'Updated' : 'Employee added');
      setShowModal(false); fetch_();
    } catch (err: unknown) { toast.error(err instanceof Error ? err.message : 'Save failed'); }
    finally { setSaving(false); }
  };

  const handleDelete = async (e: Employee) => {
    if (!confirm(`Delete "${e.name}"?`)) return;
    await fetch(`/api/employees/${e._id}`, { method: 'DELETE' });
    toast.success('Deleted'); fetch_();
  };

  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [key]: e.target.value }));

  const totalPayroll = employees.reduce((a, e) => a + (e.salary || 0), 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Employees" subtitle={`${total} employees`}
        actions={<Button size="sm" onClick={openAdd}><Plus size={15} />Add Employee</Button>} />

      {/* Stats */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Employees', value: total, color: 'blue' },
          { label: 'Active', value: employees.filter(e => e.status === 'a').length, color: 'emerald' },
          { label: 'Departments', value: [...new Set(employees.map(e => e.department).filter(Boolean))].length, color: 'purple' },
          { label: 'Total Payroll', value: `৳${totalPayroll.toLocaleString()}`, color: 'amber' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Search */}
      <div className="flex items-center gap-3">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-3.5 h-3.5" />
          <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search employees..." className="form-input pl-9 w-full" />
        </div>
        <span className="text-sm text-gray-400">{employees.length} shown</span>
      </div>

      {/* Cards */}
      {loading ? (
        <div className="flex items-center justify-center py-16 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} />Loading...</div>
      ) : employees.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <Users size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium">No employees found</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4">
          {employees.map((e, i) => (
            <div key={e._id} className="card group hover:shadow-md transition-all relative">
              {/* Actions */}
              <div className="absolute top-3 right-3 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button onClick={() => openEdit(e)} className="p-1.5 text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg"><Edit2 size={13} /></button>
                <button onClick={() => handleDelete(e)} className="p-1.5 text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg"><Trash2 size={13} /></button>
              </div>

              {/* Avatar + name */}
              <div className="flex items-center gap-3 mb-4">
                <div className={`w-12 h-12 rounded-2xl bg-gradient-to-br ${AVATAR_COLORS[i % AVATAR_COLORS.length]} flex items-center justify-center text-white text-xl font-bold flex-shrink-0`}>
                  {e.name.charAt(0)}
                </div>
                <div className="min-w-0">
                  <p className="font-bold text-gray-900 dark:text-white truncate">{e.name}</p>
                  <p className="text-xs text-gray-500 truncate">{e.designation || '—'}</p>
                </div>
              </div>

              {/* Badges */}
              <div className="flex flex-wrap gap-1 mb-3">
                <span className={`badge ${e.status === 'a' ? 'badge-green' : 'badge-gray'} text-[10px]`}>
                  {e.status === 'a' ? 'Active' : 'Inactive'}
                </span>
                {e.role && (
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold ${ROLE_COLORS[e.role] || ROLE_COLORS.employee}`}>
                    {e.role}
                  </span>
                )}
                {e.department && (
                  <span className="text-[10px] bg-blue-50 dark:bg-blue-900/20 text-blue-600 px-2 py-0.5 rounded-full">{e.department}</span>
                )}
              </div>

              {/* Info rows */}
              <div className="space-y-1.5 text-xs">
                {e.contactNo && (
                  <div className="flex items-center gap-2 text-gray-500">
                    <Phone size={11} className="text-gray-400 flex-shrink-0" />
                    <span className="truncate">{e.contactNo}</span>
                  </div>
                )}
                {e.email && (
                  <div className="flex items-center gap-2 text-gray-500">
                    <Mail size={11} className="text-gray-400 flex-shrink-0" />
                    <span className="truncate">{e.email}</span>
                  </div>
                )}
                {e.areaName && (
                  <div className="flex items-center gap-2 text-gray-500">
                    <MapPin size={11} className="text-gray-400 flex-shrink-0" />
                    <span className="truncate">{e.areaName}</span>
                  </div>
                )}
              </div>

              {/* Footer */}
              {(e.salary || 0) > 0 && (
                <div className="mt-3 pt-3 border-t border-gray-100 dark:border-gray-700 flex items-center justify-between">
                  <span className="text-xs text-gray-400">Salary</span>
                  <span className="text-sm font-bold text-emerald-600">৳{(e.salary || 0).toLocaleString()}</span>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? 'Edit Employee' : 'Add Employee'}
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button onClick={handleSave} loading={saving}>{editing ? 'Update' : 'Add Employee'}</Button>
          </>
        }
      >
        <div className="grid grid-cols-2 gap-4">
          <Field label="Employee ID">
            <Input value={form.employeeCode} onChange={set('employeeCode')} placeholder="AUTO" />
          </Field>
          <Field label="Full Name" required>
            <Input value={form.name} onChange={set('name')} placeholder="Employee name" />
          </Field>
          <Field label="Designation">
            <Input value={form.designation} onChange={set('designation')} placeholder="e.g. Sr. Officer" />
          </Field>
          <Field label="Department">
            <Input value={form.department} onChange={set('department')} placeholder="e.g. Sales & Marketing" />
          </Field>
          <Field label="Area Name" className="col-span-2">
            <Input value={form.areaName} onChange={set('areaName')} placeholder="e.g. Cumilla 01" />
          </Field>
          <Field label="Official Number">
            <Input value={form.contactNo} onChange={set('contactNo')} placeholder="Phone number" />
          </Field>
          <Field label="Email">
            <Input type="email" value={form.email} onChange={set('email')} placeholder="employee@wintechagro.com" />
          </Field>
          <Field label={editing ? 'New Password (leave blank to keep)' : 'Password'}>
            <div className="relative">
              <Key size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
              <Input type="password" value={form.password} onChange={set('password')} placeholder={editing ? 'Leave blank to keep current' : 'Set login password'} className="pl-8" />
            </div>
          </Field>
          <Field label="Role">
            <Select value={form.role} onChange={set('role')}>
              <option value="employee">Employee</option>
              <option value="manager">Manager</option>
              <option value="admin">Admin</option>
            </Select>
          </Field>
          <Field label="Salary (৳)">
            <Input type="number" value={form.salary} onChange={set('salary')} min="0" />
          </Field>
          <Field label="Join Date">
            <Input type="date" value={form.joinDate} onChange={set('joinDate')} />
          </Field>
          <Field label="Gender">
            <Select value={form.gender} onChange={set('gender')}>
              <option>Male</option>
              <option>Female</option>
              <option>Other</option>
            </Select>
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
