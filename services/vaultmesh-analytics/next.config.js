/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  swcMinify: true,
  env: {
    PSI_FIELD_URL: process.env.PSI_FIELD_URL || 'http://localhost:8000',
    AURORA_ROUTER_URL: process.env.AURORA_ROUTER_URL || 'http://localhost:8080',
  },
  async rewrites() {
    return [
      {
        source: '/api/psi-field/:path*',
        destination: `${process.env.PSI_FIELD_URL || 'http://localhost:8000'}/:path*`,
      },
      {
        source: '/api/aurora-router/:path*',
        destination: `${process.env.AURORA_ROUTER_URL || 'http://localhost:8080'}/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
