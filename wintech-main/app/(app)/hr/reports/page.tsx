'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import Link from 'next/link';
import { Users, Clock, CalendarDays, DollarSign, TrendingUp, ArrowRight, FileBarChart } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444'];

export default function HRReportsPage() {
  const { employees } = useERPStore();

  const totalPayroll = employees.filter(e => e.status === 'active').reduce((a, e) => a + e.salary, 0);
  const onLeave = employees.filter(e => e.status === 'on-leave').length;
  const active = employees.filter(e => e.status === 'active').length;

  const byDept = Object.entries(
    employees.reduce((acc, e) => { acc[e.department] = (acc[e.department] || 0) + 1; return acc; }, {} as Record<string, number>)
  ).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value);

  const bySalary = Object.entries(
    employees.reduce((acc, e) => { acc[e.department] = (acc[e.department] || 0) + e.salary; return acc; }, {} as Record<string, number>)
  ).map(([name, total]) => ({ name: name.length > 10 ? name.slice(0, 10) + '…' : name, total }));

  const reportLinks = [
    { title: 'Attendance Report', desc: 'Employee attendance records', href: '/hr/reports/attendance', icon: Clock, color: 'blue' },
    { title: 'Payroll Report', desc: 'Salary and payroll summary', href: '/hr/reports/payroll', icon: DollarSign, color: 'emerald' },
    { title: 'Leave Report', desc: 'Leave requests and balances', href: '/hr/reports/leaves', icon: CalendarDays, color: 'amber' },
    { title: 'Employee List', desc: 'Full employee directory', href: '/hr', icon: Users, color: 'purple' },
  ];

  return (
    <div className="page-wrapper">
      <Topbar title="HR Reports" subtitle="Human resource analytics and reports" />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Employees', value: employees.length, color: 'blue' },
          { label: 'Active', value: active, color: 'emerald' },
          { label: 'On Leave', value: onLeave, color: 'amber' },
          { label: 'Monthly Payroll', value: `$${(totalPayroll/12000).toFixed(0)}K`, color: 'purple' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Available Reports</h3>
          <div className="space-y-3">
            {reportLinks.map(r => (
              <Link key={r.href} href={r.href} className="group flex items-center gap-4 p-4 border border-gray-100 rounded-2xl hover:border-blue-200 hover:bg-blue-50/40 transition-all">
                <div className={`w-10 h-10 bg-${r.color}-50 rounded-xl flex items-center justify-center`}>
                  <r.icon className={`w-4 h-4 text-${r.color}-500`} />
                </div>
                <div className="flex-1">
                  <p className="font-semibold text-gray-900 text-sm">{r.title}</p>
                  <p className="text-xs text-gray-400">{r.desc}</p>
                </div>
                <ArrowRight size={16} className="text-gray-300 group-hover:text-blue-400 transition-colors" />
              </Link>
            ))}
          </div>
        </div>

        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Employees by Department</h3>
          <ResponsiveContainer width="100%" height={200}>
            <PieChart>
              <Pie data={byDept} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={75} innerRadius={40}>
                {byDept.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
              </Pie>
              <Tooltip formatter={(v, n) => [`${v} employees`, n]} />
            </PieChart>
          </ResponsiveContainer>
          <div className="grid grid-cols-2 gap-2 mt-2">
            {byDept.map((d, i) => (
              <div key={d.name} className="flex items-center gap-1.5 text-xs text-gray-600">
                <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: COLORS[i % COLORS.length] }} />
                <span className="truncate">{d.name} ({d.value})</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Payroll by Department</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={bySalary} margin={{ left: -10, right: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="name" tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <Tooltip formatter={(v: any) => [`$${Number(v).toLocaleString()}`, 'Total Salary']} />
            <Bar dataKey="total" fill="#8b5cf6" radius={[6, 6, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Employee Overview</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Employee', 'Department', 'Position', 'Salary', 'Status'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {employees.map(e => (
                <tr key={e.id} className="table-row">
                  <td className="table-cell">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{e.name.charAt(0)}</div>
                      <div>
                        <p className="font-semibold text-gray-900 text-sm">{e.name}</p>
                        <p className="text-xs text-gray-400">{e.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="table-cell"><span className="badge badge-blue">{e.department}</span></td>
                  <td className="table-cell text-gray-600 text-sm">{e.position}</td>
                  <td className="table-cell font-semibold text-gray-900">${e.salary.toLocaleString()}</td>
                  <td className="table-cell"><span className={`badge ${e.status === 'active' ? 'badge-green' : e.status === 'on-leave' ? 'badge-yellow' : 'badge-gray'}`}>{e.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
