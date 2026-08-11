'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, ShoppingCart, Truck, Users, Receipt, Package } from 'lucide-react';
import Link from 'next/link';

const ITEMS = [
  { label: 'New Sale',     href: '/sales/orders-entry', icon: ShoppingCart, color: 'text-blue-600 bg-blue-50 hover:bg-blue-100' },
  { label: 'New Purchase', href: '/purchases/new',      icon: Truck,        color: 'text-violet-600 bg-violet-50 hover:bg-violet-100' },
  { label: 'New Party',    href: '/sales/parties',      icon: Users,        color: 'text-emerald-600 bg-emerald-50 hover:bg-emerald-100' },
  { label: 'New Expense',  href: '/expenses',           icon: Receipt,      color: 'text-amber-600 bg-amber-50 hover:bg-amber-100' },
  { label: 'New Product',  href: '/inventory',          icon: Package,      color: 'text-orange-600 bg-orange-50 hover:bg-orange-100' },
];

export function QuickAdd() {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const router = useRouter();

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  return (
    <>
      {/* Desktop: inline quick-action chips */}
      <div className="hidden lg:flex items-center gap-1">
        {ITEMS.map((it) => (
          <Link
            key={it.label}
            href={it.href}
            className={`inline-flex items-center gap-1.5 h-8 px-3 rounded-lg text-xs font-semibold transition ${it.color}`}
          >
            <it.icon className="w-3.5 h-3.5" />
            {it.label}
          </Link>
        ))}
      </div>

      {/* Mobile: dropdown button */}
      <div className="relative lg:hidden" ref={ref}>
        <button
          onClick={() => setOpen((v) => !v)}
          className="hidden sm:inline-flex items-center gap-1.5 h-9 pl-3 pr-4 rounded-xl bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 shadow-sm transition"
          aria-label="Quick add"
        >
          <Plus className="w-4 h-4" /> New
        </button>
        <button
          onClick={() => setOpen((v) => !v)}
          className="sm:hidden p-2 rounded-xl bg-blue-600 text-white"
          aria-label="Quick add"
        >
          <Plus className="w-5 h-5" />
        </button>

        {open && (
          <div className="absolute right-0 mt-2 w-60 bg-white dark:bg-gray-800 border border-slate-200 dark:border-gray-700 rounded-2xl shadow-xl pt-3 pb-3 animate-slide-down z-40">
            <p className="px-4 pb-2 text-[10px] font-bold tracking-widest uppercase text-slate-400">Quick Create</p>
            <div className="grid grid-cols-2 gap-1 px-2">
              {ITEMS.map((it) => (
                <button
                  key={it.label}
                  onClick={() => { setOpen(false); router.push(it.href); }}
                  className="flex flex-col items-center gap-2 py-3 px-2 rounded-xl hover:bg-slate-50 dark:hover:bg-gray-700 transition text-center"
                >
                  <span className={`w-10 h-10 rounded-xl flex items-center justify-center ${it.color}`}>
                    <it.icon className="w-5 h-5" />
                  </span>
                  <span className="text-xs font-medium text-slate-700 dark:text-gray-200 leading-tight">{it.label}</span>
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </>
  );
}
