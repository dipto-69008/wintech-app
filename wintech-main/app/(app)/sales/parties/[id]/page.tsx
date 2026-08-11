'use client';
import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import Topbar from '@/components/layout/Topbar';
import Link from 'next/link';
import {
  ArrowLeft, Mail, Phone, MapPin, Calendar, Loader2, ShoppingCart,
  DollarSign, User, Globe, Building2, CreditCard, Hash, FileText, Tag
} from 'lucide-react';
import { formatDate } from '@/lib/utils';

interface Party {
  _id: string; code: string; name: string; type?: string; phone?: string; mobile?: string;
  email?: string; officePhone?: string; address?: string; web?: string;
  contactPerson?: string; ownerName?: string; area?: string;
  creditLimit?: number; previousDue?: number; status: string;
  addTime?: string; branchId?: number; employeeId?: string;
}
interface Invoice {
  _id: string; invoiceNo: string; saleDate: string; paymentType: string;
  subTotal: number; paidAmount: number; dueAmount: number; status: string;
}

const statusBadge = (s: string) =>
  s === 'a' ? 'badge-green' : s === 'pending' ? 'badge-yellow' : 'badge-gray';
const statusLabel = (s: string) =>
  s === 'a' ? 'Active' : s === 'pending' ? 'Pending' : 'Cancelled';

function InfoRow({ icon: Icon, label, value }: { icon: React.ElementType; label: string; value?: string | number | null }) {
  if (!value && value !== 0) return null;
  return (
    <div className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-xl">
      <Icon size={15} className="text-gray-400 flex-shrink-0 mt-0.5" />
      <div className="min-w-0">
        <p className="text-[10px] text-gray-400 font-medium uppercase tracking-wide">{label}</p>
        <p className="text-sm text-gray-700 dark:text-gray-200 font-medium break-words">{String(value)}</p>
      </div>
    </div>
  );
}

