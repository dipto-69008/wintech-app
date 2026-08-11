'use client';
import { useState } from 'react';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import { CalendarDays, CheckCircle2, Clock, XCircle } from 'lucide-react';

interface LeaveRecord {
  id: string;
  employeeId: string;
  employeeName: string;
  department: string;
  type: 'annual' | 'sick' | 'casual' | 'maternity';
  startDate: string;
  endDate: string;
  days: number;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
}

const sampleLeaves: LeaveRecord[] = [
  { id: 'LV001', employeeId: 'E001', employeeName: 'Sarah Ahmed', department: 'Engineering', type: 'annual', startDate: '2025-06-01', endDate: '2025-06-05', days: 5, reason: 'Family vacation', status: 'approved' },
  { id: 'LV002', employeeId: 'E002', employeeName: 'Rahim Khan', department: 'Sales', type: 'sick', startDate: '2025-05-28', endDate: '2025-05-29', days: 2, reason: 'Fever', status: 'approved' },
  { id: 'LV003', employeeId: 'E003', employeeName: 'Nadia Islam', department: 'HR', type: 'casual', startDate: '2025-06-10', endDate: '2025-06-10', days: 1, reason: 'Personal work', status: 'pending' },
  { id: 'LV004', employeeId: 'E004', employeeName: 'Karim Hassan', department: 'Accounting', type: 'sick', startDate: '2025-05-20', endDate: '2025-05-25', days: 6, reason: 'Surgery recovery', status: 'approved' },
];

export default function LeaveReportPage() {
  const { employees } = useERPStore();
  const [leaves, setLeaves] = useState<LeaveRecord[]>(sampleLeaves);

  const approved = leaves.filter(l => l.status === 'approved').reduce((a, l) => a + l.days, 0);
  const pending = leaves.filter(l => l.status === 'pending').length;

  const updateStatus = (id: string, status: LeaveRecord['status']) => {
    setLeaves(prev => prev.map(l => l.id === id ? { ...l, status } : l));
  };

  const typeColor = (t: string) => t === 'annual' ? 'badge-blue' : t === 'sick' ? 'badge-red' : t === 'maternity' ? 'badge-purple' : 'badge-yellow';
  const statusColor = (s: string) => s === 'approved' ? 'badge-green' : s === 'rejected' ? 'badge-red' : 'badge-yellow';

  return (
    <div className="page-wrapper">
      <Topbar title="Leave Report" subtitle="Employee leave requests and balances" />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Requests', value: leaves.length, color: 'blue' },
          { label: 'Days Approved', value: approved, color: 'emerald' },
          { label: 'Pending Approval', value: pending, color: 'amber' },
          { label: 'On Leave Now', value: employees.filter(e=>e.status==='on-leave').length, color: 'purple' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Leave Requests</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Employee', 'Type', 'Start Date', 'End Date', 'Days', 'Reason', 'Status', 'Action'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {leaves.map(l => (
                <tr key={l.id} className="table-row">
                  <td className="table-cell">
                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{l.employeeName.charAt(0)}</div>
                      <div>
                        <p className="font-semibold text-gray-900 text-sm">{l.employeeName}</p>
                        <p className="text-xs text-gray-400">{l.department}</p>
                      </div>
                    </div>
                  </td>
                  <td className="table-cell"><span className={`badge ${typeColor(l.type)} capitalize`}>{l.type}</span></td>
                  <td className="table-cell text-gray-500 text-xs">{l.startDate}</td>
                  <td className="table-cell text-gray-500 text-xs">{l.endDate}</td>
                  <td className="table-cell text-center font-bold text-gray-900">{l.days}</td>
                  <td className="table-cell text-gray-600 text-xs max-w-[120px] truncate">{l.reason}</td>
                  <td className="table-cell"><span className={`badge ${statusColor(l.status)}`}>{l.status}</span></td>
                  <td className="table-cell">
                    {l.status === 'pending' && (
                      <div className="flex gap-1">
                        <button onClick={() => updateStatus(l.id, 'approved')} className="p-1.5 text-emerald-500 hover:bg-emerald-50 rounded-lg" title="Approve"><CheckCircle2 size={14} /></button>
                        <button onClick={() => updateStatus(l.id, 'rejected')} className="p-1.5 text-red-400 hover:bg-red-50 rounded-lg" title="Reject"><XCircle size={14} /></button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
