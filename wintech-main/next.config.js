/** @type {import('next').NextConfig} */
const nextConfig = {
  compress: true,
  poweredByHeader: false,
  reactStrictMode: false,
  serverExternalPackages: ['pdfkit', 'mongoose', 'xlsx'],
  outputFileTracingIncludes: {},
  images: {
    remotePatterns: [{ protocol: 'https', hostname: '**' }],
  },
  allowedDevOrigins: ['*.sisko.replit.dev', '*.replit.dev', '*.repl.co'],
  async headers() {
    const noStore = [{ key: 'Cache-Control', value: 'no-store, max-age=0' }];
    return [
      { source: '/api/:path*', headers: noStore },
      { source: '/dashboard/:path*', headers: noStore },
    ];
  },
  experimental: {
    serverActions: {
      bodySizeLimit: '50mb',
      allowedOrigins: ['*'],
    },
  },
};

module.exports = nextConfig;