export default function PartyDetailPage() {
  const { id } = useParams();
  const [party, setParty] = useState<Party | null>(null);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const r = await fetch(`/api/parties/${id}`);
        if (!r.ok) return;
        const p = await r.json();
        setParty(p);
        const ir = await fetch(`/api/sales?search=${encodeURIComponent(p.name)}&limit=50`);
        if (ir.ok) { const id_ = await ir.json(); setInvoices(id_.data || []); }
      } finally { setLoading(false); }
    })();
  }, [id]);

  if (loading) return (
    <div className="page-wrapper">
      <div className="flex items-center justify-center py-20 gap-2 text-gray-400"><Loader2 className="animate-spin" size={20} />Loading...</div>
    </div>
  );

  if (!party) return (
    <div className="page-wrapper">
      <div className="card text-center py-16 text-gray-400">
        <p className="text-lg font-semibold">Party not found</p>
        <Link href="/sales/parties" className="text-blue-500 text-sm mt-2 inline-block">← Back to Parties</Link>
      </div>
    </div>
  );

  const totalSales = invoices.reduce((a, i) => a + (i.subTotal || 0), 0);
  const totalPaid = invoices.reduce((a, i) => a + (i.paidAmount || 0), 0);
  const totalDue = invoices.reduce((a, i) => a + (i.dueAmount || 0), 0);

  return (
    <div className="page-wrapper">
      <Topbar
        title={party.name}
        subtitle={`Code: ${party.code}`}
        actions={<Link href="/sales/parties" className="btn-secondary flex items-center gap-2"><ArrowLeft size={15} />Back</Link>}
      />

      {/* Summary cards */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Invoices', value: invoices.length, color: 'blue', icon: FileText },
          { label: 'Total Sales', value: `৳${totalSales.toLocaleString()}`, color: 'emerald', icon: ShoppingCart },
          { label: 'Total Paid', value: `৳${totalPaid.toLocaleString()}`, color: 'purple', icon: DollarSign },
          { label: 'Total Due', value: `৳${totalDue.toLocaleString()}`, color: totalDue > 0 ? 'red' : 'emerald', icon: CreditCard },
        ].map(s => (
          <div key={s.label} className="card flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl bg-${s.color}-50 dark:bg-${s.color}-900/20 flex items-center justify-center flex-shrink-0`}>
              <s.icon size={18} className={`text-${s.color}-500`} />
            </div>
            <div>
              <p className={`text-lg font-bold text-${s.color}-600`}>{s.value}</p>
              <p className="text-xs text-gray-400">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[320px_1fr] gap-4 items-start">
        {/* ── Left: Party profile ── */}
        <div className="space-y-4">
          {/* Avatar + name */}
          <div className="card text-center">
            <div className="w-20 h-20 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center text-white text-3xl font-bold mx-auto mb-3">
              {party.name.charAt(0)}
            </div>
            <h2 className="font-bold text-xl text-gray-900 dark:text-white">{party.name}</h2>
            {party.ownerName && <p className="text-sm text-gray-500 mt-0.5">{party.ownerName}</p>}
            <div className="flex items-center justify-center gap-2 mt-2 flex-wrap">
              <span className={`badge ${party.status === 'a' ? 'badge-green' : 'badge-gray'}`}>{party.status === 'a' ? 'Active' : 'Inactive'}</span>
              {party.type && <span className="badge badge-blue">{party.type}</span>}
            </div>
          </div>

          {/* All info */}
          <div className="card space-y-2">
            <h3 className="font-semibold text-gray-700 dark:text-gray-200 text-sm mb-3">Contact Information</h3>
            <InfoRow icon={Hash} label="Party Code" value={party.code} />
            <InfoRow icon={Phone} label="Mobile" value={party.mobile} />
            <InfoRow icon={Phone} label="Phone" value={party.phone} />
            <InfoRow icon={Phone} label="Office Phone" value={party.officePhone} />
            <InfoRow icon={Mail} label="Email" value={party.email} />
            <InfoRow icon={Globe} label="Website" value={party.web} />
            <InfoRow icon={MapPin} label="Address" value={party.address} />
            <InfoRow icon={Tag} label="Area" value={party.area} />
          </div>

          <div className="card space-y-2">
            <h3 className="font-semibold text-gray-700 dark:text-gray-200 text-sm mb-3">Business Details</h3>
            <InfoRow icon={User} label="Contact Person" value={party.contactPerson} />
            <InfoRow icon={Building2} label="Owner" value={party.ownerName} />
            <InfoRow icon={CreditCard} label="Credit Limit" value={party.creditLimit ? `৳${party.creditLimit.toLocaleString()}` : null} />
            <InfoRow icon={DollarSign} label="Previous Due" value={party.previousDue ? `৳${party.previousDue.toLocaleString()}` : '৳0'} />
            {party.addTime && <InfoRow icon={Calendar} label="Joined" value={formatDate(party.addTime)} />}
          </div>
        </div>

        {/* ── Right: Invoice history ── */}
        <div className="card">
          <h3 className="font-bold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
            <FileText size={16} className="text-blue-500" />
            Invoice History
            {invoices.length > 0 && <span className="text-xs bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full font-semibold">{invoices.length}</span>}
          </h3>
          {invoices.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 dark:border-gray-700 text-xs text-gray-500">
                    {['Invoice No', 'Date', 'Payment', 'Amount', 'Paid', 'Due', 'Status'].map(h => (
                      <th key={h} className="py-2.5 pr-4 font-medium text-left">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {invoices.map(inv => (
                    <tr key={inv._id} className="border-b border-gray-50 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                      <td className="py-2.5 pr-4 font-mono text-xs text-blue-600 font-semibold">{inv.invoiceNo}</td>
                      <td className="py-2.5 pr-4 text-xs text-gray-500">{formatDate(inv.saleDate)}</td>
                      <td className="py-2.5 pr-4 text-xs text-gray-500">{inv.paymentType}</td>
                      <td className="py-2.5 pr-4 font-bold text-gray-800 dark:text-white">৳{(inv.subTotal || 0).toLocaleString()}</td>
                      <td className="py-2.5 pr-4 text-emerald-600 font-semibold">৳{(inv.paidAmount || 0).toLocaleString()}</td>
                      <td className="py-2.5 pr-4">
                        {(inv.dueAmount || 0) > 0
                          ? <span className="text-red-500 font-semibold">৳{(inv.dueAmount || 0).toLocaleString()}</span>
                          : <span className="badge badge-green text-[10px]">Clear</span>}
                      </td>
                      <td className="py-2.5 pr-4">
                        <span className={`badge ${statusBadge(inv.status)}`}>{statusLabel(inv.status)}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12 text-gray-400">
              <ShoppingCart className="w-10 h-10 mx-auto mb-2 opacity-30" />
              <p className="font-medium">No invoices found</p>
              <p className="text-xs mt-1">Invoices for this party will appear here</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
