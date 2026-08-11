'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { useAuthStore, useERPStore, Branch } from '@/lib/store';
import {
  TrendingUp, Package, Users, ShoppingCart, DollarSign,
  ArrowRight, ArrowUpRight, Warehouse, Plus,
  Trash2, MapPin, Phone, UserCircle, Edit2, Loader2, Truck,
  AlertTriangle, CheckCircle2
} from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer,
  BarChart, Bar, CartesianGrid, PieChart, Pie, Cell, Legend
} from 'recharts';
import Link from 'next/link';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444', '#06b6d4'];

interface MonthlyData {
  month: string; year: number; monthNum: number;
  sales: number; dues: number; collection: number; previousDue: number;
}

interface MonthlySummary {
  monthly: MonthlyData[];
  totalRevenue: number; totalDues: number; totalCollection: number;
  thisMonthSales: number; thisMonthDues: number;
}

const salesWeekData = [
  { day: 'Mon', orders: 0 }, { day: 'Tue', orders: 0 },
  { day: 'Wed', orders: 0 }, { day: 'Thu', orders: 0 },
  { day: 'Fri', orders: 0 }, { day: 'Sat', orders: 0 }, { day: 'Sun', orders: 0 },
];

interface Stats {
  totalSales: number; totalPurchases: number; totalProducts: number;
  totalParties: number; totalEmployees: number; totalSuppliers: number;
  pendingOrders: number; recentSales: any[];
}


const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload?.length) return (
    <div className="bg-gray-900 text-white px-3 py-2 rounded-xl shadow-xl text-xs border border-white/10">
      <p className="font-bold mb-1 text-gray-300">{label}</p>
      {payload.map((p: any, i: number) => (
        <p key={i} style={{ color: p.color }}>
          {p.name}: {typeof p.value === 'number' && p.value > 1000 ? `৳${(p.value / 1000).toFixed(0)}K` : p.value}
        </p>
      ))}
    </div>
  );
  return null;
};

