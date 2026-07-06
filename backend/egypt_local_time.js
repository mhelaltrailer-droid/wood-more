/** مصر UTC+3 ثابتاً (بدون توقيت صيفي). */
const EGYPT_UTC_OFFSET_MS = 3 * 60 * 60 * 1000;

function toEgyptWallClock(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  const shifted = new Date(d.getTime() + EGYPT_UTC_OFFSET_MS);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
    hours: shifted.getUTCHours(),
    minutes: shifted.getUTCMinutes(),
  };
}

/**
 * تنسيق تاريخ/وقت عربي بتوقيت مصر المحلي بشكل موثوق
 * (بدون الاعتماد على ICU/timeZone في بيئات Node المحدودة).
 */
function formatArDateTimeEgypt(iso) {
  const wall = toEgyptWallClock(iso);
  if (!wall) return '';
  const fakeUtc = new Date(
    Date.UTC(wall.year, wall.month - 1, wall.day, wall.hours, wall.minutes),
  );
  const date = fakeUtc.toLocaleDateString('ar-EG', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    timeZone: 'UTC',
  });
  const time = fakeUtc.toLocaleTimeString('ar-EG', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
    timeZone: 'UTC',
  });
  return `${date} — ${time}`;
}

module.exports = {
  EGYPT_UTC_OFFSET_MS,
  toEgyptWallClock,
  formatArDateTimeEgypt,
};
