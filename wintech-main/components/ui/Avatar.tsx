import Image from 'next/image';
import { cn, initials } from '@/lib/utils';

export function Avatar({
  name,
  src,
  size = 32,
  className,
}: {
  name?: string;
  src?: string;
  size?: number;
  className?: string;
}) {
  const text = initials(name);
  return (
    <div
      className={cn(
        'inline-flex items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-white font-semibold overflow-hidden ring-2 ring-white',
        className
      )}
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      {src ? <Image src={src} alt={name || 'user'} width={size} height={size} className="object-cover" /> : text}
    </div>
  );
}

export function AvatarGroup({ users, max = 3, size = 28 }: { users: { name?: string; avatar?: string }[]; max?: number; size?: number }) {
  const visible = (users || []).slice(0, max);
  const overflow = (users || []).length - visible.length;
  return (
    <div className="flex -space-x-2">
      {visible.map((u, i) => (
        <Avatar key={i} name={u?.name} src={u?.avatar} size={size} />
      ))}
      {overflow > 0 && (
        <div
          className="inline-flex items-center justify-center rounded-full bg-slate-200 text-slate-700 ring-2 ring-white text-xs font-semibold"
          style={{ width: size, height: size }}
        >
          +{overflow}
        </div>
      )}
    </div>
  );
}
