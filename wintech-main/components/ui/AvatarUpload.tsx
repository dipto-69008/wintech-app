'use client';

import Image from 'next/image';
import { useRef, useState } from 'react';
import { Upload, X, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { initials } from '@/lib/utils';

type Props = {
  value?: string;
  onChange: (url: string) => void;
  name?: string;
  folder?: string;
  size?: number;
  className?: string;
};

export function AvatarUpload({ value, onChange, name, folder = 'crm-pro/avatars', size = 96, className }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const dropRef = useRef<HTMLDivElement>(null);
  const [uploading, setUploading] = useState(false);
  const [dragOver, setDragOver] = useState(false);

  async function uploadFile(file: File) {
    if (!file.type.startsWith('image/')) {
      toast.error('Please select an image file');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      toast.error('Image must be under 5MB');
      return;
    }
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append('file', file);
      fd.append('folder', folder);
      const res = await fetch('/api/upload', { method: 'POST', body: fd });
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || 'Upload failed');
      const url = json.data?.url;
      if (!url) throw new Error('Upload returned no URL');
      onChange(url);
      toast.success('Image uploaded');
    } catch (e: any) {
      toast.error(e.message || 'Upload failed');
    } finally {
      setUploading(false);
    }
  }

  function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (f) uploadFile(f);
    e.target.value = '';
  }

  function onDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragOver(false);
    const f = e.dataTransfer.files?.[0];
    if (f) uploadFile(f);
  }

  function onPaste(e: React.ClipboardEvent) {
    const items = e.clipboardData?.items;
    if (!items) return;
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (it.kind === 'file' && it.type.startsWith('image/')) {
        const f = it.getAsFile();
        if (f) {
          e.preventDefault();
          uploadFile(f);
          return;
        }
      }
    }
  }

  function clear(e?: React.MouseEvent) {
    e?.stopPropagation();
    onChange('');
  }

  const text = initials(name);

  return (
    <div className={className}>
      <div
        ref={dropRef}
        tabIndex={0}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={onDrop}
        onPaste={onPaste}
        className={[
          'relative flex items-center gap-4 rounded-xl border-2 border-dashed p-4 cursor-pointer transition outline-none',
          dragOver ? 'border-blue-500 bg-blue-50' : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50',
          'focus:ring-2 focus:ring-blue-200',
        ].join(' ')}
        role="button"
        aria-label="Upload avatar — click, drag and drop, or paste"
      >
        <div
          className="relative inline-flex items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-white font-semibold overflow-hidden ring-2 ring-white shadow-sm flex-shrink-0"
          style={{ width: size, height: size, fontSize: size * 0.36 }}
        >
          {value ? (
            <Image
              src={value}
              alt={name || 'avatar'}
              fill
              sizes={`${size}px`}
              className="object-cover"
              onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
            />
          ) : text}
          {uploading && (
            <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
              <Loader2 className="w-6 h-6 text-white animate-spin" />
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 text-sm font-medium text-slate-700">
            <Upload className="w-4 h-4 text-slate-400" />
            {value ? 'Replace photo' : 'Upload photo'}
          </div>
          <p className="text-xs text-slate-500 mt-1">
            Click to browse, drag &amp; drop, or paste an image (Ctrl/Cmd + V).
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">PNG, JPG, WebP or GIF · up to 5MB</p>
        </div>

        <div className="flex items-center gap-1.5 flex-shrink-0" onClick={(e) => e.stopPropagation()}>
          {value && (
            <button
              type="button"
              onClick={clear}
              className="p-2 rounded-lg text-red-500 hover:bg-red-50"
              title="Remove"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        <input
          ref={inputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp,image/gif"
          onChange={onFileChange}
          className="hidden"
        />
      </div>
    </div>
  );
}
