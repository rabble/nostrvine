const ACCESS_EMAIL_HEADER = 'CF-Access-Authenticated-User-Email';

export function requireAdmin(request: Request): string {
  const email = request.headers.get(ACCESS_EMAIL_HEADER)?.trim();
  if (!email) {
    throw new Response('Forbidden', { status: 403 });
  }

  return email;
}
