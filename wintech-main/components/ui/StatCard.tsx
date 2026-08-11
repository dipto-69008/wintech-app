import Link from 'next/link';
import { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

export type StatColor =
  | 'blue'
  | 'green'
  | 'orange'
  | 'purple'
  | 'red'
  | 'pink'
  | 'indigo'
  | 'cyan'
  | 'amber'
  | 'slate'
  | 'teal'
  | 'rose';

const TONE: Record<StatColor, { bg: string; fg: string; ring: string }> = {
  blue: { bg: 'bg-blue-50', fg: 'text-blue-600', ring: 'ring-blue-100' },
  green: { bg: 'bg-emerald-50', fg: 'text-emerald-600', ring: 'ring-emerald-100' },
  orange: { bg: 'bg-orange-50', fg: 'text-orange-600', ring: 'ring-orange-100' },
  purple: { bg: 'bg-purple-50', fg: 'text-purple-600', ring: 'ring-purple-100' },
  red: { bg: 'bg-red-50', fg: 'text-red-600', ring: 'ring-red-100' },
  pink: { bg: 'bg-pink-50', fg: 'text-pink-600', ring: 'ring-pink-100' },
  indigo: { bg: 'bg-indigo-50', fg: 'text-indigo-600', ring: 'ring-indigo-100' },
  cyan: { bg: 'bg-cyan-50', fg: 'text-cyan-600', ring: 'ring-cyan-100' },
  amber: { bg: 'bg-amber-50', fg: 'text-amber-600', ring: 'ring-amber-100' },
  slate: { bg: 'bg-slate-100', fg: 'text-slate-600', ring: 'ring-slate-200' },
  teal: { bg: 'bg-teal-50', fg: 'text-teal-600', ring: 'ring-teal-100' },
  rose: { bg: 'bg-rose-50', fg: 'text-rose-600', ring: 'ring-rose-100' },
};

interface StatCardProps {
  label: string;
  value: string | number;
  hint?: string;
  icon: LucideIcon;
  color?: StatColor;
  trend?: { value: number; up?: boolean };
  href?: string;
}

export function StatCard({ label, value, hint, icon: Icon, color = 'blue', trend, href }: StatCardProps) {
  const t = TONE[color];
  const inner = (
    <div className={cn('tile-stat group', href && 'cursor-pointer hover:border-blue-300')}>
      <div className={cn('w-11 h-11 rounded-xl flex items-center justify-center ring-4 transition group-hover:scale-105', t.bg, t.ring)}>
        <Icon className={cn('w-5 h-5', t.fg)} />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-2xl font-bold text-slate-900 leading-tight tabular-nums">{value}</p>
        <p className="text-xs text-slate-500 mt-0.5 truncate">{label}</p>
        {hint && <p className="text-[10px] text-slate-400 mt-0.5 truncate">{hint}</p>}
        {trend && (
          <div className="mt-1 flex items-center gap-1.5 text-[10px]">
            <span className={cn('font-semibold', trend.up !== false ? 'text-emerald-600' : 'text-red-600')}>
              {trend.up !== false ? '↑' : '↓'} {Math.abs(trend.value)}%
            </span>
            <span className="text-slate-400">vs last</span>
          </div>
        )}
      </div>
    </div>
  );
  if (href) return <Link href={href} className="block">{inner}</Link>;
  return inner;
}
