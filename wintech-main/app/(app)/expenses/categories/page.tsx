'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import { Tag, TrendingUp } from 'lucide-react';

const CATEGORY_COLORS: Record<string, string> = {
  Travel: 'bg-blue-100 text-blue-700',
  Meals: 'bg-emerald-100 text-emerald-700',
  'Office Supplies': 'bg-purple-100 text-purple-700',
  Training: 'bg-amber-100 text-amber-700',
  Marketing: 'bg-rose-100 text-rose-700',
  Utilities: 'bg-teal-100 text-teal-700',
  Medical: 'bg-red-100 text-red-700',
  Other: 'bg-gray-100 text-gray-700',
};

export default function ExpenseCategoriesPage() {
  const { expenseClaims } = useERPStore();

  const categoryStats = Object.entries(
    expenseClaims.reduce((acc, e) => {
      if (!acc[e.category]) acc[e.category] = { count: 0, total: 0 };
      acc[e.category].count++;
      acc[e.category].total += e.amount;
      return acc;
    }, {} as Record<string, { count: number; total: number }>)
  ).sort((a, b) => b[1].total - a[1].total);

  const grandTotal = expenseClaims.reduce((s, e) => s + e.amount, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Expense Categories" subtitle="Breakdown of expenses by category" />

      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
        {categoryStats.map(([cat, stats]) => {
          const pct = grandTotal > 0 ? (stats.total / grandTotal) * 100 : 0;
          const colorClass = CATEGORY_COLORS[cat] || 'bg-gray-100 text-gray-700';
          return (
            <div key={cat} className="card hover:shadow-md transition-all">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`icon-box ${colorClass}`}><Tag size={16} /></div>
                  <div>
                    <h3 className="font-bold text-gray-900 text-sm">{cat}</h3>
                    <p className="text-xs text-gray-400">{stats.count} claims</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-lg font-bold text-gray-900">${stats.total.toLocaleString()}</p>
                  <p className="text-xs text-gray-400">{pct.toFixed(1)}% of total</p>
                </div>
              </div>
              <div className="h-2 bg-gray-100 rounded-full">
                <div className={`h-2 rounded-full transition-all ${colorClass.split(' ')[0].replace('bg-', 'bg-').replace('-100', '-400')}`} style={{ width: `${pct}%` }} />
              </div>
            </div>
          );
        })}
        {categoryStats.length === 0 && (
          <div className="col-span-3 card text-center py-16">
            <TrendingUp className="w-12 h-12 text-gray-200 mx-auto mb-3" />
            <p className="text-gray-400 font-medium">No expense data yet</p>
          </div>
        )}
      </div>
    </div>
  );
}
