'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import Link from 'next/link';
import { DollarSign, TrendingUp, TrendingDown, Receipt, Wallet, Banknote, PiggyBank, ArrowRight } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function AccountingReportsPage() {
  const { transactions } = useERPStore();

  const income = transactions.filter(t => t.type === 'income').reduce((a, t) => a + t.amount, 0);
  const expense = transactions.filter(t => t.type === 'expense').reduce((a, t) => a + t.amount, 0);
  const profit = income - expense;

  const byCategory = Object.entries(
    transactions.reduce((acc, t) => {
      if (!acc[t.category]) acc[t.category] = { income: 0, expense: 0 };
      if (t.type === 'income') acc[t.category].income += t.amount;
      else acc[t.category].expense += t.amount;
      return acc;
    }, {} as Record<string, { income: number; expense: number }>)
  ).map(([name, data]) => ({ name, ...data }));

  const reportLinks = [
    { title: 'All Transactions', desc: 'Complete transaction ledger', href: '/accounting', icon: Receipt, color: 'blue' },
    { title: 'Chart of Accounts', desc: 'Account structure and balances', href: '/accounting/accounts', icon: Wallet, color: 'emerald' },
    { title: 'Payroll', desc: 'Employee salary payments', href: '/accounting/payroll', icon: Banknote, color: 'purple' },
    { title: 'Budget', desc: 'Budget planning and tracking', href: '/accounting/budget', icon: PiggyBank, color: 'amber' },
  ];

  return (
    <div className="page-wrapper">
      <Topbar title="Accounting Reports" subtitle="Financial statements and analytics" />

      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Income', value: `$${income.toLocaleString()}`, color: 'emerald', icon: TrendingUp },
          { label: 'Total Expenses', value: `$${expense.toLocaleString()}`, color: 'red', icon: TrendingDown },
          { label: 'Net Profit', value: `$${profit.toLocaleString()}`, color: profit >= 0 ? 'blue' : 'red', icon: DollarSign },
        ].map(s => (
          <div key={s.label} className="card flex items-center gap-4">
            <div className={`w-12 h-12 bg-${s.color}-50 rounded-2xl flex items-center justify-center`}>
              <s.icon className={`w-5 h-5 text-${s.color}-500`} />
            </div>
            <div><p className={`text-2xl font-bold text-${s.color}-600`}>{s.value}</p><p className="text-xs text-gray-400">{s.label}</p></div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Quick Access Reports</h3>
          <div className="space-y-3">
            {reportLinks.map(r => (
              <Link key={r.href} href={r.href} className="group flex items-center gap-4 p-4 border border-gray-100 rounded-2xl hover:border-blue-200 hover:bg-blue-50/40 transition-all">
                <div className={`w-10 h-10 bg-${r.color}-50 rounded-xl flex items-center justify-center flex-shrink-0`}>
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
          <h3 className="font-bold text-gray-900 mb-4">Income vs Expense by Category</h3>
          <div className="space-y-3">
            {byCategory.map(c => (
              <div key={c.name} className="p-3 border border-gray-100 rounded-xl">
                <p className="font-semibold text-sm text-gray-900 mb-2">{c.name}</p>
                <div className="grid grid-cols-2 gap-2 text-xs">
                  {c.income > 0 && (
                    <div className="flex items-center gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-emerald-400" />
                      <span className="text-gray-500">Income: </span>
                      <span className="font-semibold text-emerald-600">${c.income.toLocaleString()}</span>
                    </div>
                  )}
                  {c.expense > 0 && (
                    <div className="flex items-center gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-red-400" />
                      <span className="text-gray-500">Expense: </span>
                      <span className="font-semibold text-red-600">${c.expense.toLocaleString()}</span>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Transaction Ledger</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Date', 'Description', 'Category', 'Type', 'Method', 'Amount'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {transactions.sort((a, b) => b.date.localeCompare(a.date)).map(t => (
                <tr key={t.id} className="table-row">
                  <td className="table-cell text-gray-500 text-xs">{t.date}</td>
                  <td className="table-cell font-medium text-gray-900 text-sm">{t.description}</td>
                  <td className="table-cell"><span className="badge badge-blue">{t.category}</span></td>
                  <td className="table-cell">
                    <span className={`badge ${t.type === 'income' ? 'badge-green' : 'badge-red'} flex items-center gap-1 w-fit`}>
                      {t.type === 'income' ? <TrendingUp size={10} /> : <TrendingDown size={10} />}
                      {t.type}
                    </span>
                  </td>
                  <td className="table-cell text-gray-500 text-xs">{t.method || '—'}</td>
                  <td className="table-cell">
                    <span className={`font-bold ${t.type === 'income' ? 'text-emerald-600' : 'text-red-600'}`}>
                      {t.type === 'income' ? '+' : '-'}${t.amount.toLocaleString()}
                    </span>
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
