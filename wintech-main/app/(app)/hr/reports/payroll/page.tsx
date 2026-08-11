'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import { DollarSign, TrendingUp, Users, Banknote } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function PayrollReportPage() {
  const { employees } = useERPStore();

  const activeEmployees = employees.filter(e => e.status === 'active');
  const totalAnnualPayroll = activeEmployees.reduce((a, e) => a + e.salary, 0);
  const monthlyPayroll = totalAnnualPayroll / 12;
  const avgSalary = activeEmployees.length > 0 ? totalAnnualPayroll / activeEmployees.length : 0;

  const byDept = Object.entries(
    employees.reduce((acc, e) => {
      if (!acc[e.department]) acc[e.department] = { count: 0, totalSalary: 0 };
      acc[e.department].count += 1;
      acc[e.department].totalSalary += e.salary;
      return acc;
    }, {} as Record<string, { count: number; totalSalary: number }>)
  ).map(([name, data]) => ({ name: name.length > 12 ? name.slice(0, 12) + '…' : name, ...data, avg: Math.round(data.totalSalary / data.count) }));

  return (
    <div className="page-wrapper">
      <Topbar title="Payroll Report" subtitle="Salary and compensation summary" />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Monthly Payroll', value: `$${(monthlyPayroll/1000).toFixed(1)}K`, color: 'blue', icon: DollarSign },
          { label: 'Annual Payroll', value: `$${(totalAnnualPayroll/1000).toFixed(0)}K`, color: 'purple', icon: TrendingUp },
          { label: 'Employees Paid', value: activeEmployees.length, color: 'emerald', icon: Users },
          { label: 'Average Salary', value: `$${(avgSalary/1000).toFixed(1)}K`, color: 'amber', icon: Banknote },
        ].map(s => (
          <div key={s.label} className="card flex items-center gap-4">
            <div className={`w-12 h-12 bg-${s.color}-50 rounded-2xl flex items-center justify-center`}>
              <s.icon className={`w-5 h-5 text-${s.color}-500`} />
            </div>
            <div><p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p><p className="text-xs text-gray-400">{s.label}</p></div>
          </div>
        ))}
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Payroll by Department</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={byDept} margin={{ left: -10, right: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="name" tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <Tooltip formatter={(v: any) => [`$${Number(v).toLocaleString()}`, 'Total Salary']} />
            <Bar dataKey="totalSalary" fill="#3b82f6" radius={[6, 6, 0, 0]} name="Total Salary" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Department Payroll Summary</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Department', 'Employees', 'Total Salary/Year', 'Monthly Cost', 'Avg Salary', '% of Total'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {byDept.map((d, i) => (
                <tr key={d.name} className="table-row">
                  <td className="table-cell font-semibold text-gray-900">{d.name}</td>
                  <td className="table-cell text-center font-semibold text-gray-700">{d.count}</td>
                  <td className="table-cell font-bold text-gray-900">${d.totalSalary.toLocaleString()}</td>
                  <td className="table-cell text-gray-600">${Math.round(d.totalSalary / 12).toLocaleString()}</td>
                  <td className="table-cell text-gray-600">${d.avg.toLocaleString()}</td>
                  <td className="table-cell">
                    <div className="flex items-center gap-2">
                      <div className="flex-1 bg-gray-100 rounded-full h-1.5 w-16">
                        <div className="h-1.5 rounded-full bg-blue-400" style={{ width: `${(d.totalSalary / totalAnnualPayroll) * 100}%` }} />
                      </div>
                      <span className="text-xs text-gray-600">{((d.totalSalary / totalAnnualPayroll) * 100).toFixed(0)}%</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Individual Payroll</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Employee', 'Department', 'Position', 'Annual Salary', 'Monthly', 'Status'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {employees.sort((a, b) => b.salary - a.salary).map(e => (
                <tr key={e.id} className="table-row">
                  <td className="table-cell">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{e.name.charAt(0)}</div>
                      <p className="font-semibold text-gray-900 text-sm">{e.name}</p>
                    </div>
                  </td>
                  <td className="table-cell"><span className="badge badge-blue">{e.department}</span></td>
                  <td className="table-cell text-gray-600 text-sm">{e.position}</td>
                  <td className="table-cell font-bold text-gray-900">${e.salary.toLocaleString()}</td>
                  <td className="table-cell text-gray-600">${Math.round(e.salary / 12).toLocaleString()}</td>
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
