import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  serverExternalPackages: ['pino', 'thread-stream'],
  turbopack: {},
};

export default nextConfig;
