'use client';

import { forwardRef, ButtonHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

type Variant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger' | 'success';
type Size = 'sm' | 'md' | 'lg' | 'icon';

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
}

const variants: Record<Variant, string> = {
  primary:
    'bg-gradient-to-b from-blue-600 to-blue-700 text-white hover:from-blue-500 hover:to-blue-600 shadow-[0_1px_2px_rgba(0,0,0,0.08),inset_0_1px_0_rgba(255,255,255,0.2)] hover:shadow-[0_4px_12px_rgba(37,99,235,0.35)] active:scale-[.98]',
  secondary:
    'bg-slate-100 text-slate-900 hover:bg-slate-200 active:scale-[.98]',
  outline:
    'border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 hover:border-slate-400 shadow-[0_1px_2px_rgba(0,0,0,0.04)] active:scale-[.98]',
  ghost:
    'text-slate-700 hover:bg-slate-100 active:scale-[.98]',
  danger:
    'bg-gradient-to-b from-red-600 to-red-700 text-white hover:from-red-500 hover:to-red-600 shadow-[0_1px_2px_rgba(0,0,0,0.08),inset_0_1px_0_rgba(255,255,255,0.2)] hover:shadow-[0_4px_12px_rgba(220,38,38,0.35)] active:scale-[.98]',
  success:
    'bg-gradient-to-b from-emerald-600 to-emerald-700 text-white hover:from-emerald-500 hover:to-emerald-600 shadow-[0_1px_2px_rgba(0,0,0,0.08),inset_0_1px_0_rgba(255,255,255,0.2)] hover:shadow-[0_4px_12px_rgba(5,150,105,0.35)] active:scale-[.98]',
};

const sizes: Record<Size, string> = {
  sm: 'h-8 px-3 text-xs rounded-md',
  md: 'h-10 px-4 text-sm rounded-lg',
  lg: 'h-12 px-6 text-base rounded-lg',
  icon: 'h-9 w-9 rounded-md',
};

export const Button = forwardRef<HTMLButtonElement, Props>(
  ({ className, variant = 'primary', size = 'md', loading, disabled, children, ...rest }, ref) => {
    return (
      <button
        ref={ref}
        disabled={loading || disabled}
        className={cn(
          'inline-flex items-center justify-center gap-2 font-medium transition-all duration-150 disabled:opacity-50 disabled:cursor-not-allowed disabled:active:scale-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/40 focus-visible:ring-offset-1',
          variants[variant],
          sizes[size],
          className
        )}
        {...rest}
      >
        {loading && (
          <span className="inline-block w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
        )}
        {children}
      </button>
    );
  }
);
Button.displayName = 'Button';
