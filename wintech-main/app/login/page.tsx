'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { Lock, Mail, Eye, EyeOff, ArrowRight, Zap } from 'lucide-react';
import { useAuthStore } from '@/lib/store';
import toast from 'react-hot-toast';

const DEMO_USERS = [
  { email: 'admin@wintechagro.com', password: 'admin123', name: 'Admin User', role: 'admin' as const, id: 'U001' },
  { email: 'manager@wintechagro.com', password: 'manager123', name: 'Sarah Ahmed', role: 'manager' as const, id: 'U002' },
  { email: 'employee@wintechagro.com', password: 'emp123', name: 'Rahim Khan', role: 'employee' as const, id: 'U003' },
];

const roleColors: Record<string, string> = {
  admin: 'bg-violet-100 text-violet-700',
  manager: 'bg-emerald-100 text-emerald-700',
  employee: 'bg-amber-100 text-amber-700',
};

export default function LoginPage() {
  const [email, setEmail] = useState('admin@wintechagro.com');
  const [password, setPassword] = useState('admin123');
  const [showPass, setShowPass] = useState(false);
  const [loading, setLoading] = useState(false);
  const { login } = useAuthStore();
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      // 1. Try employee database first
      const res = await fetch('/api/auth/employee', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      if (res.ok) {
        const emp = await res.json();
        const role = (emp.role === 'admin' || emp.role === 'manager') ? emp.role : 'employee';
        login({ id: emp.id, name: emp.name, email: emp.email, role });
        toast.success(`Welcome back, ${emp.name}!`);
        router.push('/dashboard');
        return;
      }

      // 2. Fall back to demo users
      const demo = DEMO_USERS.find((u) => u.email === email && u.password === password);
      if (demo) {
        login({ id: demo.id, name: demo.name, email: demo.email, role: demo.role });
        toast.success(`Welcome back, ${demo.name}!`);
        router.push('/dashboard');
        return;
      }

      toast.error('Invalid email or password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex">
      {/* Left panel */}
      <div className="hidden lg:flex w-[45%] bg-gradient-to-br from-[#0d1526] via-[#0f2545] to-[#0d1526] flex-col justify-between p-12 relative overflow-hidden">
        <div className="absolute inset-0 overflow-hidden">
          <div className="absolute -top-32 -right-32 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl" />
          <div className="absolute -bottom-32 -left-32 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-blue-600/5 rounded-full blur-2xl" />
        </div>
        <div className="absolute inset-0 opacity-[0.03]"
          style={{ backgroundImage: 'linear-gradient(rgba(255,255,255,0.8) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.8) 1px, transparent 1px)', backgroundSize: '40px 40px' }} />

        {/* Logo */}
        <div className="relative">
          <div className="flex items-center gap-3 mb-8">
            <div className="w-12 h-12 rounded-2xl overflow-hidden shadow-lg shadow-green-900/40">
              <Image src="/wintech.jpeg" alt="Wintech Logo" width={48} height={48} className="w-full h-full object-cover" />
            </div>
            <div>
              <span className="text-white font-bold text-xl tracking-tight block leading-tight">WINTECH AGRO BD</span>
              <span className="text-emerald-400/80 text-[11px] font-medium">Fish Import & Distribution</span>
            </div>
          </div>

          <h2 className="text-4xl font-bold text-white leading-tight mb-4">
            Manage your entire<br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-green-300">business in one place</span>
          </h2>
          <p className="text-gray-400 text-sm leading-relaxed max-w-sm">
            Import, depot, distribution, HR, accounting, and more — unified in a single powerful ERP platform built for Wintech Agro BD.
          </p>
        </div>

        {/* Feature list */}
        <div className="relative space-y-3">
          {[
            { label: 'Fish Import from India', color: 'bg-emerald-500' },
            { label: 'Camila Depot Management', color: 'bg-teal-500' },
            { label: 'Branch Distribution Control', color: 'bg-blue-500' },
            { label: 'HR, Payroll & Attendance', color: 'bg-purple-500' },
            { label: 'Accounting & Budgeting', color: 'bg-amber-500' },
            { label: 'Sales & Invoice Management', color: 'bg-rose-500' },
          ].map(f => (
            <div key={f.label} className="flex items-center gap-3">
              <span className={`w-1.5 h-1.5 rounded-full ${f.color} flex-shrink-0`} />
              <span className="text-gray-400 text-xs font-medium">{f.label}</span>
            </div>
          ))}
          <div className="pt-4 mt-2 border-t border-white/[0.07]">
            <p className="text-gray-600 text-[11px]">© 2025 Wintech Agro BD. All rights reserved.</p>
          </div>
        </div>
      </div>

      {/* Right panel */}
      <div className="flex-1 flex items-center justify-center bg-slate-50 px-6 py-12">
        <div className="w-full max-w-[380px]">
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-3 mb-8 justify-center">
            <div className="w-10 h-10 rounded-xl overflow-hidden shadow-lg">
              <Image src="/wintech.jpeg" alt="Wintech Logo" width={40} height={40} className="w-full h-full object-cover" />
            </div>
            <div>
              <span className="text-gray-900 font-bold text-xl block leading-tight">WINTECH AGRO BD</span>
              <span className="text-gray-500 text-[11px]">Fish Import & Distribution</span>
            </div>
          </div>

          <div className="mb-8">
            <h1 className="text-2xl font-bold text-gray-900">Sign in</h1>
            <p className="text-gray-500 text-sm mt-1.5 font-medium">Enter your credentials to access your workspace</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="form-label">Email Address</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 w-4 h-4 pointer-events-none" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="form-input pl-10"
                  placeholder="you@wintechagro.com"
                  autoComplete="email"
                  required
                />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="form-label mb-0">Password</label>
                <button type="button" className="text-[11px] text-blue-600 hover:text-blue-800 font-semibold">Forgot password?</button>
              </div>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 w-4 h-4 pointer-events-none" />
                <input
                  type={showPass ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="form-input pl-10 pr-10"
                  placeholder="••••••••"
                  autoComplete="current-password"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPass(!showPass)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                >
                  {showPass ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full btn-primary py-3 justify-center text-sm font-bold mt-2 gap-2"
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
                  Signing in...
                </>
              ) : (
                <>
                  Sign In
                  <ArrowRight size={15} />
                </>
              )}
            </button>
          </form>

          {/* Demo accounts */}
          <div className="mt-6 rounded-2xl border border-dashed border-gray-200 bg-white p-4">
            <div className="flex items-center gap-2 mb-3">
              <Zap size={13} className="text-amber-500" />
              <p className="text-xs font-bold text-gray-600 uppercase tracking-wide">Quick Demo Login</p>
            </div>
            <div className="space-y-2">
              {DEMO_USERS.map((u) => (
                <button
                  key={u.email}
                  onClick={() => { setEmail(u.email); setPassword(u.password); }}
                  className="w-full flex items-center gap-3 px-3 py-2 rounded-xl hover:bg-gray-50 transition-colors text-left group border border-transparent hover:border-gray-100"
                >
                  <div className="w-7 h-7 rounded-full bg-gradient-to-br from-gray-200 to-gray-300 flex items-center justify-center text-gray-600 text-xs font-bold flex-shrink-0">
                    {u.name.charAt(0)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold text-gray-800 leading-tight">{u.name}</p>
                    <p className="text-[10px] text-gray-400">{u.email}</p>
                  </div>
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-md ${roleColors[u.role]}`}>
                    {u.role}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
