'use client';
import { useState, useEffect } from 'react';
import Topbar from '@/components/layout/Topbar';
import { DollarSign, CheckCircle2, Clock, Download, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';

interface Employee { _id: string; name: string; email?: string; department?: string; designation?: string; salary: number; }

export default function PayrollPage() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [month, setMonth] = useState(() => {
    const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  });
  const [paid, setPaid] = useState<string[]>([]);

  useEffect(() => {
    fetch('/api/employees?limit=500')
      .then(r => r.ok ? r.json() : { data: [] })
      .then(j => setEmployees(j.data || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const payrollData = employees.map(e => ({
    ...e,
    gross: Math.round((e.salary || 0) / 12),
    tax: Math.round(((e.salary || 0) / 12) * 0.1),
    insurance: Math.round(((e.salary || 0) / 12) * 0.03),
    net: Math.round(((e.salary || 0) / 12) * 0.87),
    isPaid: paid.includes(e._id),
  }));

  const totalGross = payrollData.reduce((a, p) => a + p.gross, 0);
  const totalNet = payrollData.reduce((a, p) => a + p.net, 0);
  const paidCount = paid.length;

  const markPaid = (id: string) => { if (!paid.includes(id)) { setPaid(prev => [...prev, id]); toast.success('Payment processed!'); } };
  const markAllPaid = () => { setPaid(employees.map(e => e._id)); toast.success('All salaries processed!'); };

  return (
    <div className="page-wrapper">
      <Topbar title="Payroll" subtitle="Process employee salaries"
        actions={
          <div className="flex gap-2">
            <input type="month" value={month} onChange={e => setMonth(e.target.value)} className="form-input text-sm" />
            <button onClick={markAllPaid} className="btn-success"><CheckCircle2 size={15} /> Process All</button>
          </div>
        }
      />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Gross', value: `৳${totalGross.toLocaleString()}`, color: 'blue' },
          { label: 'Total Net Pay', value: `৳${totalNet.toLocaleString()}`, color: 'emerald' },
          { label: 'Processed', value: `${paidCount}/${employees.length}`, color: 'purple' },
          { label: 'Total Tax Withheld', value: `৳${payrollData.reduce((a,p)=>a+p.tax,0).toLocaleString()}`, color: 'amber' },
        ].map(s => (
          <div key={s.label} className="card text-center">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p>
            <p className="text-xs text-gray-400 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-bold text-gray-900 dark:text-white">
            Payroll for {new Date(month + '-01').toLocaleString('default', { month: 'long', year: 'numeric' })}
          </h3>
          <button className="btn-secondary text-xs"><Download size={14} /> Export</button>
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Loader2 className="animate-spin text-gray-400" size={24} /></div>
        ) : (
          <div className="table-wrapper">
            <table className="w-full">
              <thead><tr>{['Employee', 'Department', 'Gross Pay', 'Tax (10%)', 'Insurance (3%)', 'Net Pay', 'Status', 'Action'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-50">
                {payrollData.map(p => (
                  <tr key={p._id} className={`table-row ${p.isPaid ? 'bg-emerald-50/30' : ''}`}>
                    <td className="table-cell">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{p.name.charAt(0)}</div>
                        <div><p className="font-semibold text-sm dark:text-white">{p.name}</p><p className="text-xs text-gray-400">{p.email}</p></div>
                      </div>
                    </td>
                    <td className="table-cell"><span className="badge badge-blue">{p.department}</span></td>
                    <td className="table-cell font-semibold">৳{p.gross.toLocaleString()}</td>
                    <td className="table-cell text-red-500">-৳{p.tax.toLocaleString()}</td>
                    <td className="table-cell text-red-500">-৳{p.insurance.toLocaleString()}</td>
                    <td className="table-cell font-bold text-emerald-600">৳{p.net.toLocaleString()}</td>
                    <td className="table-cell">
                      {p.isPaid
                        ? <span className="badge badge-green flex items-center gap-1 w-fit"><CheckCircle2 size={11} />Paid</span>
                        : <span className="badge badge-yellow flex items-center gap-1 w-fit"><Clock size={11} />Pending</span>
                      }
                    </td>
                    <td className="table-cell">
                      {!p.isPaid
                        ? <button onClick={() => markPaid(p._id)} className="btn-primary text-xs py-1.5 px-3"><DollarSign size={12} />Pay</button>
                        : <span className="text-xs text-gray-400">Processed</span>
                      }
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {payrollData.length === 0 && <div className="text-center py-8 text-gray-400 text-sm">No employees found</div>}
          </div>
        )}
      </div>
    </div>
  );
}
