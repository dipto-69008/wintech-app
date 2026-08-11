'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import Link from 'next/link';
import { Bell, Check, Trash2, X, Volume2, VolumeX } from 'lucide-react';
import toast from 'react-hot-toast';
import { cn } from '@/lib/utils';

type Notif = {
  _id: string;
  type: string;
  title: string;
  message: string;
  link?: string;
  read: boolean;
  createdAt: string;
  createdBy?: { _id: string; name: string; avatar?: string } | null;
};

const FALLBACK_POLL_MS = 60000;
const NOTIF_KEY = 'crm_notif_enabled';
const SSE_RECONNECT_MS = 5000;

function timeAgo(d: string) {
  const ms = Date.now() - new Date(d).getTime();
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const day = Math.floor(h / 24);
  return `${day}d ago`;
}

let _audioCtx: AudioContext | null = null;

function getAudioCtx(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  try {
    if (!_audioCtx || _audioCtx.state === 'closed') {
      _audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    return _audioCtx;
  } catch { return null; }
}

async function playNotifSound() {
  try {
    const ctx = getAudioCtx();
    if (!ctx) return;
    if (ctx.state === 'suspended') await ctx.resume();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(660, ctx.currentTime + 0.15);
    gain.gain.setValueAtTime(0.35, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.4);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.4);
  } catch {}
}

function showBrowserNotif(n: Notif) {
  if (typeof window === 'undefined' || !('Notification' in window)) return;
  if (localStorage.getItem(NOTIF_KEY) !== '1') return;
  if (Notification.permission !== 'granted') return;
  playNotifSound();
  try { new Notification(n.title, { body: n.message || '', icon: '/favicon.ico' }); } catch {}
}

