import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  // Suppress HMR-related console warnings in development
  onDemandEntries: {
    maxInactiveAge: 25 * 1000,
    pagesBufferLength: 2,
  },
  // Note: output: 'standalone' is for Docker/self-hosted deployments
  // Cloudflare Pages uses its own Next.js runtime, so we don't need standalone
  // Uncomment the line below if deploying to Docker/Coolify
  // output: 'standalone',
};

export default nextConfig;
