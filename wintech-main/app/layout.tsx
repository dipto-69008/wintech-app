import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import Providers from './providers';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
  weight: ['300', '400', '500', '600', '700', '800'],
});

export const metadata: Metadata = {
  title: 'Wintech Agro BD - ERP System',
  description: 'Enterprise Resource Planning system for Wintech Agro BD — Fish Import & Distribution',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <body className={`${inter.className} bg-slate-50 text-gray-900 antialiased dark:bg-gray-900 dark:text-gray-100`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
