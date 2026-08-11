'use client';
import { useState } from 'react';
import Topbar from '@/components/layout/Topbar';
import { useAuthStore } from '@/lib/store';
import { Building2, User, Bell, Shield, Globe, Save, Camera, Lock, CheckSquare } from 'lucide-react';
import toast from 'react-hot-toast';

const TABS = [
  { id: 'company', label: 'Company', icon: Building2 },
  { id: 'profile', label: 'My Profile', icon: User },
  { id: 'notifications', label: 'Notifications', icon: Bell },
  { id: 'security', label: 'Security', icon: Shield },
  { id: 'localization', label: 'Localization', icon: Globe },
  { id: 'access', label: 'Page Access', icon: Lock },
];

const ALL_PAGES = [
  {
    section: 'Overview',
    pages: [
      { id: 'dashboard', label: 'Dashboard', path: '/dashboard' },
      { id: 'reports_sales', label: 'Sales Reports', path: '/reports/sales' },
      { id: 'reports_purchases', label: 'Purchase Reports', path: '/reports/purchases' },
      { id: 'reports_hr', label: 'HR Reports', path: '/reports/hr' },
      { id: 'reports_inventory', label: 'Inventory Reports', path: '/reports/inventory' },
      { id: 'reports_accounting', label: 'Accounting Reports', path: '/reports/accounting' },
    ],
  },
  {
    section: 'Inventory',
    pages: [
      { id: 'inventory', label: 'Products', path: '/inventory' },
      { id: 'inventory_categories', label: 'Categories', path: '/inventory/categories' },
      { id: 'inventory_adjustments', label: 'Stock Adjustments', path: '/inventory/adjustments' },
      { id: 'inventory_reports', label: 'Inventory Reports', path: '/inventory/reports' },
    ],
  },
  {
    section: 'Sales',
    pages: [
      { id: 'sales', label: 'Sale Orders', path: '/sales' },
      { id: 'sales_invoices', label: 'Invoices', path: '/sales/invoices' },
      { id: 'sales_returns', label: 'Returns', path: '/sales/returns' },
      { id: 'sales_quotations', label: 'Quotations', path: '/sales/quotations' },
      { id: 'sales_parties', label: 'Parties', path: '/sales/parties' },
      { id: 'sales_reports', label: 'Sales Reports', path: '/sales/reports' },
    ],
  },
  {
    section: 'Purchases',
    pages: [
      { id: 'purchases', label: 'Purchase Orders', path: '/purchases' },
      { id: 'purchases_suppliers', label: 'Suppliers', path: '/purchases/suppliers' },
      { id: 'purchases_reports', label: 'Purchase Reports', path: '/purchases/reports' },
    ],
  },
  {
    section: 'Accounting',
    pages: [
      { id: 'accounting', label: 'Transactions', path: '/accounting' },
      { id: 'accounting_accounts', label: 'Chart of Accounts', path: '/accounting/accounts' },
      { id: 'accounting_payroll', label: 'Payroll', path: '/accounting/payroll' },
      { id: 'accounting_budget', label: 'Budget', path: '/accounting/budget' },
    ],
  },
  {
    section: 'Expenses',
    pages: [
      { id: 'expenses', label: 'Expense Claims', path: '/expenses' },
      { id: 'expenses_categories', label: 'Expense Categories', path: '/expenses/categories' },
    ],
  },
  {
    section: 'HR',
    pages: [
      { id: 'hr', label: 'Employees', path: '/hr' },
      { id: 'hr_leaves', label: 'Leaves', path: '/hr/leaves' },
      { id: 'hr_attendance', label: 'Attendance', path: '/hr/attendance' },
      { id: 'hr_shift', label: 'Shift Roster', path: '/hr/shift' },
      { id: 'hr_holiday', label: 'Holidays', path: '/hr/holiday' },
      { id: 'hr_designation', label: 'Designations', path: '/hr/designation' },
      { id: 'hr_department', label: 'Departments', path: '/hr/department' },
      { id: 'hr_announcements', label: 'Announcements', path: '/hr/announcements' },
      { id: 'hr_reports', label: 'HR Reports', path: '/hr/reports' },
    ],
  },
  {
    section: 'CRM',
    pages: [
      { id: 'crm', label: 'All Leads', path: '/crm' },
      { id: 'crm_followups', label: 'Follow-ups', path: '/crm/followups' },
      { id: 'crm_parties', label: 'CRM Parties', path: '/crm/parties' },
    ],
  },
  {
    section: 'Projects',
    pages: [
      { id: 'projects', label: 'All Projects', path: '/projects' },
      { id: 'projects_tasks', label: 'Tasks', path: '/projects/tasks' },
    ],
  },
  {
    section: 'Assets',
    pages: [
      { id: 'assets', label: 'Fixed Assets', path: '/assets' },
      { id: 'assets_depreciation', label: 'Depreciation', path: '/assets/depreciation' },
    ],
  },
  {
    section: 'Targets',
    pages: [
      { id: 'targets', label: 'Add Target', path: '/targets' },
      { id: 'targets_report', label: 'Target Report', path: '/targets/report' },
    ],
  },
  {
    section: 'Admin',
    pages: [
      { id: 'settings', label: 'Settings', path: '/settings' },
    ],
  },
];

