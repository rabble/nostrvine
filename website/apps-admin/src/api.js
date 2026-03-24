async function requestJson(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      accept: 'application/json',
      ...(options.body ? { 'content-type': 'application/json' } : {}),
      ...(options.headers || {}),
    },
    ...options,
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(body || `Request failed: ${response.status}`);
  }

  return response.json();
}

export function listApps() {
  return requestJson('/v1/admin/apps');
}

export function saveApp(payload) {
  return requestJson('/v1/admin/apps', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function listAuditEvents() {
  return requestJson('/v1/admin/audit-events');
}
