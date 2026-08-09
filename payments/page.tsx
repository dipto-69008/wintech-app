'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import Link from 'next/link';
import { Plus, Trash2, Edit3, Wallet, Search, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { PageHeader } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Input, Select, Field, Textarea } from '@/components/ui/Input';
import { Modal } from '@/components/ui/Modal';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { StatCard } from '@/components/ui/StatCard';
import { EmptyState } from '@/components/ui/EmptyState';
import { PageLoader } from '@/components/ui/Spinner';
import { useConfirm } from '@/components/ui/Confirm';
import { api } from '@/lib/api-client';
import { useFormDirty } from '@/lib/hooks/useFormDirty';
import { formatCurrency, formatDate } from '@/lib/utils';
import { useAuthStore } from '@/lib/stores/authStore';

function localDate(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
const today      = localDate(new Date());
const monthStart = localDate(new Date(new Date().getFullYear(), new Date().getMonth(), 1));

const empty = { client: '', invoice: '', order: '', amount: 0, method: 'cash', status: 'received', paidAt: today, reference: '', notes: '' };

const METHODS = [
  { v: 'cash', label: 'Cash' }, { v: 'bank', label: 'Bank Transfer' }, { v: 'card', label: 'Card' },
  { v: 'bkash', label: 'bKash' }, { v: 'nagad', label: 'Nagad' },
  { v: 'steadfast', label: 'Steadfast Courier' }, { v: 'pathao', label: 'Pathao Courier' },
  { v: 'online', label: 'Online Gateway' }, { v: 'other', label: 'Other' },
];

export default function PaymentsPage() {
  const me = useAuthStore((s) => s.user);
  const isAdmin = me?.role === 'admin' || me?.role === 'manager';
  const [items, setItems] = useState<any[] | null>(null);
  const [clients, setClients] = useState<any[]>([]);
  const [invoices, setInvoices] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [open, setOpen] = useState(false);
  const [edit, setEdit] = useState<any>(null);
  const [form, setForm] = useState<any>(empty);
  const [saving, setSaving] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [clientSearch, setClientSearch] = useState('');
  const [showClientDrop, setShowClientDrop] = useState(false);
  const { takeSnapshot, isDirty, forPatch } = useFormDirty(form);
  const { confirm, Confirmation } = useConfirm();

  // ── Filter state (date defaults to current month) ──────────────────────────
  const [search, setSearch]       = useState('');
  const [filterFrom, setFilterFrom] = useState(monthStart);
  const [filterTo, setFilterTo]   = useState(today);
  const [filterStatus, setFilterStatus] = useState('');
  const [filterMethod, setFilterMethod] = useState('');
  const searchTimer = useRef<any>(null);

  const buildQuery = useCallback((skip = 0) => {
    const p = new URLSearchParams({ skip: String(skip), limit: '50' });
    if (search)       p.set('search', search);
    if (filterFrom)   p.set('from', filterFrom);
    if (filterTo)     p.set('to', filterTo);
    if (filterStatus) p.set('status', filterStatus);
    if (filterMethod) p.set('method', filterMethod);
    return `/api/payments?${p.toString()}`;
  }, [search, filterFrom, filterTo, filterStatus, filterMethod]);

  const [formDataLoaded, setFormDataLoaded] = useState(false);

  const load = useCallback(async () => {
    setItems(null);
    const p = await api.get<{ items: any[]; hasMore: boolean }>(buildQuery(0));
    setItems(p.items); setHasMore(p.hasMore);
  }, [buildQuery]);

  useEffect(() => { load(); }, [load]);

  const loadFormData = useCallback(async () => {
    if (formDataLoaded) return;
    const [c, iv, ord] = await Promise.all([
      api.get<any[]>('/api/clients').catch(() => []),
      api.get<any[]>('/api/invoices').catch(() => []),
      api.get<any[]>('/api/orders').catch(() => []),
    ]);
    setClients(c); setInvoices(iv); setOrders(ord);
    setFormDataLoaded(true);
  }, [formDataLoaded]);

  // debounce search input
  function onSearchChange(v: string) {
    setSearch(v);
    clearTimeout(searchTimer.current);
  }

  function clearFilters() {
    setSearch(''); setFilterFrom(monthStart); setFilterTo(today);
    setFilterStatus(''); setFilterMethod('');
  }

  function openNew() { setEdit(null); setForm({ ...empty }); setClientSearch(''); setOpen(true); loadFormData(); }
  function openEdit(p: any) {
    const fv = { ...empty, ...p, client: p.client?._id || p.client || '', invoice: p.invoice?._id || p.invoice || '', order: p.order?._id || p.order || '', paidAt: p.paidAt ? new Date(p.paidAt).toISOString().slice(0, 10) : today };
    setEdit(p);
    setForm(fv);
    setClientSearch(p.client?.phone || p.client?.name || '');
    takeSnapshot(fv);
    setOpen(true);
    loadFormData();
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const payload: any = { ...form, amount: Number(form.amount) };
      if (!payload.client) delete payload.client;
      if (!payload.invoice) delete payload.invoice;
      if (!payload.order) delete payload.order;
      if (edit) await api.patch(`/api/payments/${edit._id}`, forPatch(payload));
      else await api.post('/api/payments', payload);
      toast.success(edit ? 'Updated' : 'Recorded');
      setOpen(false); load();
    } catch (e: any) { toast.error(e.message); }
    finally { setSaving(false); }
  }

  const filteredInvoices = form.client
    ? invoices.filter((iv) => (iv.client?._id || iv.client) === form.client)
    : invoices;
  const filteredOrders = form.client
    ? orders.filter((o: any) => (o.client?._id || o.client) === form.client)
    : [];

  async function remove(p: any) {
    confirm({ title: 'Delete payment', message: `Delete payment ${p.paymentNo}?`, onConfirm: async () => {
      try { await api.delete(`/api/payments/${p._id}`); toast.success('Deleted'); load(); } catch (e: any) { toast.error(e.message); }
    }});
  }

  async function loadMore() {
    setLoadingMore(true);
    try {
      const res = await api.get<{ items: any[]; hasMore: boolean }>(buildQuery(items?.length || 0));
      setItems(prev => [...(prev || []), ...res.items]);
      setHasMore(res.hasMore);
    } finally { setLoadingMore(false); }
  }

  if (!items) return <PageLoader />;

  const totalReceived = items.filter((p) => p.status === 'received').reduce((s, p) => s + (p.amount || 0), 0);
  const totalPending  = items.filter((p) => p.status === 'pending').reduce((s, p) => s + (p.amount || 0), 0);
  const monthReceived = items.filter((p) => p.status === 'received' && new Date(p.paidAt).getMonth() === new Date().getMonth() && new Date(p.paidAt).getFullYear() === new Date().getFullYear()).reduce((s, p) => s + (p.amount || 0), 0);

  const statusColor: any = { received: 'green', pending: 'amber', failed: 'red', refunded: 'slate' };
  const hasActiveFilter = search || filterStatus || filterMethod || filterFrom !== monthStart || filterTo !== today;

  return (
    <>
      <PageHeader title="Payments" subtitle="Record and track money received from clients."
        actions={<Button onClick={openNew}><Plus className="w-4 h-4" /> New Payment</Button>} />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <StatCard label="Total Received" value={formatCurrency(totalReceived)} icon={Wallet} color="green" />
        <StatCard label="This Month"     value={formatCurrency(monthReceived)} icon={Wallet} color="blue" />
        <StatCard label="Pending"        value={formatCurrency(totalPending)}  icon={Wallet} color="amber" />
        <StatCard label="Total Records"  value={items.length}                  icon={Wallet} color="purple" />
      </div>

      {/* ── Filter bar ── */}
      <Card className="mb-4 p-3">
        <div className="flex flex-wrap gap-2 items-end">
          {/* Search */}
          <div className="relative flex-1 min-w-[160px]">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400 pointer-events-none" />
            <input
              type="text"
              placeholder="Search payment #..."
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
              className="w-full pl-8 pr-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          {/* Date from */}
          <div className="flex items-center gap-1">
            <span className="text-xs text-slate-500 whitespace-nowrap">From</span>
            <input
              type="date"
              value={filterFrom}
              onChange={(e) => setFilterFrom(e.target.value)}
              className="text-sm border border-slate-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Date to */}
          <div className="flex items-center gap-1">
            <span className="text-xs text-slate-500 whitespace-nowrap">To</span>
            <input
              type="date"
              value={filterTo}
              onChange={(e) => setFilterTo(e.target.value)}
              className="text-sm border border-slate-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Status */}
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="text-sm border border-slate-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white"
          >
            <option value="">All Status</option>
            <option value="received">Received</option>
            <option value="pending">Pending</option>
            <option value="failed">Failed</option>
            <option value="refunded">Refunded</option>
          </select>

          {/* Method */}
          <select
            value={filterMethod}
            onChange={(e) => setFilterMethod(e.target.value)}
            className="text-sm border border-slate-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white"
          >
            <option value="">All Methods</option>
            {METHODS.map((m) => <option key={m.v} value={m.v}>{m.label}</option>)}
          </select>

          {/* Clear */}
          {hasActiveFilter && (
            <button
              onClick={clearFilters}
              className="flex items-center gap-1 text-xs text-slate-500 hover:text-red-500 px-2 py-1.5 rounded-lg border border-slate-200 hover:border-red-300 transition-colors"
            >
              <X className="w-3 h-3" /> Clear
            </button>
          )}
        </div>
      </Card>

      {items.length === 0 ? (
        <EmptyState icon={Wallet} title="No payments found" description={hasActiveFilter ? 'Try adjusting your filters.' : 'Record your first payment.'} action={!hasActiveFilter ? <Button onClick={openNew}><Plus className="w-4 h-4" /> New Payment</Button> : undefined} />
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-600 text-xs uppercase tracking-wider">
                <tr>
                  <th className="px-4 py-3 text-left">Payment #</th>
                  <th className="px-4 py-3 text-left">Date</th>
                  <th className="px-4 py-3 text-left">Client</th>
                  <th className="px-4 py-3 text-left">Order</th>
                  <th className="px-4 py-3 text-left">Invoice</th>
                  <th className="px-4 py-3 text-left">Method</th>
                  <th className="px-4 py-3 text-right">Amount</th>
                  <th className="px-4 py-3 text-left">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {items.map((p) => (
                  <tr key={p._id} className="hover:bg-slate-50">
                    <td className="px-4 py-3 font-medium text-slate-800">{p.paymentNo}</td>
                    <td className="px-4 py-3 text-slate-600">{formatDate(p.paidAt)}</td>
                    <td className="px-4 py-3 text-slate-700">{p.client?.name || '—'}</td>
                    <td className="px-4 py-3">
                      {p.order?._id ? (
                        <Link href={`/finance/orders/${p.order._id}`} className="text-blue-600 hover:underline font-medium">
                          {p.order.orderNo}
                        </Link>
                      ) : '—'}
                    </td>
                    <td className="px-4 py-3">
                      {p.invoice?._id ? (
                        <Link href={`/invoices/${p.invoice._id}`} className="text-blue-600 hover:underline font-medium">
                          {p.invoice.number}
                        </Link>
                      ) : '—'}
                    </td>
                    <td className="px-4 py-3"><Badge color="slate">{METHODS.find(m => m.v === p.method)?.label || p.method}</Badge></td>
                    <td className="px-4 py-3 text-right text-base font-semibold text-slate-900">{formatCurrency(p.amount)}</td>
                    <td className="px-4 py-3"><Badge color={statusColor[p.status] || 'slate'}>{p.status}</Badge></td>
                    <td className="px-4 py-3 text-right whitespace-nowrap">
                      <button onClick={() => openEdit(p)} className="p-1.5 rounded hover:bg-slate-100 text-slate-500"><Edit3 className="w-4 h-4" /></button>
                      {isAdmin && <button onClick={() => remove(p)} className="p-1.5 rounded hover:bg-red-100 text-red-500"><Trash2 className="w-4 h-4" /></button>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {hasMore && (
        <div className="mt-4 text-center">
          <Button variant="outline" onClick={loadMore} loading={loadingMore}>Load more payments</Button>
        </div>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={edit ? 'Edit Payment' : 'New Payment'} size="lg"
        footer={<><Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button><Button onClick={save as any} loading={saving} disabled={!!edit && !isDirty}>{edit ? 'Update' : 'Record'}</Button></>}>
        <form onSubmit={save} className="space-y-4">
          <div className="grid sm:grid-cols-2 gap-4">
            <Field label="Customer">
              <div className="relative">
                <Input
                  placeholder="Search by phone or name"
                  value={clientSearch}
                  onChange={(e) => { setClientSearch(e.target.value); setForm({ ...form, client: '', invoice: '', order: '' }); setShowClientDrop(true); }}
                  onFocus={() => setShowClientDrop(true)}
                  onBlur={() => setTimeout(() => setShowClientDrop(false), 150)}
                />
                {showClientDrop && clientSearch.length > 0 && (
                  <div className="absolute z-50 top-full left-0 right-0 bg-white border border-slate-200 rounded-lg shadow-lg mt-1 max-h-48 overflow-y-auto">
                    {(() => {
                      const filtered = clients.filter((c: any) =>
                        (c.phone && c.phone.includes(clientSearch)) ||
                        c.name?.toLowerCase().includes(clientSearch.toLowerCase())
                      ).slice(0, 8);
                      return filtered.length > 0 ? filtered.map((c: any) => (
                        <button
                          key={c._id}
                          type="button"
                          onMouseDown={() => { setForm({ ...form, client: c._id, invoice: '', order: '' }); setClientSearch(c.phone || c.name); setShowClientDrop(false); }}
                          className="w-full text-left px-3 py-2.5 hover:bg-blue-50 flex items-center justify-between border-b border-slate-50 last:border-0"
                        >
                          <span className="font-medium text-sm text-slate-900">{c.name}</span>
                          {c.phone && <span className="text-xs text-slate-500">{c.phone}</span>}
                        </button>
                      )) : <p className="px-3 py-2 text-sm text-slate-500">No customers found</p>;
                    })()}
                  </div>
                )}
              </div>
              {form.client && (
                <p className="text-xs text-emerald-600 mt-1 font-medium">
                  {clients.find((c: any) => c._id === form.client)?.name}
                </p>
              )}
            </Field>
            <Field label="Order No">
              <Select value={form.order} onChange={(e) => {
                const selectedOrder = orders.find((o: any) => o._id === e.target.value);
                const balanceDue = selectedOrder ? Math.max((selectedOrder.total || 0) - (selectedOrder.amountPaid || 0), 0) : form.amount;
                setForm({ ...form, order: e.target.value, amount: e.target.value && selectedOrder ? balanceDue : form.amount });
              }}>
                <option value="">— None —</option>
                {filteredOrders.map((o: any) => {
                  const balance = Math.max((o.total || 0) - (o.amountPaid || 0), 0);
                  return (
                    <option key={o._id} value={o._id}>
                      {o.orderNo} — Due: {formatCurrency(balance)}
                    </option>
                  );
                })}
              </Select>
              {!form.client && <p className="text-xs text-slate-400 mt-1">Select a customer first</p>}
              {form.order && (() => {
                const o = orders.find((x: any) => x._id === form.order);
                if (!o) return null;
                const balance = Math.max((o.total || 0) - (o.amountPaid || 0), 0);
                return <p className="text-xs text-blue-600 mt-1">Balance due: {formatCurrency(balance)}</p>;
              })()}
            </Field>
            <Field label="Date" required>
              <Input type="date" value={form.paidAt} onChange={(e) => setForm({ ...form, paidAt: e.target.value })} required />
            </Field>
            <Field label="Status">
              <Select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                <option value="received">Received</option>
                <option value="pending">Pending</option>
                <option value="failed">Failed</option>
                <option value="refunded">Refunded</option>
              </Select>
            </Field>
            <Field label="Method">
              <Select value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })}>
                {METHODS.map((m) => <option key={m.v} value={m.v}>{m.label}</option>)}
              </Select>
            </Field>
            <Field label="Amount" required>
              <Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} required />
            </Field>
            <Field label="Reference / Transaction ID" className="sm:col-span-2">
              <Input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} placeholder="TRX-12345" />
            </Field>
            <Field label="Notes" className="sm:col-span-2">
              <Textarea rows={3} value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} />
            </Field>
          </div>
        </form>
      </Modal>
      {Confirmation}
    </>
  );
}
