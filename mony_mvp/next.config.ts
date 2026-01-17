import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  // Suppress HMR-related console warnings in development
  onDemandEntries: {
    maxInactiveAge: 25 * 1000,
    pagesBufferLength: 2,
  },
  // Enable standalone output for Docker deployment
  output: 'standalone',
};

export default nextConfig;
