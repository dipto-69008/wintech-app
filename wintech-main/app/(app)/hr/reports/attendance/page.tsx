'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import { Clock, CheckCircle2, XCircle, AlertTriangle } from 'lucide-react';

const attendanceData = [
  { date: '2025-05-26', day: 'Monday', present: 4, absent: 1, late: 0 },
  { date: '2025-05-27', day: 'Tuesday', present: 5, absent: 0, late: 0 },
  { date: '2025-05-28', day: 'Wednesday', present: 3, absent: 1, late: 1 },
  { date: '2025-05-29', day: 'Thursday', present: 5, absent: 0, late: 0 },
  { date: '2025-05-30', day: 'Friday', present: 4, absent: 0, late: 1 },
];

export default function AttendanceReportPage() {
  const { employees } = useERPStore();
  const activeEmp = employees.filter(e => e.status === 'active');

  const empAttendance = activeEmp.map(e => {
    const present = Math.floor(Math.random() * 3) + 17;
    const total = 20;
    const rate = ((present / total) * 100).toFixed(0);
    return { ...e, present, absent: total - present, late: Math.floor(Math.random() * 3), rate: Number(rate) };
  });

  return (
    <div className="page-wrapper">
      <Topbar title="Attendance Report" subtitle="Employee attendance summary for this month" />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Working Days', value: 20, color: 'blue' },
          { label: 'Avg Attendance', value: `${(empAttendance.reduce((a,e)=>a+e.rate,0)/Math.max(empAttendance.length,1)).toFixed(0)}%`, color: 'emerald' },
          { label: 'Perfect Attendance', value: empAttendance.filter(e=>e.absent===0).length, color: 'purple' },
          { label: 'Frequent Absents', value: empAttendance.filter(e=>e.absent>=3).length, color: 'amber' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Weekly Overview</h3>
        <div className="grid grid-cols-5 gap-3">
          {attendanceData.map(d => (
            <div key={d.date} className="border border-gray-100 rounded-xl p-3 text-center">
              <p className="text-xs font-semibold text-gray-500 mb-2">{d.day.slice(0,3)}</p>
              <p className="text-[10px] text-gray-400 mb-3">{d.date.slice(5)}</p>
              <div className="space-y-1.5">
                <div className="flex items-center justify-between text-xs">
                  <span className="flex items-center gap-1 text-emerald-600"><CheckCircle2 size={10} />Present</span>
                  <span className="font-bold">{d.present}</span>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="flex items-center gap-1 text-red-500"><XCircle size={10} />Absent</span>
                  <span className="font-bold">{d.absent}</span>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="flex items-center gap-1 text-amber-500"><Clock size={10} />Late</span>
                  <span className="font-bold">{d.late}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Employee Attendance — May 2025</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Employee', 'Department', 'Present Days', 'Absent Days', 'Late Days', 'Attendance %'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {empAttendance.map(e => (
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
                  <td className="table-cell text-center"><span className="font-bold text-emerald-600">{e.present}</span></td>
                  <td className="table-cell text-center">
                    <span className={`font-bold ${e.absent > 2 ? 'text-red-600' : e.absent > 0 ? 'text-amber-600' : 'text-emerald-600'}`}>{e.absent}</span>
                  </td>
                  <td className="table-cell text-center"><span className={`font-bold ${e.late > 0 ? 'text-amber-500' : 'text-gray-400'}`}>{e.late}</span></td>
                  <td className="table-cell">
                    <div className="flex items-center gap-2">
                      <div className="flex-1 bg-gray-100 rounded-full h-2">
                        <div className={`h-2 rounded-full ${e.rate >= 90 ? 'bg-emerald-400' : e.rate >= 75 ? 'bg-amber-400' : 'bg-red-400'}`} style={{ width: `${e.rate}%` }} />
                      </div>
                      <span className={`text-xs font-bold w-10 ${e.rate >= 90 ? 'text-emerald-600' : e.rate >= 75 ? 'text-amber-600' : 'text-red-600'}`}>{e.rate}%</span>
                    </div>
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