export default function DashboardPage() {
  const { user } = useAuthStore();
  const [branches, setBranches] = useState<Branch[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [monthlySummary, setMonthlySummary] = useState<MonthlySummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [showBranchModal, setShowBranchModal] = useState(false);
  const [editingBranch, setEditingBranch] = useState<Branch | null>(null);
  const [branchForm, setBranchForm] = useState({ name: '', location: '', manager: '', phone: '', status: 'active' as Branch['status'] });

  useEffect(() => {
    const fetchAll = async () => {
      setLoading(true);
      try {
        const [salesRes, purchasesRes, productsRes, partiesRes, employeesRes, suppliersRes, pendingRes, branchRes, monthlyRes] = await Promise.all([
          fetch('/api/sales?limit=6&status=a'),
          fetch('/api/purchases?limit=1'),
          fetch('/api/products?limit=1'),
          fetch('/api/parties?limit=1'),
          fetch('/api/employees?limit=1'),
          fetch('/api/suppliers?limit=1'),
          fetch('/api/sales?limit=1&status=pending'),
          fetch('/api/branches'),
          fetch('/api/monthly-summary?months=6'),
        ]);
        const [s, p, pr, c, e, su, pend, br, ms] = await Promise.all([
          salesRes.ok ? salesRes.json() : { data: [], total: 0 },
          purchasesRes.ok ? purchasesRes.json() : { total: 0 },
          productsRes.ok ? productsRes.json() : { total: 0 },
          partiesRes.ok ? partiesRes.json() : { total: 0 },
          employeesRes.ok ? employeesRes.json() : { total: 0 },
          suppliersRes.ok ? suppliersRes.json() : { total: 0 },
          pendingRes.ok ? pendingRes.json() : { total: 0 },
          branchRes.ok ? branchRes.json() : { data: [] },
          monthlyRes.ok ? monthlyRes.json() : null,
        ]);
        setStats({
          totalSales: s.total || 0, totalPurchases: p.total || 0,
          totalProducts: pr.total || 0, totalParties: c.total || 0,
          totalEmployees: e.total || 0, totalSuppliers: su.total || 0,
          pendingOrders: pend.total || 0, recentSales: s.data || [],
        });
        setBranches(br.data || []);
        if (ms) setMonthlySummary(ms);
      } catch { toast.error('Failed to load dashboard data'); }
      finally { setLoading(false); }
    };
    fetchAll();
  }, []);

  const openAddBranch = () => { setEditingBranch(null); setBranchForm({ name: '', location: '', manager: '', phone: '', status: 'active' }); setShowBranchModal(true); };
  const openEditBranch = (b: Branch) => { setEditingBranch(b); setBranchForm({ name: b.name, location: b.location ?? '', manager: b.manager ?? '', phone: b.phone ?? '', status: b.status }); setShowBranchModal(true); };
  const handleSaveBranch = async () => {
    if (!branchForm.name || !branchForm.location) return toast.error('Name and location required');
    try {
      if (editingBranch) {
        await fetch(`/api/branches/${editingBranch._id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(branchForm) });
        setBranches(prev => prev.map(b => b._id === editingBranch._id ? { ...b, ...branchForm } : b));
        toast.success('Branch updated');
      } else {
        const res = await fetch('/api/branches', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(branchForm) });
        const newB = await res.json();
        setBranches(prev => [...prev, newB]);
        toast.success('Branch added');
      }
    } catch { toast.error('Failed to save branch'); }
    setShowBranchModal(false);
  };
  const handleDeleteBranch = async (id: string, name: string) => {
    if (!confirm(`Delete branch "${name}"?`)) return;
    try {
      await fetch(`/api/branches/${id}`, { method: 'DELETE' });
      setBranches(prev => prev.filter(b => b._id !== id));
      toast.success('Branch deleted');
    } catch { toast.error('Failed to delete'); }
  };

  const kpis = stats ? [
    { label: 'Total Sales', value: stats.totalSales.toLocaleString(), sub: 'Approved invoices', icon: ShoppingCart, bg: 'from-blue-500 to-blue-600', link: '/sales', trend: '+8.2%' },
    { label: 'Products', value: stats.totalProducts.toLocaleString(), sub: 'In inventory', icon: Package, bg: 'from-emerald-500 to-emerald-600', link: '/inventory', trend: 'Active' },
    { label: 'Parties', value: stats.totalParties.toLocaleString(), sub: `${stats.totalSuppliers} suppliers`, icon: Users, bg: 'from-purple-500 to-purple-600', link: '/sales/parties', trend: '+3.1%' },
    { label: 'Purchases', value: stats.totalPurchases.toLocaleString(), sub: `${stats.pendingOrders} pending approval`, icon: Truck, bg: 'from-amber-500 to-amber-600', link: '/purchases', trend: stats.pendingOrders > 0 ? `${stats.pendingOrders} pending` : 'All clear' },
  ] : [];

  const pieData = stats ? [
    { name: 'Products', value: stats.totalProducts },
    { name: 'Parties', value: stats.totalParties },
    { name: 'Employees', value: stats.totalEmployees },
    { name: 'Suppliers', value: stats.totalSuppliers },
  ].filter(d => d.value > 0) : [];

  return (
    <div className="page-wrapper">
      <Topbar
        title={`Welcome back, ${user?.name?.split(' ')[0] ?? 'User'} 👋`}
        subtitle={formatDate(new Date())}
      />

      {loading ? (
        <div className="flex items-center justify-center py-20 text-gray-400 gap-3">
          <Loader2 className="animate-spin" size={22} /><span>Loading live data…</span>
        </div>
      ) : (
        <>
          {/* KPI Cards */}
          <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
            {kpis.map(k => (
              <Link key={k.label} href={k.link} className="stat-card group block hover:shadow-lg transition-all relative overflow-hidden">
                <div className={`absolute inset-0 bg-gradient-to-br ${k.bg} opacity-0 group-hover:opacity-[0.06] rounded-2xl transition-opacity`} />
                <div className="flex items-start justify-between">
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">{k.label}</p>
                    <p className="text-3xl font-black text-gray-900 dark:text-white mt-1 leading-none">{k.value}</p>
                    <p className="text-xs text-gray-500 font-medium mt-1.5">{k.sub}</p>
                  </div>
                  <div className={`w-11 h-11 bg-gradient-to-br ${k.bg} rounded-2xl flex items-center justify-center shadow-lg shadow-black/10`}>
                    <k.icon className="text-white w-5 h-5" />
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-gray-100 dark:border-gray-700/50 flex items-center justify-between text-xs">
                  <span className="text-gray-400">View all</span>
                  <span className="text-emerald-600 dark:text-emerald-400 font-semibold flex items-center gap-0.5">
                    <ArrowUpRight size={12} />{k.trend}
                  </span>
                </div>
              </Link>
            ))}
          </div>

          {/* Charts Row */}
          <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
            {/* Revenue Area Chart */}
            <div className="card xl:col-span-2">
              <div className="flex items-center justify-between mb-5">
                <div>
                  <h3 className="font-bold text-gray-900 dark:text-white text-sm">Revenue Overview</h3>
                  <p className="text-xs text-gray-400 mt-0.5">6-month sales vs outstanding vs collection</p>
                </div>
                <div className="flex gap-3 text-[11px]">
                  {[{c:'#3b82f6',l:'Sales'},{c:'#8b5cf6',l:'Outstanding'},{c:'#10b981',l:'Collection'}].map(({c,l}) => (
                    <span key={l} className="flex items-center gap-1.5 text-gray-500">
                      <span className="w-2.5 h-2.5 rounded-full" style={{backgroundColor:c}}/>{l}
                    </span>
                  ))}
                </div>
              </div>
              <ResponsiveContainer width="100%" height={220}>
                <AreaChart data={monthlySummary?.monthly ?? []} margin={{top:5,right:5,left:-20,bottom:0}}>
                  <defs>
                    <linearGradient id="gS" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#3b82f6" stopOpacity={0.18}/><stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/></linearGradient>
                    <linearGradient id="gP2" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#8b5cf6" stopOpacity={0.12}/><stop offset="95%" stopColor="#8b5cf6" stopOpacity={0}/></linearGradient>
                    <linearGradient id="gPr" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#10b981" stopOpacity={0.18}/><stop offset="95%" stopColor="#10b981" stopOpacity={0}/></linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" className="dark:stroke-gray-800" />
                  <XAxis dataKey="month" tick={{fontSize:11,fill:'#9ca3af'}} axisLine={false} tickLine={false}/>
                  <YAxis tick={{fontSize:11,fill:'#9ca3af'}} axisLine={false} tickLine={false} tickFormatter={v=>`৳${(v/1000).toFixed(0)}k`}/>
                  <Tooltip content={<CustomTooltip/>}/>
                  <Area type="monotone" dataKey="sales" stroke="#3b82f6" strokeWidth={2.5} fill="url(#gS)" name="Sales" dot={false}/>
                  <Area type="monotone" dataKey="dues" stroke="#8b5cf6" strokeWidth={2} fill="url(#gP2)" name="Outstanding" dot={false}/>
                  <Area type="monotone" dataKey="collection" stroke="#10b981" strokeWidth={2} fill="url(#gPr)" name="Collection" dot={false}/>
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* Weekly bar chart */}
            <div className="card">
              <div className="mb-5">
                <h3 className="font-bold text-gray-900 dark:text-white text-sm">This Week Orders</h3>
                <p className="text-xs text-gray-400 mt-0.5">Daily order activity</p>
              </div>
              <ResponsiveContainer width="100%" height={160}>
                <BarChart data={salesWeekData} margin={{top:0,right:0,left:-30,bottom:0}}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f5f5f5" vertical={false} className="dark:stroke-gray-800"/>
                  <XAxis dataKey="day" tick={{fontSize:11,fill:'#9ca3af'}} axisLine={false} tickLine={false}/>
                  <YAxis tick={{fontSize:11,fill:'#9ca3af'}} axisLine={false} tickLine={false}/>
                  <Tooltip cursor={{fill:'#f0f7ff'}} formatter={(v:any)=>[`${v} orders`,'Orders']}/>
                  <Bar dataKey="orders" fill="#3b82f6" radius={[6,6,0,0]}/>
                </BarChart>
              </ResponsiveContainer>
              <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-700 grid grid-cols-2 gap-3">
                <div className="text-center">
                  <p className="text-xl font-black text-gray-900 dark:text-white">{salesWeekData.reduce((a,b)=>a+b.orders,0)}</p>
                  <p className="text-xs text-gray-400">Total orders</p>
                </div>
                <div className="text-center">
                  <p className="text-xl font-black text-emerald-600">+18%</p>
                  <p className="text-xs text-gray-400">vs last week</p>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Sales + Business Overview */}
          <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
            {/* Recent Sales */}
            <div className="card xl:col-span-2">
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-bold text-gray-900 dark:text-white text-sm">Recent Sales</h3>
                <Link href="/sales" className="text-xs text-blue-600 hover:underline font-medium flex items-center gap-1">View all <ArrowRight size={12}/></Link>
              </div>
              {(stats?.recentSales || []).length === 0 ? (
                <div className="text-center py-8 text-gray-400">
                  <ShoppingCart className="w-8 h-8 mx-auto mb-2 opacity-40"/>
                  <p className="text-sm">No recent sales</p>
                </div>
              ) : (
                <div className="space-y-1.5">
                  {(stats?.recentSales || []).slice(0,5).map((s:any) => (
                    <div key={s._id} className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors">
                      <div className="w-9 h-9 bg-blue-50 dark:bg-blue-900/20 rounded-xl flex items-center justify-center flex-shrink-0">
                        <ShoppingCart className="w-4 h-4 text-blue-500"/>
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-800 dark:text-white truncate">{s.partyName || 'Walk-in Party'}</p>
                        <p className="text-xs text-gray-400 truncate font-mono">{s.invoiceNo} · {formatDate(s.saleDate)}</p>
                      </div>
                      <div className="text-right flex-shrink-0">
                        <p className="text-sm font-bold text-gray-900 dark:text-white">৳{(s.subTotal||0).toLocaleString()}</p>
                        <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded-full ${s.dueAmount>0?'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400':'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400'}`}>
                          {s.dueAmount>0?`Due ৳${s.dueAmount.toLocaleString()}`:'Paid'}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Pie chart + stats */}
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-white text-sm mb-4">Business Summary</h3>
              {pieData.length > 0 && (
                <ResponsiveContainer width="100%" height={150}>
                  <PieChart>
                    <Pie data={pieData} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={60} innerRadius={32}>
                      {pieData.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]}/>)}
                    </Pie>
                    <Tooltip formatter={(v:any,n:any)=>[v.toLocaleString(),n]}/>
                  </PieChart>
                </ResponsiveContainer>
              )}
              <div className="space-y-2 mt-2">
                {stats && [
                  { label: 'Products', val: stats.totalProducts, color: COLORS[0] },
                  { label: 'Parties', val: stats.totalParties, color: COLORS[1] },
                  { label: 'Employees', val: stats.totalEmployees, color: COLORS[2] },
                  { label: 'Suppliers', val: stats.totalSuppliers, color: COLORS[3] },
                ].map(item => (
                  <div key={item.label} className="flex items-center gap-2 text-xs">
                    <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{backgroundColor:item.color}}/>
                    <span className="text-gray-500 flex-1">{item.label}</span>
                    <span className="font-bold text-gray-700 dark:text-gray-300">{item.val.toLocaleString()}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Branches + Quick Actions */}
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
            {/* Branch Management */}
            <div className="card">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 bg-blue-50 dark:bg-blue-900/20 rounded-xl flex items-center justify-center">
                    <Warehouse className="w-4 h-4 text-blue-600"/>
                  </div>
                  <div>
                    <h3 className="font-bold text-gray-900 dark:text-white text-sm">Branches</h3>
                    <p className="text-xs text-gray-400">{branches.length} location{branches.length !== 1?'s':''}</p>
                  </div>
                </div>
                <button onClick={openAddBranch} className="btn-primary text-xs py-1.5 px-3"><Plus size={13}/> Add</button>
              </div>
              {branches.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-4">No branches yet</p>
              ) : (
                <div className="space-y-2">
                  {branches.map(b => (
                    <div key={b._id} className="flex items-center gap-3 p-3 border border-gray-100 dark:border-gray-700 rounded-xl hover:border-blue-200 dark:hover:border-blue-700 transition-all group">
                      <div className="w-9 h-9 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center shadow-sm flex-shrink-0">
                        <Warehouse className="w-4 h-4 text-white"/>
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-gray-900 dark:text-white text-sm truncate">{b.name}</p>
                        <p className="text-xs text-gray-400 flex items-center gap-1"><MapPin size={9}/>{b.location}</p>
                      </div>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${b.status==='active'?'bg-emerald-100 text-emerald-700':'bg-gray-100 text-gray-500'}`}>{b.status}</span>
                      <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={()=>openEditBranch(b)} className="p-1.5 text-blue-500 hover:bg-blue-100 dark:hover:bg-blue-900/20 rounded-lg"><Edit2 size={11}/></button>
                        <button onClick={()=>handleDeleteBranch(b._id,b.name)} className="p-1.5 text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg"><Trash2 size={11}/></button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Quick Actions */}
            <div className="card">
              <h3 className="font-bold text-gray-900 dark:text-white text-sm mb-4">Quick Actions</h3>
              <div className="grid grid-cols-2 gap-3">
                {[
                  { label: 'New Order Entry', href: '/sales/orders-entry', icon: ShoppingCart, color: 'bg-blue-50 text-blue-600 dark:bg-blue-900/20 hover:bg-blue-100' },
                  { label: 'Purchase Return', href: '/purchases/returns', icon: Truck, color: 'bg-orange-50 text-orange-600 dark:bg-orange-900/20 hover:bg-orange-100' },
                  { label: 'Cheque Entry', href: '/accounting/cheques', icon: DollarSign, color: 'bg-violet-50 text-violet-600 dark:bg-violet-900/20 hover:bg-violet-100' },
                  { label: 'Run Payroll', href: '/hr/payroll', icon: Users, color: 'bg-teal-50 text-teal-600 dark:bg-teal-900/20 hover:bg-teal-100' },
                  { label: 'Inventory', href: '/inventory', icon: Package, color: 'bg-emerald-50 text-emerald-600 dark:bg-emerald-900/20 hover:bg-emerald-100' },
                  { label: 'Reports', href: '/reports', icon: TrendingUp, color: 'bg-amber-50 text-amber-600 dark:bg-amber-900/20 hover:bg-amber-100' },
                ].map(q => (
                  <Link key={q.label} href={q.href} className={`flex items-center gap-3 p-3.5 rounded-2xl ${q.color} transition-colors`}>
                    <q.icon size={18} className="flex-shrink-0"/>
                    <span className="text-xs font-bold leading-tight">{q.label}</span>
                  </Link>
                ))}
              </div>
              {stats && stats.pendingOrders > 0 && (
                <Link href="/sales" className="mt-3 flex items-center gap-2.5 p-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/40 rounded-xl text-amber-700 dark:text-amber-400 text-xs font-medium hover:bg-amber-100 transition-colors">
                  <AlertTriangle size={14} className="flex-shrink-0"/>
                  <span><strong>{stats.pendingOrders}</strong> order{stats.pendingOrders>1?'s':''} waiting for admin approval</span>
                  <ArrowRight size={12} className="ml-auto"/>
                </Link>
              )}
            </div>
          </div>
        </>
      )}

      {/* Branch Modal */}
      <Modal
        open={showBranchModal}
        onClose={() => setShowBranchModal(false)}
        title={editingBranch ? 'Edit Branch' : 'Add Branch'}
        footer={
          <>
            <button onClick={() => setShowBranchModal(false)} className="btn-secondary">Cancel</button>
            <button onClick={handleSaveBranch} className="btn-primary">Save Branch</button>
          </>
        }
      >
        <div className="space-y-4">
          <div><label className="form-label">Branch Name *</label><input value={branchForm.name} onChange={e=>setBranchForm({...branchForm,name:e.target.value})} className="form-input" placeholder="e.g. Dhaka Head Office"/></div>
          <div><label className="form-label">Location *</label><input value={branchForm.location} onChange={e=>setBranchForm({...branchForm,location:e.target.value})} className="form-input" placeholder="e.g. Dhaka, Bangladesh"/></div>
          <div><label className="form-label">Manager</label><input value={branchForm.manager} onChange={e=>setBranchForm({...branchForm,manager:e.target.value})} className="form-input" placeholder="Manager name"/></div>
          <div><label className="form-label">Phone</label><input value={branchForm.phone} onChange={e=>setBranchForm({...branchForm,phone:e.target.value})} className="form-input" placeholder="+880..."/></div>
          <div><label className="form-label">Status</label>
            <select value={branchForm.status} onChange={e=>setBranchForm({...branchForm,status:e.target.value as Branch['status']})} className="form-input">
              <option value="active">Active</option><option value="inactive">Inactive</option>
            </select>
          </div>
        </div>
      </Modal>
    </div>
  );
}
