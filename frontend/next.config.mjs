/** @type {import('next').NextConfig} */
const nextConfig = {
  agentRules: false,
  reactCompiler: true,
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "shared.fastly.steamstatic.com" },
      { protocol: "https", hostname: "imgcdn1.nexarda.com" },
      { protocol: "https", hostname: "assets.nintendo.com" },
      { protocol: "https", hostname: "en.wikipedia.org" },
      { protocol: "https", hostname: "upload.wikimedia.org" },
      { protocol: "https", hostname: "media-rockstargames-com.akamaized.net" },
      { protocol: "https", hostname: "commons.wikimedia.org" },
      { protocol: "https", hostname: "pisces.bbystatic.com" },
      { protocol: "https", hostname: "images.launchbox-app.com" },
      { protocol: "https", hostname: "cdn2.steamgriddb.com" },
      { protocol: "https", hostname: "wallpaperset.com" },
      { protocol: "https", hostname: "www.rockstargames.com" },
    ],
  },
};

export default nextConfig;
