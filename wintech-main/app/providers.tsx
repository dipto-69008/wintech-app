'use client';

import { ThemeProvider as NextThemesProvider } from 'next-themes';
import { ThemeProvider } from '@/components/providers/ThemeProvider';
import { Toaster } from 'react-hot-toast';

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <NextThemesProvider attribute="class" defaultTheme="light" enableSystem={false}>
      <ThemeProvider>
        {children}
      <Toaster
        position="top-right"
        toastOptions={{
          className: '!rounded-xl !shadow-lg',
          style: { padding: '12px 16px', fontSize: 14 },
          success: { iconTheme: { primary: '#16a34a', secondary: '#fff' } },
          error: { iconTheme: { primary: '#dc2626', secondary: '#fff' } },
        }}
      />
      </ThemeProvider>
    </NextThemesProvider>
  );
}
