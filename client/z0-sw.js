// Punycode & ancient script address resolution service worker
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // Intercept Brahmi script routes and normalize to canonical endpoint
  if (url.pathname.startsWith("/𑀮𑀺𑀧𑀺")) {
    const targetUrl = new URL("/api/v1/lipi", url.origin);
    event.respondWith(fetch(targetUrl));
    return;
  }

  event.respondWith(fetch(event.request));
});