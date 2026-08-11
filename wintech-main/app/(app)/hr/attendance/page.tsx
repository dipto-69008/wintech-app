'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { formatDate } from '@/lib/utils';
import { Clock, CheckCircle2, XCircle, AlertCircle, Calendar, Loader2, Save } from 'lucide-react';
import toast from 'react-hot-toast';

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
type AttStatus = 'present' | 'absent' | 'late' | 'leave' | 'half';

const STATUS_CONFIG: Record<AttStatus, { color: string; icon: React.ElementType; label: string; cell: string }> = {
  present: { color: 'badge-green', icon: CheckCircle2, label: 'Present', cell: 'bg-emerald-50 text-emerald-600' },
  absent:  { color: 'badge-red', icon: XCircle, label: 'Absent', cell: 'bg-red-50 text-red-600' },
  late:    { color: 'badge-yellow', icon: Clock, label: 'Late', cell: 'bg-amber-50 text-amber-600' },
  leave:   { color: 'badge-purple', icon: Calendar, label: 'Leave', cell: 'bg-purple-50 text-purple-400' },
  half:    { color: 'badge-blue', icon: AlertCircle, label: 'Half Day', cell: 'bg-blue-50 text-blue-600' },
};

function getWeekLabel(offset = 0) {
  const now = new Date();
  const day = now.getDay();
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((day + 6) % 7) + offset * 7);
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  const fmt = (d: Date) => formatDate(d);
  return `${fmt(monday)} – ${fmt(sunday)}`;
}

export default function AttendancePage() {
  const [weekOffset, setWeekOffset] = useState(0);
  const [employees, setEmployees] = useState<string[]>([]);
  const [data, setData] = useState<Record<string, Record<string, AttStatus>>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const weekLabel = getWeekLabel(weekOffset);

  const fetchData = useCallback(async (label: string) => {
    setLoading(true);
    try {
      const [er, ar] = await Promise.all([
        fetch('/api/employees'),
        fetch(`/api/attendance?weekLabel=${encodeURIComponent(label)}`),
      ]);
      const [ej, aj] = await Promise.all([er.json(), ar.json()]);
      const empNames: string[] = (ej.data || []).map((e: { name: string }) => e.name);
      setEmployees(empNames);

      const initData: Record<string, Record<string, AttStatus>> = {};
      empNames.forEach(name => {
        initData[name] = {};
        DAYS.forEach(d => { initData[name][d] = 'leave'; });
      });

      const records = (aj.data || [])[0]?.records || [];
      records.forEach((r: { employee: string; day: string; status: AttStatus }) => {
        if (initData[r.employee]) initData[r.employee][r.day] = r.status;
      });

      setData(initData);
    } catch { toast.error('Failed to load attendance'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(weekLabel); }, [fetchData, weekLabel]);

  const saveAttendance = async () => {
    setSaving(true);
    try {
      const records: { employee: string; day: string; status: string }[] = [];
      employees.forEach(emp => {
        DAYS.forEach(day => {
          records.push({ employee: emp, day, status: data[emp]?.[day] || 'leave' });
        });
      });
      const res = await fetch('/api/attendance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weekLabel, records }),
      });
      if (!res.ok) throw new Error();
      toast.success('Attendance saved');
    } catch { toast.error('Failed to save attendance'); }
    finally { setSaving(false); }
  };

  const summary = employees.map(emp => {
    const days = Object.values(data[emp] || {});
    return { name: emp, present: days.filter(d => d === 'present').length, absent: days.filter(d => d === 'absent').length, late: days.filter(d => d === 'late').length, leave: days.filter(d => d === 'leave').length };
  });

  const totalPresent = summary.reduce((a, s) => a + s.present, 0);
  const totalAbsent = summary.reduce((a, s) => a + s.absent, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Attendance" subtitle="Weekly attendance tracker"
        actions={
          <div className="flex items-center gap-2">
            <button onClick={() => setWeekOffset(o => o - 1)} className="btn-ghost text-xs">← Prev</button>
            <span className="text-sm font-medium text-gray-700 px-3 py-2 bg-gray-50 rounded-xl border border-gray-200">{weekLabel}</span>
            <button onClick={() => setWeekOffset(o => o + 1)} className="btn-ghost text-xs">Next →</button>
            <button onClick={saveAttendance} disabled={saving || loading} className="btn-primary flex items-center gap-1.5">
              {saving ? <Loader2 size={13} className="animate-spin" /> : <Save size={13} />} Save
            </button>
          </div>
        }
      />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Present', value: totalPresent, color: 'emerald' },
          { label: 'Total Absent', value: totalAbsent, color: 'red' },
          { label: 'Late Arrivals', value: summary.reduce((a,s)=>a+s.late,0), color: 'amber' },
          { label: 'On Full Leave', value: summary.filter(s=>s.leave>=7).length, color: 'purple' },
        ].map(s => (
          <div key={s.label} className="card text-center">
            <p className={`text-3xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-xs text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card overflow-x-auto">
        <h3 className="font-bold text-gray-900 mb-4">Weekly Attendance Sheet</h3>
        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : employees.length === 0 ? (
          <p className="text-center text-gray-400 py-10">No employees found. Add employees in HR module first.</p>
        ) : (
          <table className="w-full">
            <thead>
              <tr>
                <th className="table-header w-40">Employee</th>
                {DAYS.map(d => <th key={d} className="table-header text-center">{d}</th>)}
                <th className="table-header text-center">Summary</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {employees.map(emp => (
                <tr key={emp} className="table-row">
                  <td className="table-cell">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{emp.charAt(0)}</div>
                      <span className="font-medium text-sm">{emp}</span>
                    </div>
                  </td>
                  {DAYS.map(day => {
                    const st = (data[emp]?.[day] || 'leave') as AttStatus;
                    const cfg = STATUS_CONFIG[st];
                    return (
                      <td key={day} className="table-cell text-center">
                        <select value={st} onChange={e => setData(prev => ({ ...prev, [emp]: { ...prev[emp], [day]: e.target.value as AttStatus } }))}
                          className={`text-xs px-2 py-1.5 rounded-lg font-medium border-0 cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500/30 ${cfg.cell}`}>
                          {Object.entries(STATUS_CONFIG).map(([val, c]) => <option key={val} value={val}>{c.label}</option>)}
                        </select>
                      </td>
                    );
                  })}
                  <td className="table-cell">
                    <div className="flex gap-1 flex-wrap justify-center">
                      {(() => { const s = summary.find(x => x.name === emp)!; return (
                        <>
                          <span className="text-[10px] bg-emerald-50 text-emerald-600 px-1.5 py-0.5 rounded font-bold">P:{s.present}</span>
                          <span className="text-[10px] bg-red-50 text-red-500 px-1.5 py-0.5 rounded font-bold">A:{s.absent}</span>
                          {s.late > 0 && <span className="text-[10px] bg-amber-50 text-amber-600 px-1.5 py-0.5 rounded font-bold">L:{s.late}</span>}
                        </>
                      );})()}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Attendance Legend</h3>
        <div className="flex flex-wrap gap-3">
          {Object.entries(STATUS_CONFIG).map(([key, cfg]) => (
            <div key={key} className="flex items-center gap-2">
              <span className={`badge ${cfg.color}`}>{cfg.label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
