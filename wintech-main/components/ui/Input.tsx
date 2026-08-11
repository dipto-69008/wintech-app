'use client';

import { forwardRef, InputHTMLAttributes, TextareaHTMLAttributes, SelectHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

const baseField =
  'w-full bg-white border border-slate-300 rounded-lg px-3.5 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-[0_1px_2px_rgba(15,23,42,0.04)] focus:outline-none focus:ring-4 focus:ring-blue-500/15 focus:border-blue-500 hover:border-slate-400 transition-all disabled:bg-slate-50 disabled:cursor-not-allowed disabled:hover:border-slate-300';

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...p }, ref) => <input ref={ref} className={cn(baseField, 'h-10', className)} {...p} />
);
Input.displayName = 'Input';

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  ({ className, ...p }, ref) => <textarea ref={ref} className={cn(baseField, 'min-h-[88px] py-2.5', className)} {...p} />
);
Textarea.displayName = 'Textarea';

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, children, style, ...p }, ref) => (
    <select
      ref={ref}
      className={cn(baseField, 'h-10 pr-9 cursor-pointer appearance-none bg-no-repeat bg-[right_0.7rem_center]', className)}
      style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2364748b' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E")`, ...style }}
      {...p}
    >
      {children}
    </select>
  )
);
Select.displayName = 'Select';

export function Field({
  label,
  required,
  error,
  hint,
  children,
  className,
}: {
  label?: string;
  required?: boolean;
  error?: string;
  hint?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn('space-y-1.5', className)}>
      {label && (
        <label className="text-xs font-semibold text-slate-700 flex items-center gap-1 uppercase tracking-wide">
          {label}
          {required && <span className="text-red-500">*</span>}
        </label>
      )}
      {children}
      {hint && !error && <p className="text-xs text-slate-500">{hint}</p>}
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  );
}
