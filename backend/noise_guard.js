/**
 * حجب طلبات الضوضاء (بوتات / ماسحات) قبل أي عمل على Neon.
 * لا يلمس قاعدة البيانات.
 */

const BOT_UA_RE =
  /bot|crawler|spider|slurp|bingpreview|facebookexternalhit|whatsapp|telegram|discordbot|python-requests|curl\/|wget|scrapy|httpclient|go-http-client|java\/|libwww|feedfetcher|semrush|ahrefs|petalbot|bytespider|gptbot|claudebot|anthropic|openai|claude-web|meta-externalagent|amazonbot|yandexbot|baiduspider|duckduckbot|applebot|twitterbot|linkedinbot|embedly|quora link preview|showyoubot|outbrain|pinterest|redditbot|slackbot|vkshare|w3c_validator|phantomjs|headlesschrome|selenium|puppeteer/i;

/** مسارات ماسحات شائعة — لا تخص تطبيق Wood & More. */
const NOISE_PATH_RE =
  /^\/(\.env|\.git|wp-|wordpress|phpmyadmin|adminer|xmlrpc|cgi-bin|actuator|vendor\/|composer\.|laravel|telescope|horizon|server-status|favicon\.ico|robots\.txt|sitemap|autodiscover|owa\/|mssql|mysql|backup|debug|config\.json|api-docs|swagger)/i;

function requestPath(req) {
  const raw = String(req.originalUrl || req.url || req.path || '/');
  const q = raw.indexOf('?');
  return q >= 0 ? raw.slice(0, q) : raw;
}

function isHealthOrRoot(pathname) {
  return pathname === '/healthz' || pathname === '/';
}

function looksLikeBot(req) {
  const ua = String(req.headers['user-agent'] || '').trim();
  // عملاء التطبيق عندنا عادة Dart/Flutter أو متصفح حقيقي.
  if (/^Dart\//i.test(ua)) return false;
  if (/flutter/i.test(ua)) return false;
  if (!ua) return true;
  if (BOT_UA_RE.test(ua)) return true;
  return false;
}

function isNoisePath(pathname) {
  if (isHealthOrRoot(pathname)) return false;
  return NOISE_PATH_RE.test(pathname);
}

/**
 * Express middleware: 404 سريع بدون DB.
 */
function noiseGuard(req, res, next) {
  const pathname = requestPath(req);
  if (isHealthOrRoot(pathname)) return next();

  if (isNoisePath(pathname) || looksLikeBot(req)) {
    res.setHeader('Cache-Control', 'no-store');
    return res.status(404).type('text/plain').send('Not Found');
  }
  return next();
}

module.exports = {
  noiseGuard,
  looksLikeBot,
  isNoisePath,
  isHealthOrRoot,
  requestPath,
};