const allPageIds = ALL_PAGES.flatMap(s => s.pages.map(p => p.id));

type RoleKey = 'admin' | 'manager' | 'employee';

const defaultAccess: Record<RoleKey, Record<string, boolean>> = {
  admin: Object.fromEntries(allPageIds.map(id => [id, true])),
  manager: Object.fromEntries(allPageIds.map(id => [id, !['settings', 'accounting_budget', 'accounting_payroll'].includes(id)])),
  employee: Object.fromEntries(allPageIds.map(id => [id, ['dashboard', 'sales', 'sales_invoices', 'inventory', 'hr', 'hr_leaves', 'hr_attendance', 'expenses', 'expenses_categories'].includes(id)])),
};

export default function SettingsPage() {
  const { user } = useAuthStore();
  const [tab, setTab] = useState('company');
  const [company, setCompany] = useState({
    name: 'Wintech Agro BD',
    email: 'contact@wintechagro.com',
    phone: '+880 1711-000000',
    website: 'www.wintechagro.com.bd',
    address: 'Camila Depot, Chittagong, Bangladesh',
    currency: 'BDT',
    timezone: 'Asia/Dhaka',
    fiscalYear: 'January',
    logo: '',
  });
  const [notifs, setNotifs] = useState({ lowStock: true, newOrder: true, payment: true, newLead: true, payroll: true, announcements: false });
  const [selectedRole, setSelectedRole] = useState<RoleKey>('manager');
  const [access, setAccess] = useState<Record<RoleKey, Record<string, boolean>>>(defaultAccess);

  const save = () => toast.success('Settings saved!');

  const togglePage = (pageId: string) => {
    if (selectedRole === 'admin') return;
    setAccess(prev => ({
      ...prev,
      [selectedRole]: { ...prev[selectedRole], [pageId]: !prev[selectedRole][pageId] },
    }));
  };

  const toggleSection = (sectionPages: { id: string }[]) => {
    if (selectedRole === 'admin') return;
    const allOn = sectionPages.every(p => access[selectedRole][p.id]);
    const newState = !allOn;
    setAccess(prev => ({
      ...prev,
      [selectedRole]: {
        ...prev[selectedRole],
        ...Object.fromEntries(sectionPages.map(p => [p.id, newState])),
      },
    }));
  };

  const totalEnabled = Object.values(access[selectedRole]).filter(Boolean).length;

  return (
    <div className="page-wrapper">
      <Topbar title="Settings" subtitle="Configure your ERP system preferences" />

      <div className="flex gap-6 flex-col lg:flex-row">
        <div className="lg:w-56 flex-shrink-0">
          <div className="card p-2 sticky top-24">
            <p className="text-[10px] font-bold text-gray-400 dark:text-gray-500 uppercase px-3 py-2">Configuration</p>
            {TABS.map(({ id, label, icon: Icon }) => (
              <button key={id} onClick={() => setTab(id)}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all ${tab === id ? 'bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400' : 'text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'}`}>
                <Icon size={15} className={tab === id ? 'text-blue-500' : 'text-gray-400 dark:text-gray-500'} />
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="flex-1 space-y-4">
          {/* Company */}
          {tab === 'company' && (
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-gray-100 mb-5 pb-4 border-b border-gray-100 dark:border-gray-700">Company Information</h3>
              <div className="flex items-center gap-4 mb-6">
                <div className="w-20 h-20 bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl flex items-center justify-center text-white text-2xl font-bold">O</div>
                <div>
                  <button className="btn-secondary text-xs"><Camera size={13} /> Change Logo</button>
                  <p className="text-xs text-gray-400 mt-1">PNG, JPG up to 2MB</p>
                </div>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div><label className="form-label">Company Name</label><input value={company.name} onChange={e => setCompany({ ...company, name: e.target.value })} className="form-input" /></div>
                <div><label className="form-label">Business Email</label><input type="email" value={company.email} onChange={e => setCompany({ ...company, email: e.target.value })} className="form-input" /></div>
                <div><label className="form-label">Phone</label><input value={company.phone} onChange={e => setCompany({ ...company, phone: e.target.value })} className="form-input" /></div>
                <div><label className="form-label">Website</label><input value={company.website} onChange={e => setCompany({ ...company, website: e.target.value })} className="form-input" /></div>
                <div className="col-span-1 sm:col-span-2"><label className="form-label">Address</label><textarea value={company.address} onChange={e => setCompany({ ...company, address: e.target.value })} className="form-input" rows={2} /></div>
                <div><label className="form-label">Default Currency</label>
                  <select value={company.currency} onChange={e => setCompany({ ...company, currency: e.target.value })} className="form-input">
                    <option value="BDT">BDT - Bangladeshi Taka</option>
                    <option value="USD">USD - US Dollar</option>
                    <option value="EUR">EUR - Euro</option>
                    <option value="GBP">GBP - British Pound</option>
                    <option value="INR">INR - Indian Rupee</option>
                  </select>
                </div>
                <div><label className="form-label">Fiscal Year Start</label>
                  <select value={company.fiscalYear} onChange={e => setCompany({ ...company, fiscalYear: e.target.value })} className="form-input">
                    {['January', 'April', 'July', 'October'].map(m => <option key={m}>{m}</option>)}
                  </select>
                </div>
              </div>
              <div className="mt-5 pt-4 border-t border-gray-100 dark:border-gray-700 flex justify-end">
                <button onClick={save} className="btn-primary"><Save size={15} />Save Changes</button>
              </div>
            </div>
          )}

          {/* Profile */}
          {tab === 'profile' && (
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-gray-100 mb-5 pb-4 border-b border-gray-100 dark:border-gray-700">My Profile</h3>
              <div className="flex items-center gap-5 mb-6">
                <div className="w-20 h-20 bg-gradient-to-br from-blue-500 to-purple-600 rounded-2xl flex items-center justify-center text-white text-3xl font-bold">{user?.name?.charAt(0)}</div>
                <div>
                  <h4 className="text-xl font-bold text-gray-900 dark:text-gray-100">{user?.name}</h4>
                  <p className="text-gray-500 text-sm">{user?.email}</p>
                  <span className="badge badge-blue capitalize mt-1">{user?.role}</span>
                </div>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div><label className="form-label">Full Name</label><input defaultValue={user?.name} className="form-input" /></div>
                <div><label className="form-label">Email Address</label><input defaultValue={user?.email} className="form-input" /></div>
                <div><label className="form-label">Phone</label><input placeholder="+880 1711-000000" className="form-input" /></div>
                <div><label className="form-label">Department</label><input placeholder="e.g. Engineering" className="form-input" /></div>
              </div>
              <div className="mt-5 pt-4 border-t border-gray-100 dark:border-gray-700 flex justify-end">
                <button onClick={save} className="btn-primary"><Save size={15} />Update Profile</button>
              </div>
            </div>
          )}

          {/* Notifications */}
          {tab === 'notifications' && (
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-gray-100 mb-5 pb-4 border-b border-gray-100 dark:border-gray-700">Notification Preferences</h3>
              <div className="space-y-1">
                {[
                  { key: 'lowStock', label: 'Low Stock Alerts', desc: 'When products fall below minimum stock level' },
                  { key: 'newOrder', label: 'New Sale Orders', desc: 'When a new sale order is created' },
                  { key: 'payment', label: 'Payment Updates', desc: 'When payment status changes' },
                  { key: 'newLead', label: 'New CRM Leads', desc: 'When a new lead is added to CRM' },
                  { key: 'payroll', label: 'Payroll Reminders', desc: 'Monthly payroll processing reminders' },
                  { key: 'announcements', label: 'Announcements', desc: 'Company-wide announcement notifications' },
                ].map(n => (
                  <div key={n.key} className="flex items-center justify-between py-4 border-b border-gray-50 dark:border-gray-700/50 last:border-0">
                    <div>
                      <p className="font-medium text-gray-900 dark:text-gray-100 text-sm">{n.label}</p>
                      <p className="text-xs text-gray-400 mt-0.5">{n.desc}</p>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer ml-6">
                      <input type="checkbox" checked={(notifs as any)[n.key]} onChange={e => setNotifs({ ...notifs, [n.key]: e.target.checked })} className="sr-only peer" />
                      <div className="w-10 h-5 bg-gray-200 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5" />
                    </label>
                  </div>
                ))}
              </div>
              <div className="mt-5 pt-4 border-t border-gray-100 dark:border-gray-700 flex justify-end">
                <button onClick={save} className="btn-primary"><Save size={15} />Save Preferences</button>
              </div>
            </div>
          )}

          {/* Security */}
          {tab === 'security' && (
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-gray-100 mb-5 pb-4 border-b border-gray-100 dark:border-gray-700">Change Password</h3>
              <div className="space-y-4 max-w-md">
                <div><label className="form-label">Current Password</label><input type="password" placeholder="••••••••" className="form-input" /></div>
                <div><label className="form-label">New Password</label><input type="password" placeholder="••••••••" className="form-input" /></div>
                <div><label className="form-label">Confirm New Password</label><input type="password" placeholder="••••••••" className="form-input" /></div>
              </div>
              <div className="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-xl">
                <p className="text-xs font-semibold text-blue-800 dark:text-blue-300 mb-1">Password Requirements</p>
                {['At least 8 characters', 'At least one uppercase letter', 'At least one number', 'At least one special character'].map(r => (
                  <p key={r} className="text-xs text-blue-600 dark:text-blue-400 flex items-center gap-1.5 mt-1">✓ {r}</p>
                ))}
              </div>
              <div className="mt-5 pt-4 border-t border-gray-100 dark:border-gray-700 flex justify-end">
                <button onClick={() => toast.success('Password changed!')} className="btn-primary"><Save size={15} />Update Password</button>
              </div>
            </div>
          )}

          {/* Localization */}
          {tab === 'localization' && (
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-gray-100 mb-5 pb-4 border-b border-gray-100 dark:border-gray-700">Localization Settings</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div><label className="form-label">Timezone</label>
                  <select value={company.timezone} onChange={e => setCompany({ ...company, timezone: e.target.value })} className="form-input">
                    <option value="Asia/Dhaka">Asia/Dhaka (GMT+6)</option>
                    <option value="UTC">UTC (GMT+0)</option>
                    <option value="America/New_York">America/New_York (GMT-5)</option>
                    <option value="Europe/London">Europe/London (GMT+0)</option>
                    <option value="Asia/Kolkata">Asia/Kolkata (GMT+5:30)</option>
                  </select>
                </div>
                <div><label className="form-label">Date Format</label>
                  <select className="form-input">
                    <option>DD/MM/YYYY</option>
                    <option>MM/DD/YYYY</option>
                    <option>YYYY-MM-DD</option>
                  </select>
                </div>
                <div><label className="form-label">Language</label>
                  <select className="form-input">
                    <option>English</option>
                    <option>বাংলা (Bengali)</option>
                    <option>Arabic</option>
                  </select>
                </div>
                <div><label className="form-label">Number Format</label>
                  <select className="form-input">
                    <option>1,000,000.00</option>
                    <option>1.000.000,00</option>
                    <option>1 000 000.00</option>
                  </select>
                </div>
              </div>
              <div className="mt-5 pt-4 border-t border-gray-100 dark:border-gray-700 flex justify-end">
                <button onClick={save} className="btn-primary"><Save size={15} />Save</button>
              </div>
            </div>
          )}

          {/* Page Access Control */}
          {tab === 'access' && (
            <div className="space-y-4">
              {/* Role selector */}
              <div className="card">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div>
                    <h3 className="font-bold text-gray-900 dark:text-gray-100">Page Access Control</h3>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Control which pages each role can access</p>
                  </div>
                  <div className="flex gap-2">
                    {(['admin', 'manager', 'employee'] as RoleKey[]).map(role => (
                      <button
                        key={role}
                        onClick={() => setSelectedRole(role)}
                        className={`px-4 py-2 rounded-xl text-sm font-semibold capitalize transition-all ${selectedRole === role ? 'bg-blue-600 text-white shadow-sm' : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'}`}
                      >
                        {role}
                      </button>
                    ))}
                  </div>
                </div>

                {selectedRole === 'admin' && (
                  <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl flex items-center gap-2">
                    <Shield size={14} className="text-blue-500 flex-shrink-0" />
                    <p className="text-xs text-blue-700 dark:text-blue-300 font-medium">Admin role always has access to all pages and cannot be restricted.</p>
                  </div>
                )}

                <div className="mt-4 flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
                  <span className="font-medium capitalize">{selectedRole} role — {totalEnabled} of {allPageIds.length} pages enabled</span>
                  {selectedRole !== 'admin' && (
                    <button
                      onClick={() => setAccess(prev => ({ ...prev, [selectedRole]: Object.fromEntries(allPageIds.map(id => [id, true])) }))}
                      className="text-blue-600 dark:text-blue-400 hover:underline font-semibold"
                    >
                      Enable all
                    </button>
                  )}
                </div>
              </div>

              {/* Page list by section */}
              {ALL_PAGES.map(section => {
                const allOn = section.pages.every(p => access[selectedRole][p.id]);
                const someOn = section.pages.some(p => access[selectedRole][p.id]);
                return (
                  <div key={section.section} className="card p-0 overflow-hidden">
                    {/* Section header */}
                    <div className="flex items-center justify-between px-5 py-3.5 bg-gray-50 dark:bg-gray-700/40 border-b border-gray-100 dark:border-gray-700">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => toggleSection(section.pages)}
                          disabled={selectedRole === 'admin'}
                          className={`w-5 h-5 rounded flex items-center justify-center border transition-all flex-shrink-0
                            ${allOn
                              ? 'bg-blue-600 border-blue-600 text-white'
                              : someOn
                              ? 'bg-blue-200 dark:bg-blue-800 border-blue-400 text-blue-600'
                              : 'border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700'
                            } ${selectedRole === 'admin' ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                        >
                          {(allOn || someOn) && <CheckSquare size={12} />}
                        </button>
                        <span className="font-bold text-sm text-gray-800 dark:text-gray-200">{section.section}</span>
                      </div>
                      <span className="text-[11px] text-gray-400 dark:text-gray-500 font-medium">
                        {section.pages.filter(p => access[selectedRole][p.id]).length}/{section.pages.length} pages
                      </span>
                    </div>

                    {/* Pages */}
                    <div className="divide-y divide-gray-50 dark:divide-gray-700/50">
                      {section.pages.map(page => {
                        const enabled = access[selectedRole][page.id];
                        return (
                          <div
                            key={page.id}
                            className={`flex items-center justify-between px-5 py-3 transition-colors ${selectedRole !== 'admin' ? 'hover:bg-gray-50 dark:hover:bg-gray-700/30 cursor-pointer' : ''}`}
                            onClick={() => togglePage(page.id)}
                          >
                            <div className="flex items-center gap-3">
                              <div className={`w-2 h-2 rounded-full flex-shrink-0 ${enabled ? 'bg-emerald-500' : 'bg-gray-300 dark:bg-gray-600'}`} />
                              <div>
                                <p className="text-sm font-medium text-gray-800 dark:text-gray-200">{page.label}</p>
                                <p className="text-[11px] text-gray-400 dark:text-gray-500 font-mono">{page.path}</p>
                              </div>
                            </div>
                            <label className="relative inline-flex items-center cursor-pointer" onClick={e => e.stopPropagation()}>
                              <input
                                type="checkbox"
                                checked={enabled}
                                disabled={selectedRole === 'admin'}
                                onChange={() => togglePage(page.id)}
                                className="sr-only peer"
                              />
                              <div className="w-9 h-5 bg-gray-200 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-4 peer-disabled:opacity-50" />
                            </label>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })}

              <div className="flex justify-end">
                <button onClick={() => toast.success('Access permissions saved!')} className="btn-primary">
                  <Save size={15} />Save Access Settings
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
