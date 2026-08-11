'use client';
import { useState, useEffect, useCallback } from 'react';
import Topbar from '@/components/layout/Topbar';
import Link from 'next/link';
import { Package, AlertTriangle, Tag, ArrowRight, Loader2 } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444'];

interface Product {
  _id: string; name: string; categoryName?: string; status: string;
  sellingPrice: number; purchaseRate: number; reorderLevel?: number; stock?: number;
}

export default function InventoryReportsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [activeIdx, setActiveIdx] = useState(0);
  const onPieEnter = useCallback((_: unknown, idx: number) => setActiveIdx(idx), []);

  useEffect(() => {
    fetch('/api/products?limit=500').then(r => r.json()).then(d => {
      setProducts(d.data || []);
      setTotal(d.total || 0);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const lowStockItems = products.filter(p => (p.reorderLevel || 0) > 0 && (p.stock || 0) <= (p.reorderLevel || 0));
  const outOfStock = products.filter(p => (p.stock || 0) === 0);

  const byCategory = Object.entries(
    products.reduce((acc, p) => {
      const cat = p.categoryName || 'Uncategorized';
      if (!acc[cat]) acc[cat] = { count: 0, value: 0 };
      acc[cat].count += 1;
      acc[cat].value += p.sellingPrice || 0;
      return acc;
    }, {} as Record<string, { count: number; value: number }>)
  ).map(([name, data]) => ({ name: name.length > 14 ? name.slice(0, 14) + '…' : name, ...data }))
    .sort((a, b) => b.count - a.count).slice(0, 8);

  const pieData = byCategory.slice(0, 5);

  const reportLinks = [
    { title: 'Product List', desc: 'All inventory products', href: '/inventory', icon: Package, color: 'blue' },
    { title: 'Categories', desc: 'Product categories overview', href: '/inventory/categories', icon: Tag, color: 'purple' },
    { title: 'Stock Adjustments', desc: 'Stock add/remove history', href: '/inventory/adjustments', icon: ArrowRight, color: 'emerald' },
    { title: 'Low Stock Items', desc: 'Products that need reordering', href: '/inventory', icon: AlertTriangle, color: 'amber' },
  ];

  return (
    <div className="page-wrapper">
      <Topbar title="Inventory Reports" subtitle="Stock levels and inventory analytics" />

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Total Products', value: loading ? '…' : total, color: 'blue' },
          { label: 'Active Products', value: loading ? '…' : products.filter(p => p.status === 'a').length, color: 'emerald' },
          { label: 'Low Stock Items', value: loading ? '…' : lowStockItems.length, color: 'amber' },
          { label: 'Out of Stock', value: loading ? '…' : outOfStock.length, color: 'red' },
        ].map(s => (
          <div key={s.label} className="card">
            <p className={`text-2xl font-bold text-${s.color}-600`}>{loading ? <Loader2 className="animate-spin" size={20} /> : s.value}</p>
            <p className="text-sm text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Available Reports</h3>
          <div className="space-y-3">
            {reportLinks.map(r => (
              <Link key={r.href} href={r.href} className="group flex items-center gap-4 p-4 border border-gray-100 rounded-2xl hover:border-blue-200 hover:bg-blue-50/40 transition-all">
                <div className={`w-10 h-10 bg-${r.color}-50 rounded-xl flex items-center justify-center`}>
                  <r.icon className={`w-4 h-4 text-${r.color}-500`} size={18} />
                </div>
                <div className="flex-1">
                  <p className="font-semibold text-gray-900">{r.title}</p>
                  <p className="text-xs text-gray-400">{r.desc}</p>
                </div>
                <ArrowRight size={16} className="text-gray-300 group-hover:text-blue-400 transition-colors" />
              </Link>
            ))}
          </div>
        </div>

        {byCategory.length > 0 && (
          <div className="card">
            <h3 className="font-bold text-gray-900 mb-4">Products by Category</h3>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={byCategory}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Bar dataKey="count" fill="#3b82f6" radius={[4, 4, 0, 0]} name="Products" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      {pieData.length > 0 && (
        <div className="card">
          <h3 className="font-bold text-gray-900 mb-4">Category Distribution</h3>
          <div className="flex items-center gap-8">
            {/* Donut chart with center label */}
            <div className="relative flex-shrink-0" style={{ width: 200, height: 200 }}>
              <PieChart width={200} height={200}>
                <Pie
                  data={pieData}
                  cx={100} cy={100}
                  innerRadius={55} outerRadius={90}
                  dataKey="count"
                  onMouseEnter={onPieEnter}
                  strokeWidth={2}
                >
                  {pieData.map((_, idx) => (
                    <Cell
                      key={idx}
                      fill={COLORS[idx % COLORS.length]}
                      opacity={activeIdx === idx ? 1 : 0.75}
                    />
                  ))}
                </Pie>
                <Tooltip formatter={(v: unknown) => [`${Number(v)} products`]} />
              </PieChart>
              {/* Center label overlay */}
              <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                <span className="text-lg font-bold text-gray-800 leading-tight">
                  {pieData[activeIdx]?.count ?? ''}
                </span>
                <span className="text-[10px] text-gray-500 font-medium text-center leading-tight px-2">
                  products
                </span>
                <span
                  className="text-[10px] font-semibold text-center leading-tight px-3 mt-0.5"
                  style={{ color: COLORS[activeIdx % COLORS.length] }}
                >
                  {pieData[activeIdx]?.name ?? ''}
                </span>
              </div>
            </div>
            <div className="space-y-2">
              {pieData.map((item, idx) => (
                <div key={item.name} className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: COLORS[idx % COLORS.length] }} />
                  <span className="text-sm text-gray-700">{item.name}</span>
                  <span className="text-xs text-gray-400 ml-auto font-medium">{item.count}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
