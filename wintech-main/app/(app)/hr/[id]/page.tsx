'use client';
import { useParams } from 'next/navigation';
import { useERPStore } from '@/lib/store';
import Topbar from '@/components/layout/Topbar';
import Link from 'next/link';
import { ArrowLeft, Mail, Phone, Building2, Calendar, DollarSign, Award, Clock, Edit2 } from 'lucide-react';

export default function EmployeeDetailPage() {
  const { id } = useParams();
  const { employees } = useERPStore();
  const employee = employees.find(e => e.id === id);

  if (!employee) return (
    <div className="page-wrapper">
      <div className="card text-center py-16 text-gray-400">
        <p className="text-lg font-semibold">Employee not found</p>
        <Link href="/hr" className="text-blue-500 text-sm mt-2 inline-block">← Back to Employees</Link>
      </div>
    </div>
  );

  const statusColor = employee.status === 'active' ? 'badge-green' : employee.status === 'on-leave' ? 'badge-yellow' : 'badge-gray';

  const infoCards = [
    { label: 'Email', value: employee.email, icon: Mail },
    { label: 'Phone', value: employee.phone, icon: Phone },
    { label: 'Department', value: employee.department, icon: Building2 },
    { label: 'Position', value: employee.position, icon: Award },
    { label: 'Join Date', value: employee.joinDate, icon: Calendar },
    { label: 'Annual Salary', value: `$${employee.salary.toLocaleString()}`, icon: DollarSign },
  ];

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  const salaryHistory = months.map(m => ({ month: m, amount: employee.salary / 12 }));

  return (
    <div className="page-wrapper">
      <Topbar title="Employee Profile" subtitle={`${employee.department} — ${employee.position}`}
        actions={
          <div className="flex gap-2">
            <Link href="/hr" className="btn-secondary flex items-center gap-2"><ArrowLeft size={15} />Back</Link>
          </div>
        }
      />

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        {/* Profile Card */}
        <div className="card text-center">
          <div className="flex flex-col items-center mb-5">
            <div className="w-24 h-24 bg-gradient-to-br from-blue-400 to-purple-600 rounded-full flex items-center justify-center text-white text-4xl font-bold mb-3 shadow-lg shadow-blue-200">
              {employee.name.charAt(0)}
            </div>
            <h2 className="font-bold text-xl text-gray-900">{employee.name}</h2>
            <p className="text-gray-500 text-sm mt-1">{employee.position}</p>
            <span className={`badge mt-2 ${statusColor}`}>{employee.status.replace('-', ' ')}</span>
            <p className="text-xs text-gray-400 font-mono mt-2">{employee.id}</p>
          </div>

          <div className="grid grid-cols-2 gap-3 mt-4">
            <div className="bg-blue-50 rounded-xl p-3 text-center">
              <p className="text-lg font-bold text-blue-600">${(employee.salary / 12000).toFixed(1)}K</p>
              <p className="text-xs text-gray-500">Monthly</p>
            </div>
            <div className="bg-purple-50 rounded-xl p-3 text-center">
              <p className="text-lg font-bold text-purple-600">
                {Math.floor((new Date().getTime() - new Date(employee.joinDate).getTime()) / (1000 * 60 * 60 * 24 * 365))}y
              </p>
              <p className="text-xs text-gray-500">Tenure</p>
            </div>
          </div>
        </div>

        {/* Info */}
        <div className="xl:col-span-2 space-y-4">
          <div className="card">
            <h3 className="font-bold text-gray-900 mb-4">Employee Information</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {infoCards.map(item => (
                <div key={item.label} className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
                  <div className="w-9 h-9 bg-white rounded-lg flex items-center justify-center shadow-sm flex-shrink-0">
                    <item.icon size={16} className="text-blue-500" />
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 font-medium">{item.label}</p>
                    <p className="text-sm font-semibold text-gray-900">{item.value}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="card">
            <h3 className="font-bold text-gray-900 mb-4">Monthly Salary (2025)</h3>
            <div className="grid grid-cols-3 sm:grid-cols-6 gap-2">
              {salaryHistory.map(s => (
                <div key={s.month} className="text-center p-3 bg-gradient-to-b from-blue-50 to-white rounded-xl border border-blue-100">
                  <p className="text-xs font-bold text-gray-900">${(s.amount / 1000).toFixed(1)}K</p>
                  <p className="text-[10px] text-gray-400 mt-1">{s.month}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="card">
            <h3 className="font-bold text-gray-900 mb-4">Quick Stats</h3>
            <div className="grid grid-cols-3 gap-3">
              {[
                { label: 'Leave Balance', value: '12 days', icon: Calendar, color: 'emerald' },
                { label: 'This Month Attendance', value: '19/20', icon: Clock, color: 'blue' },
                { label: 'Performance', value: 'Excellent', icon: Award, color: 'amber' },
              ].map(s => (
                <div key={s.label} className={`bg-${s.color}-50 rounded-xl p-4 text-center`}>
                  <s.icon className={`w-5 h-5 text-${s.color}-500 mx-auto mb-2`} />
                  <p className={`font-bold text-${s.color}-700 text-sm`}>{s.value}</p>
                  <p className="text-xs text-gray-500 mt-0.5">{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
