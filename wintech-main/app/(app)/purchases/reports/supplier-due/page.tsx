'use client';
import Topbar from '@/components/layout/Topbar';
import { useERPStore } from '@/lib/store';
import { Building2, AlertTriangle, Mail, Phone } from 'lucide-react';

export default function SupplierDuePage() {
  const { suppliers } = useERPStore();
  const dueSuppliers = suppliers.filter(s => s.balance > 0).sort((a, b) => b.balance - a.balance);
  const totalDue = dueSuppliers.reduce((a, s) => a + s.balance, 0);

  return (
    <div className="page-wrapper">
      <Topbar title="Supplier Due List" subtitle="Suppliers with outstanding payables" />

      <div className="grid grid-cols-3 gap-4">
        <div className="card"><p className="text-2xl font-bold text-amber-600">${totalDue.toLocaleString()}</p><p className="text-sm text-gray-500 mt-1">Total Payable</p></div>
        <div className="card"><p className="text-2xl font-bold text-red-600">{dueSuppliers.length}</p><p className="text-sm text-gray-500 mt-1">Suppliers with Dues</p></div>
        <div className="card"><p className="text-2xl font-bold text-blue-600">{suppliers.filter(s=>s.balance===0).length}</p><p className="text-sm text-gray-500 mt-1">Cleared Suppliers</p></div>
      </div>

      <div className="card">
        <h3 className="font-bold text-gray-900 mb-4">Outstanding Supplier Balances</h3>
        <div className="table-wrapper">
          <table className="w-full">
            <thead><tr>{['Supplier', 'Category', 'Contact', 'Total Orders', 'Amount Due', 'Priority'].map(h => <th key={h} className="table-header">{h}</th>)}</tr></thead>
            <tbody className="divide-y divide-gray-50">
              {dueSuppliers.map(s => {
                const priority = s.balance > 5000 ? 'Urgent' : s.balance > 1000 ? 'Medium' : 'Low';
                const pColor = priority === 'Urgent' ? 'badge-red' : priority === 'Medium' ? 'badge-yellow' : 'badge-green';
                return (
                  <tr key={s.id} className="table-row">
                    <td className="table-cell">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-gradient-to-br from-amber-400 to-orange-500 rounded-full flex items-center justify-center text-white text-xs font-bold">{s.name.charAt(0)}</div>
                        <p className="font-semibold text-gray-900">{s.name}</p>
                      </div>
                    </td>
                    <td className="table-cell"><span className="badge badge-blue">{s.category}</span></td>
                    <td className="table-cell">
                      <div className="flex flex-col gap-0.5 text-xs text-gray-500">
                        <span className="flex items-center gap-1"><Mail size={10} />{s.email}</span>
                        <span className="flex items-center gap-1"><Phone size={10} />{s.phone}</span>
                      </div>
                    </td>
                    <td className="table-cell text-center font-semibold">{s.totalOrders}</td>
                    <td className="table-cell">
                      <div className="flex items-center gap-2">
                        <AlertTriangle size={14} className="text-amber-500" />
                        <span className="font-bold text-amber-600 text-base">${s.balance.toLocaleString()}</span>
                      </div>
                    </td>
                    <td className="table-cell"><span className={`badge ${pColor}`}>{priority}</span></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {dueSuppliers.length === 0 && (
            <div className="text-center py-12 text-gray-400">
              <Building2 className="w-10 h-10 mx-auto mb-2 opacity-30" />
              <p>No outstanding supplier dues — all payments are cleared!</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
