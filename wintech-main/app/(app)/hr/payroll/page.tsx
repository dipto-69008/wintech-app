'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import toast from 'react-hot-toast';
import { Users, DollarSign, CheckCircle, Clock, RefreshCw, Edit2, X, Save, Banknote } from 'lucide-react';

interface PayrollRecord {
  _id: string;
  employeeId?: string;
  employeeName: string;
  designation?: string;
  department?: string;
  month: number;
  year: number;
  basicSalary: number;
  houseRent: number;
  medicalAllowance: number;
  transportAllowance: number;
  otherAllowance: number;
  grossSalary: number;
  providentFund: number;
  tax: number;
  otherDeductions: number;
  totalDeductions: number;
  netSalary: number;
  paidAmount: number;
  dueAmount: number;
  paymentDate?: string;
  paymentMethod: string;
  status: string;
  note?: string;
}

const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];

export default function PayrollPage() {
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [records, setRecords] = useState<PayrollRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState<Partial<PayrollRecord>>({});

  const fetchPayroll = useCallback(async () => {
    setLoading(true);
    try {
      const r = await fetch(`/api/payroll?month=${month}&year=${year}`);
      if (r.ok) { const d = await r.json(); setRecords(d.data || []); }
    } finally { setLoading(false); }
  }, [month, year]);

  useEffect(() => { fetchPayroll(); }, [fetchPayroll]);

  const totalNet = records.reduce((a, r) => a + r.netSalary, 0);
  const totalPaid = records.reduce((a, r) => a + r.paidAmount, 0);
  const totalDue = records.reduce((a, r) => a + r.dueAmount, 0);
  const paidCount = records.filter(r => r.status === 'paid').length;

  const handleGenerate = async () => {
    setGenerating(true);
    try {
      const res = await fetch('/api/payroll', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ generateForMonth: true, month, year }) });
      if (!res.ok) throw new Error((await res.json()).error || 'Failed');
      const d = await res.json();
      toast.success(`Generated ${d.generated} payroll records`);
      fetchPayroll();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Generation failed');
    } finally { setGenerating(false); }
  };

  const startEdit = (r: PayrollRecord) => {
    setEditId(r._id);
    setEditForm({ paidAmount: r.paidAmount, paymentDate: r.paymentDate || new Date().toISOString().split('T')[0], paymentMethod: r.paymentMethod, note: r.note || '', status: r.status });
  };

  const handleSaveEdit = async (r: PayrollRecord) => {
    const paidAmount = Number(editForm.paidAmount) || 0;
    const status = paidAmount >= r.netSalary ? 'paid' : paidAmount > 0 ? 'partial' : 'pending';
    const dueAmount = r.netSalary - paidAmount;
    try {
      const res = await fetch(`/api/payroll/${r._id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...editForm, paidAmount, dueAmount, status }) });
      if (!res.ok) throw new Error('Failed');
      toast.success('Payroll updated');
      setEditId(null);
      fetchPayroll();
    } catch { toast.error('Update failed'); }
  };

  const markAllPaid = async () => {
    if (!confirm(`Mark all ${records.filter(r => r.status !== 'paid').length} unpaid as PAID?`)) return;
    const unpaid = records.filter(r => r.status !== 'paid');
    await Promise.all(unpaid.map(r => fetch(`/api/payroll/${r._id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ paidAmount: r.netSalary, dueAmount: 0, status: 'paid', paymentDate: new Date().toISOString().split('T')[0] }) })));
    toast.success('All payrolls marked as paid');
    fetchPayroll();
  };

  const STATUS_STYLE: Record<string, string> = {
    paid: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400',
    partial: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
    pending: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  };

  return (
    <div className="page-wrapper">
      <Topbar title="Payroll" subtitle={`${MONTHS[month - 1]} ${year} salary management`}
        actions={
          <div className="flex gap-2">
            {records.some(r => r.status !== 'paid') && records.length > 0 && (
              <button className="btn-secondary text-xs" onClick={markAllPaid}><CheckCircle size={13} /> Mark All Paid</button>
            )}
            <button className="btn-primary" onClick={handleGenerate} disabled={generating}>
              {generating ? <><span className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" /></> : <><RefreshCw size={14} /> Generate</>}
            </button>
          </div>
        }
      />

      {/* Month/Year picker */}
      <div className="flex gap-3 mb-4 items-center">
        <select className="input max-w-[160px]" value={month} onChange={e => setMonth(parseInt(e.target.value))}>
          {MONTHS.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
        </select>
        <select className="input max-w-[120px]" value={year} onChange={e => setYear(parseInt(e.target.value))}>
          {[2022,2023,2024,2025,2026].map(y => <option key={y} value={y}>{y}</option>)}
        </select>
        <span className="text-sm text-gray-500 dark:text-gray-400">{records.length} employees</span>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
        {[
          { label: 'Total Net Salary', value: `৳${totalNet.toLocaleString()}`, icon: Banknote, color: 'blue' },
          { label: 'Total Paid', value: `৳${totalPaid.toLocaleString()}`, icon: CheckCircle, color: 'emerald' },
          { label: 'Total Due', value: `৳${totalDue.toLocaleString()}`, icon: Clock, color: 'red' },
          { label: 'Paid / Total', value: `${paidCount} / ${records.length}`, icon: Users, color: 'violet' },
        ].map(s => (
          <div key={s.label} className="card py-3">
            <div className="flex items-center gap-2">
              <div className={`w-8 h-8 rounded-lg bg-${s.color}-100 dark:bg-${s.color}-900/30 flex items-center justify-center`}>
                <s.icon size={15} className={`text-${s.color}-600 dark:text-${s.color}-400`} />
              </div>
              <div>
                <p className="text-[11px] text-gray-500 dark:text-gray-400">{s.label}</p>
                <p className={`text-lg font-bold text-${s.color}-600 dark:text-${s.color}-400`}>{s.value}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="card">
        {loading ? (
          <div className="text-center py-12 text-gray-400">Loading...</div>
        ) : records.length === 0 ? (
          <div className="text-center py-16">
            <DollarSign size={36} className="mx-auto mb-3 text-gray-300" />
            <p className="text-gray-500 font-medium">No payroll for {MONTHS[month - 1]} {year}</p>
            <p className="text-gray-400 text-sm mt-1">Click Generate to create payroll from employees</p>
            <button className="btn-primary mt-4" onClick={handleGenerate} disabled={generating}>
              {generating ? 'Generating...' : <><RefreshCw size={14} /> Generate Payroll</>}
            </button>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-gray-500 text-xs">
                  <th className="text-left py-3 pr-3">Employee</th>
                  <th className="text-left py-3 pr-3">Dept</th>
                  <th className="text-right py-3 pr-3">Basic</th>
                  <th className="text-right py-3 pr-3">Gross</th>
                  <th className="text-right py-3 pr-3">Deductions</th>
                  <th className="text-right py-3 pr-3">Net Salary</th>
                  <th className="text-right py-3 pr-3">Paid</th>
                  <th className="text-right py-3 pr-3">Due</th>
                  <th className="text-center py-3 pr-3">Status</th>
                  <th className="text-center py-3">Action</th>
                </tr>
              </thead>
              <tbody>
                {records.map(r => (
                  <tr key={r._id} className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="py-2.5 pr-3">
                      <p className="font-medium">{r.employeeName}</p>
                      <p className="text-xs text-gray-400">{r.designation}</p>
                    </td>
                    <td className="py-2.5 pr-3 text-xs text-gray-500">{r.department}</td>
                    <td className="py-2.5 pr-3 text-right text-xs">৳{r.basicSalary.toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-right text-xs">৳{r.grossSalary.toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-right text-xs text-red-500">-৳{r.totalDeductions.toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-right font-semibold">৳{r.netSalary.toLocaleString()}</td>
                    {editId === r._id ? (
                      <>
                        <td className="py-2.5 pr-3" colSpan={3}>
                          <div className="flex gap-2 items-center">
                            <input type="number" className="input text-xs py-1 w-32" placeholder="Paid amount" value={editForm.paidAmount || 0}
                              onChange={e => setEditForm(f => ({ ...f, paidAmount: parseFloat(e.target.value) || 0 }))} />
                            <input type="date" className="input text-xs py-1 w-36" value={editForm.paymentDate || ''}
                              onChange={e => setEditForm(f => ({ ...f, paymentDate: e.target.value }))} />
                            <select className="input text-xs py-1 w-36" value={editForm.paymentMethod || 'Bank Transfer'}
                              onChange={e => setEditForm(f => ({ ...f, paymentMethod: e.target.value }))}>
                              <option>Bank Transfer</option><option>Cash</option><option>Cheque</option><option>Mobile Banking</option>
                            </select>
                          </div>
                        </td>
                        <td className="py-2.5 text-center">
                          <div className="flex gap-1 justify-center">
                            <button onClick={() => handleSaveEdit(r)} className="text-emerald-500 hover:text-emerald-700 p-1"><Save size={14} /></button>
                            <button onClick={() => setEditId(null)} className="text-gray-400 hover:text-gray-600 p-1"><X size={14} /></button>
                          </div>
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="py-2.5 pr-3 text-right text-emerald-600 font-medium">৳{r.paidAmount.toLocaleString()}</td>
                        <td className="py-2.5 pr-3 text-right text-red-500 font-medium">৳{r.dueAmount.toLocaleString()}</td>
                        <td className="py-2.5 pr-3 text-center">
                          <span className={`text-xs px-2 py-0.5 rounded-full font-medium capitalize ${STATUS_STYLE[r.status] || ''}`}>{r.status}</span>
                        </td>
                        <td className="py-2.5 text-center">
                          <button onClick={() => startEdit(r)} className="text-blue-400 hover:text-blue-600 p-1 rounded" title="Record Payment">
                            <Edit2 size={14} />
                          </button>
                        </td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t-2 border-gray-300 dark:border-gray-600 font-semibold text-sm bg-gray-50 dark:bg-gray-800/50">
                  <td className="py-3 pr-3" colSpan={5}>Total</td>
                  <td className="py-3 pr-3 text-right">৳{totalNet.toLocaleString()}</td>
                  <td className="py-3 pr-3 text-right text-emerald-600">৳{totalPaid.toLocaleString()}</td>
                  <td className="py-3 pr-3 text-right text-red-500">৳{totalDue.toLocaleString()}</td>
                  <td colSpan={2}></td>
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
