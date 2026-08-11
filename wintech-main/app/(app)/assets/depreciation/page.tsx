'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import { TrendingDown, Calculator } from 'lucide-react';

export default function DepreciationPage() {
  const { assets } = useERPStore();

  const rows = assets.map(a => {
    const accumulated = a.purchaseCost - a.currentValue;
    const annualDep = (a.purchaseCost * a.depreciationRate) / 100;
    const years = a.purchaseCost > 0 ? Math.round(accumulated / (annualDep || 1)) : 0;
    return { ...a, accumulated, annualDep, years };
  });

  const totalAnnual = rows.reduce((s, r) => s + r.annualDep, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Asset Depreciation" subtitle="Annual depreciation schedule for all fixed assets" />

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[
          { label: 'Total Assets', value: assets.length, sub: 'registered assets' },
          { label: 'Total Accumulated', value: `$${rows.reduce((s, r) => s + r.accumulated, 0).toLocaleString()}`, sub: 'total depreciation to date' },
          { label: 'Annual Depreciation', value: `$${totalAnnual.toLocaleString()}`, sub: 'scheduled this year' },
        ].map(k => (
          <div key={k.label} className="stat-card">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">{k.label}</p>
            <p className="text-2xl font-bold text-gray-900 mt-1">{k.value}</p>
            <p className="text-xs text-gray-400 mt-0.5">{k.sub}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="flex items-center gap-2.5 mb-5">
          <div className="icon-box bg-amber-50 text-amber-600"><Calculator size={18} /></div>
          <div>
            <h3 className="section-title">Depreciation Schedule</h3>
            <p className="section-subtitle">Straight-line method based on depreciation rates</p>
          </div>
        </div>
        <div className="table-wrapper">
          <table className="w-full">
            <thead>
              <tr>
                {['Asset', 'Category', 'Purchase Cost', 'Accumulated Dep.', 'Annual Dep.', 'Rate', 'Current Value', 'Progress'].map(h => (
                  <th key={h} className="table-header">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map(r => {
                const pct = r.purchaseCost > 0 ? Math.min((r.accumulated / r.purchaseCost) * 100, 100) : 0;
                return (
                  <tr key={r.id} className="table-row">
                    <td className="table-cell font-semibold text-gray-900">{r.name}</td>
                    <td className="table-cell"><span className="badge badge-blue">{r.category}</span></td>
                    <td className="table-cell">${r.purchaseCost.toLocaleString()}</td>
                    <td className="table-cell text-red-600 font-semibold">${r.accumulated.toLocaleString()}</td>
                    <td className="table-cell text-amber-600 font-semibold">${r.annualDep.toLocaleString()}/yr</td>
                    <td className="table-cell">{r.depreciationRate}%</td>
                    <td className="table-cell text-emerald-600 font-semibold">${r.currentValue.toLocaleString()}</td>
                    <td className="table-cell">
                      <div className="flex items-center gap-2">
                        <div className="flex-1 h-2 bg-gray-100 rounded-full w-24">
                          <div className="h-2 bg-amber-400 rounded-full transition-all" style={{ width: `${pct}%` }} />
                        </div>
                        <span className="text-xs text-gray-500 font-semibold">{pct.toFixed(0)}%</span>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
