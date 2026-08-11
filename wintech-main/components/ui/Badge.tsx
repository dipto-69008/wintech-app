import { cn } from '@/lib/utils';

type Color = 'default' | 'blue' | 'green' | 'orange' | 'red' | 'purple' | 'pink' | 'indigo' | 'amber' | 'cyan' | 'slate' | 'teal' | 'rose';

const COLORS: Record<Color, string> = {
  default: 'bg-slate-100 text-slate-700 ring-slate-200',
  blue: 'bg-blue-50 text-blue-700 ring-blue-200',
  green: 'bg-emerald-50 text-emerald-700 ring-emerald-200',
  orange: 'bg-orange-50 text-orange-700 ring-orange-200',
  red: 'bg-red-50 text-red-700 ring-red-200',
  purple: 'bg-purple-50 text-purple-700 ring-purple-200',
  pink: 'bg-pink-50 text-pink-700 ring-pink-200',
  indigo: 'bg-indigo-50 text-indigo-700 ring-indigo-200',
  amber: 'bg-amber-50 text-amber-700 ring-amber-200',
  cyan: 'bg-cyan-50 text-cyan-700 ring-cyan-200',
  slate: 'bg-slate-100 text-slate-700 ring-slate-200',
  teal: 'bg-teal-50 text-teal-700 ring-teal-200',
  rose: 'bg-rose-50 text-rose-700 ring-rose-200',
};

export const STATUS_COLORS: Record<string, Color> = {
  // Lead/deal
  new: 'blue',
  contacted: 'cyan',
  qualified: 'indigo',
  proposal: 'amber',
  negotiation: 'orange',
  won: 'green',
  lost: 'red',
  // Lead rating
  hot: 'red',
  warm: 'amber',
  lukewarm: 'orange',
  cold: 'blue',
  unqualified: 'slate',
  // Tasks/projects
  todo: 'slate',
  in_progress: 'blue',
  review: 'amber',
  done: 'green',
  blocked: 'red',
  active: 'green',
  on_hold: 'amber',
  completed: 'green',
  cancelled: 'red',
  // Invoices
  draft: 'slate',
  sent: 'blue',
  partial: 'amber',
  paid: 'green',
  overdue: 'red',
  // Tickets
  open: 'blue',
  closed: 'slate',
  // Generic
  scheduled: 'purple',
  missed: 'red',
};

export function Badge({
  color = 'default',
  children,
  className,
  size = 'md',
}: {
  color?: Color;
  children: React.ReactNode;
  className?: string;
  size?: 'sm' | 'md';
}) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 font-semibold rounded-md ring-1 ring-inset capitalize',
        size === 'sm' ? 'px-1.5 py-0.5 text-[10px]' : 'px-2 py-0.5 text-xs',
        COLORS[color],
        className
      )}
    >
      {children}
    </span>
  );
}
