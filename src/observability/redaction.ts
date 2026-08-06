const BEARER_PATTERN = /Bearer\s+[^\s,]+/gi
const URL_PATTERN = /\b(?:https?|wss?):\/\/[^\s]+/gi
const SECRET_ASSIGNMENT_PATTERN = /\b(token|secret|password|api[_-]?key)\s*[:=]\s*[^\s,]+/gi

export function redactSensitiveText(value: string): string {
  return value
    .replace(BEARER_PATTERN, 'Bearer [REDACTED]')
    .replace(SECRET_ASSIGNMENT_PATTERN, '$1=[REDACTED]')
    .replace(URL_PATTERN, '[REDACTED_URL]')
}

export function redactSensitiveValue(value: unknown): unknown {
  if (typeof value === 'string') {
    return redactSensitiveText(value)
  }
  if (Array.isArray(value)) {
    return value.map(redactSensitiveValue)
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [
        key,
        /^(token|secret|password|api[_-]?key)$/i.test(key)
          ? '[REDACTED]'
          : redactSensitiveValue(entry),
      ]),
    )
  }
  return value
}
