'use client';
import { useEffect, useState, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import { Target, TrendingUp, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, CartesianGrid } from 'recharts';

interface TargetDoc { _id: string; module: string; title: string; status: 'on-track' | 'at-risk' | 'completed' | 'overdue'; progress: number; }

const STATUS_COLORS: Record<string, string> = {
  'on-track': '#10b981',
  'at-risk': '#f59e0b',
  'completed': '#3b82f6',
  'overdue': '#ef4444',
};

const CustomTooltip = ({ active, payload, label }: { active?: boolean; payload?: { name: string; value: number; color: string }[]; label?: string }) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-gray-900 text-white px-3 py-2 rounded-xl shadow-xl text-xs">
        <p className="font-semibold mb-1">{label}</p>
        {payload.map((p) => <p key={p.name} style={{ color: p.color }}>{p.name}: {p.value}</p>)}
      </div>
    );
  }
  return null;
};

export default function TargetReportPage() {
  const [targets, setTargets] = useState<TargetDoc[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/targets');
      const json = await res.json();
      setTargets(json.data || []);
    } catch { } finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const total = targets.length;
  const completed = targets.filter(t => t.status === 'completed').length;
  const overdue = targets.filter(t => t.status === 'overdue').length;
  const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0;

  const statusDist = [
    { name: 'On Track', value: targets.filter(t => t.status === 'on-track').length, color: STATUS_COLORS['on-track'] },
    { name: 'At Risk', value: targets.filter(t => t.status === 'at-risk').length, color: STATUS_COLORS['at-risk'] },
    { name: 'Completed', value: completed, color: STATUS_COLORS['completed'] },
    { name: 'Overdue', value: overdue, color: STATUS_COLORS['overdue'] },
  ].filter(s => s.value > 0);

  const moduleMap: Record<string, { targets: number; completed: number; totalProgress: number }> = {};
  targets.forEach(t => {
    if (!moduleMap[t.module]) moduleMap[t.module] = { targets: 0, completed: 0, totalProgress: 0 };
    moduleMap[t.module].targets++;
    moduleMap[t.module].totalProgress += t.progress || 0;
    if (t.status === 'completed') moduleMap[t.module].completed++;
  });

  const moduleData = Object.entries(moduleMap).map(([name, v]) => ({
    name,
    targets: v.targets,
    completed: v.completed,
    progress: Math.round(v.totalProgress / v.targets),
  }));

  return (
    <div className="page-wrapper">
      <Topbar title="Target Reports" subtitle="Performance overview across all business targets" />

      {loading ? (
        <div className="flex justify-center py-20"><Loader2 className="animate-spin text-gray-400" size={32} /></div>
      ) : (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              { label: 'Total Targets', value: total, icon: Target, color: 'text-blue-600', bg: 'bg-blue-50' },
              { label: 'Completed', value: completed, icon: CheckCircle2, color: 'text-emerald-600', bg: 'bg-emerald-50' },
              { label: 'Completion Rate', value: `${completionRate}%`, icon: TrendingUp, color: 'text-violet-600', bg: 'bg-violet-50' },
              { label: 'Overdue', value: overdue, icon: AlertCircle, color: 'text-red-600', bg: 'bg-red-50' },
            ].map(s => (
              <div key={s.label} className="stat-card flex items-center gap-4">
                <div className={`icon-box ${s.bg}`}><s.icon size={20} className={s.color} /></div>
                <div>
                  <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">{s.value}</p>
                  <p className="text-xs text-gray-500 font-medium">{s.label}</p>
                </div>
              </div>
            ))}
          </div>

          {total === 0 ? (
            <div className="card text-center py-16 text-gray-400">
              <Target className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p>No targets found. Add targets in the Targets module.</p>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                <div className="card lg:col-span-2">
                  <h3 className="font-bold text-gray-900 mb-4">Performance by Module</h3>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={moduleData} barGap={4}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.05)" />
                      <XAxis dataKey="name" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                      <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                      <Tooltip content={<CustomTooltip />} />
                      <Bar dataKey="targets" name="Total" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                      <Bar dataKey="completed" name="Completed" fill="#10b981" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>

                <div className="card">
                  <h3 className="font-bold text-gray-900 mb-4">Status Distribution</h3>
                  <ResponsiveContainer width="100%" height={160}>
                    <PieChart>
                      <Pie data={statusDist} cx="50%" cy="50%" innerRadius={45} outerRadius={70} paddingAngle={3} dataKey="value">
                        {statusDist.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                      </Pie>
                      <Tooltip formatter={(val, name) => [val, name]} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="space-y-2 mt-2">
                    {statusDist.map(s => (
                      <div key={s.name} className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: s.color }} />
                          <span className="text-xs text-gray-600 font-medium">{s.name}</span>
                        </div>
                        <span className="text-xs font-bold text-gray-700">{s.value}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              <div className="card">
                <h3 className="font-bold text-gray-900 mb-4">Module Breakdown</h3>
                <div className="table-wrapper">
                  <table className="w-full">
                    <thead><tr>
                      {['Module', 'Total Targets', 'Completed', 'Avg Progress', 'Status'].map(h => <th key={h} className="table-header">{h}</th>)}
                    </tr></thead>
                    <tbody>
                      {moduleData.map(row => (
                        <tr key={row.name} className="table-row">
                          <td className="table-cell font-bold">{row.name}</td>
                          <td className="table-cell">{row.targets}</td>
                          <td className="table-cell">{row.completed}</td>
                          <td className="table-cell w-48">
                            <div className="flex items-center gap-3">
                              <div className="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
                                <div className="h-full bg-blue-500 rounded-full" style={{ width: `${row.progress}%` }} />
                              </div>
                              <span className="text-xs font-bold text-gray-700 w-10 text-right">{row.progress}%</span>
                            </div>
                          </td>
                          <td className="table-cell">
                            <span className={`badge ${row.progress === 100 ? 'badge-green' : row.progress >= 70 ? 'badge-blue' : 'badge-yellow'}`}>
                              {row.progress === 100 ? 'Excellent' : row.progress >= 70 ? 'Good' : 'Needs Attention'}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
