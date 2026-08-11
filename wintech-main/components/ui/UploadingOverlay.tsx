'use client';

import { Loader2 } from 'lucide-react';

interface UploadingOverlayProps {
  show: boolean;
  count?: number;
  label?: string;
}

export default function UploadingOverlay({ show, count, label }: UploadingOverlayProps) {
  if (!show) return null;
  return (
    <div className="absolute inset-0 z-20 flex flex-col items-center justify-center gap-2 bg-white/85 dark:bg-gray-900/85 backdrop-blur-sm rounded-xl pointer-events-none">
      <Loader2 className="w-7 h-7 animate-spin text-blue-600" />
      <p className="text-sm font-semibold text-gray-700 dark:text-gray-200">
        {label || 'আপলোড হচ্ছে...'}
        {typeof count === 'number' && count > 1 ? ` (${count})` : ''}
      </p>
      <p className="text-xs text-gray-500 dark:text-gray-400">একটু অপেক্ষা করুন</p>
    </div>
  );
}