export function NotificationBell() {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<Notif[]>([]);
  const [unread, setUnread] = useState(0);
  const [loading, setLoading] = useState(false);
  const [notifEnabled, setNotifEnabled] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const seenIds = useRef<Set<string>>(new Set());
  const esRef = useRef<EventSource | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (typeof window === 'undefined' || !('Notification' in window)) return;
    const stored = localStorage.getItem(NOTIF_KEY);
    if (stored === '1' && Notification.permission === 'granted') {
      setNotifEnabled(true);
    } else if (stored === '1' && Notification.permission !== 'granted') {
      localStorage.removeItem(NOTIF_KEY);
    }
  }, []);

  const load = useCallback(async () => {
    try {
      const res = await fetch('/api/notifications?limit=20');
      const data: { items: Notif[]; unreadCount: number } = await res.json();
      const incoming = data.items || [];
      seenIds.current = new Set(incoming.map((n) => n._id));
      setItems(incoming);
      setUnread(data.unreadCount || 0);
    } catch {}
  }, []);

  const applyIncoming = useCallback((newNotifs: Notif[], unreadCount: number) => {
    for (const n of newNotifs) {
      if (!seenIds.current.has(n._id) && !n.read) {
        showBrowserNotif(n);
      }
      seenIds.current.add(n._id);
    }
    setItems((prev) => {
      const existingIds = new Set(prev.map((x) => x._id));
      const toAdd = newNotifs.filter((n) => !existingIds.has(n._id));
      if (toAdd.length === 0) return prev;
      return [...toAdd, ...prev].slice(0, 20);
    });
    setUnread(unreadCount);
  }, []);

  const connectSSE = useCallback(() => {
    if (typeof window === 'undefined') return;
    if (esRef.current) {
      esRef.current.close();
      esRef.current = null;
    }

    const es = new EventSource('/api/notifications/stream');
    esRef.current = es;

    es.addEventListener('notification', (e) => {
      try {
        const payload = JSON.parse(e.data) as { items: Notif[]; unreadCount: number };
        applyIncoming(payload.items, payload.unreadCount);
      } catch {}
    });

    es.onerror = () => {
      es.close();
      esRef.current = null;
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      reconnectTimer.current = setTimeout(connectSSE, SSE_RECONNECT_MS);
    };
  }, [applyIncoming]);

  useEffect(() => {
    load();
    connectSSE();

    const fallback = setInterval(load, FALLBACK_POLL_MS);

    return () => {
      clearInterval(fallback);
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      if (esRef.current) { esRef.current.close(); esRef.current = null; }
    };
  }, [load, connectSSE]);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  async function toggleNotifications() {
    if (notifEnabled) {
      localStorage.removeItem(NOTIF_KEY);
      setNotifEnabled(false);
      toast.success('Sound notifications turned off');
      return;
    }

    if (typeof window === 'undefined' || !('Notification' in window)) {
      toast.error('Your browser does not support notifications');
      return;
    }

    if (Notification.permission === 'denied') {
      toast.error('Notifications are blocked. Please allow them in your browser settings and try again.');
      return;
    }

    const perm: NotificationPermission =
      Notification.permission === 'granted'
        ? 'granted'
        : await Notification.requestPermission();

    if (perm === 'granted') {
      localStorage.setItem(NOTIF_KEY, '1');
      setNotifEnabled(true);
      toast.success('Sound notifications enabled!');
      getAudioCtx();
      playNotifSound();
    } else {
      toast.error('Notification permission denied');
    }
  }

  const markOne = async (id: string) => {
    try {
      await fetch(`/api/notifications/${id}`, { method: 'PATCH' });
      setItems((xs) => xs.map((x) => x._id === id ? { ...x, read: true } : x));
      setUnread((u) => Math.max(0, u - 1));
    } catch {}
  };

  const markAll = async () => {
    setLoading(true);
    try {
      await fetch('/api/notifications', { method: 'PATCH' });
      setItems((xs) => xs.map((x) => ({ ...x, read: true })));
      setUnread(0);
      toast.success('All marked read');
    } catch (e: any) { toast.error(e.message); }
    finally { setLoading(false); }
  };

  const removeOne = async (id: string) => {
    try {
      await fetch(`/api/notifications/${id}`, { method: 'DELETE' });
      setItems((xs) => xs.filter((x) => x._id !== id));
    } catch {}
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((o) => !o)}
        className="relative p-2 rounded-lg hover:bg-slate-100 text-slate-600 transition"
        aria-label="Notifications"
      >
        <Bell className="w-5 h-5" />
        {unread > 0 && (
          <span className="absolute top-1 right-1 min-w-[18px] h-[18px] px-1 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
            {unread > 99 ? '99+' : unread}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-[360px] max-w-[calc(100vw-2rem)] bg-white border border-slate-200 rounded-xl shadow-2xl z-50 overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-100 flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-slate-900">Notifications</p>
              <p className="text-xs text-slate-500">{unread > 0 ? `${unread} unread` : 'All caught up'}</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={toggleNotifications}
                title={notifEnabled ? 'Turn off sound notifications' : 'Turn on sound notifications'}
                className={cn(
                  'flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium border transition',
                  notifEnabled
                    ? 'bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-100'
                    : 'bg-slate-50 text-slate-500 border-slate-200 hover:border-blue-300 hover:text-blue-600'
                )}
              >
                {notifEnabled
                  ? <><Volume2 className="w-3.5 h-3.5" /> On</>
                  : <><VolumeX className="w-3.5 h-3.5" /> Off</>
                }
              </button>
              {unread > 0 && (
                <button
                  onClick={markAll}
                  disabled={loading}
                  className="text-xs font-medium text-blue-600 hover:text-blue-700 disabled:opacity-50"
                >
                  Mark all read
                </button>
              )}
            </div>
          </div>
          <div className="max-h-[420px] overflow-y-auto">
            {items.length === 0 ? (
              <div className="px-4 py-10 text-center">
                <Bell className="w-8 h-8 mx-auto text-slate-300 mb-2" />
                <p className="text-sm text-slate-500">No notifications yet</p>
              </div>
            ) : (
              items.map((n) => (
                <div
                  key={n._id}
                  className={cn(
                    'px-4 py-3 border-b border-slate-50 hover:bg-slate-50/70 transition flex gap-3 group',
                    !n.read && 'bg-blue-50/40'
                  )}
                >
                  <div className={cn('w-2 h-2 rounded-full mt-2 flex-shrink-0', n.read ? 'bg-slate-300' : 'bg-blue-500')} />
                  <div className="flex-1 min-w-0">
                    {n.link ? (
                      <Link
                        href={n.link}
                        onClick={() => { markOne(n._id); setOpen(false); }}
                        className="block"
                      >
                        <p className="text-sm font-semibold text-slate-900 truncate">{n.title}</p>
                        <p className="text-xs text-slate-600 line-clamp-2 mt-0.5">{n.message}</p>
                      </Link>
                    ) : (
                      <div onClick={() => markOne(n._id)} className="cursor-pointer">
                        <p className="text-sm font-semibold text-slate-900 truncate">{n.title}</p>
                        <p className="text-xs text-slate-600 line-clamp-2 mt-0.5">{n.message}</p>
                      </div>
                    )}
                    <p className="text-[10px] text-slate-400 mt-1">{timeAgo(n.createdAt)}</p>
                  </div>
                  <div className="flex flex-col gap-1 opacity-0 group-hover:opacity-100 transition">
                    {!n.read && (
                      <button onClick={() => markOne(n._id)} className="p-1 rounded hover:bg-slate-200 text-slate-500" title="Mark read">
                        <Check className="w-3.5 h-3.5" />
                      </button>
                    )}
                    <button onClick={() => removeOne(n._id)} className="p-1 rounded hover:bg-red-100 text-red-500" title="Delete">
                      <X className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
