'use client';
import { useRef, useState, useCallback, useEffect } from 'react';
import { UploadCloud, X, Loader2, ImageIcon } from 'lucide-react';
import toast from 'react-hot-toast';

interface ImageUploadProps {
  value?: string;        // Cloudinary URL OR legacy filename — both handled
  onChange: (url: string) => void;
  disabled?: boolean;
}

/** Resolve legacy filenames to a displayable URL without breaking full URLs */
function resolvePreview(v?: string) {
  if (!v) return '';
  return v.startsWith('http') ? v : `/uploads/${v}`;
}

export function ImageUpload({ value, onChange, disabled }: ImageUploadProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);

  const upload = useCallback(async (file: File) => {
    if (!file.type.startsWith('image/')) { toast.error('Only image files allowed'); return; }
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append('file', file);
      const res = await fetch('/api/upload', { method: 'POST', body: fd });
      if (!res.ok) { const e = await res.json(); throw new Error(e.error || 'Upload failed'); }
      const { url } = await res.json();
      onChange(url);
      toast.success('Image uploaded');
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Upload failed');
    } finally {
      setUploading(false);
    }
  }, [onChange]);

  // Global paste listener
  useEffect(() => {
    const onPaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;
      for (const item of Array.from(items)) {
        if (item.type.startsWith('image/')) {
          const file = item.getAsFile();
          if (file) upload(file);
          break;
        }
      }
    };
    document.addEventListener('paste', onPaste);
    return () => document.removeEventListener('paste', onPaste);
  }, [upload]);

  const onDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) upload(file);
  };

  const onFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) upload(file);
    e.target.value = '';
  };

  const clear = (ev: React.MouseEvent) => {
    ev.stopPropagation();
    onChange('');
  };

  if (value) {
    return (
      <div className="relative inline-block">
        <img
          src={resolvePreview(value)}
          alt="Product"
          className="h-32 w-32 object-cover rounded-xl border border-gray-200 dark:border-gray-700"
        />
        {!disabled && (
          <button
            type="button"
            onClick={clear}
            className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center shadow hover:bg-red-600 transition-colors"
          >
            <X size={11} />
          </button>
        )}
        {!disabled && (
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            className="absolute bottom-1 right-1 text-[10px] bg-black/50 text-white rounded px-1.5 py-0.5 hover:bg-black/70"
          >
            Change
          </button>
        )}
        <input ref={inputRef} type="file" accept="image/*" className="hidden" onChange={onFileChange} />
      </div>
    );
  }

  return (
    <div
      onClick={() => !disabled && inputRef.current?.click()}
      onDragOver={e => { e.preventDefault(); setDragging(true); }}
      onDragLeave={() => setDragging(false)}
      onDrop={onDrop}
      className={`
        col-span-2 flex flex-col items-center justify-center gap-2
        border-2 border-dashed rounded-xl px-6 py-8 cursor-pointer
        transition-all select-none
        ${dragging ? 'border-blue-400 bg-blue-50 dark:bg-blue-900/20' : 'border-gray-200 dark:border-gray-700 hover:border-blue-300 hover:bg-gray-50 dark:hover:bg-gray-800/50'}
        ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
      `}
    >
      {uploading ? (
        <>
          <Loader2 size={28} className="text-blue-500 animate-spin" />
          <p className="text-sm text-gray-500">Uploading…</p>
        </>
      ) : (
        <>
          <div className="w-12 h-12 bg-blue-50 dark:bg-blue-900/30 rounded-full flex items-center justify-center">
            {dragging ? <ImageIcon size={22} className="text-blue-500" /> : <UploadCloud size={22} className="text-blue-400" />}
          </div>
          <div className="text-center">
            <p className="text-sm font-medium text-gray-700 dark:text-gray-200">
              {dragging ? 'Drop image here' : 'Click, drag & drop, or paste image'}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">PNG, JPG, WEBP up to 10MB</p>
          </div>
        </>
      )}
      <input ref={inputRef} type="file" accept="image/*" className="hidden" onChange={onFileChange} disabled={disabled} />
    </div>
  );
}
