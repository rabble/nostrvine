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

function normalizeSavedApp(payload) {
  if (!payload || typeof payload !== 'object') {
    return payload;
  }

  if ('app' in payload && 'id' in payload) {
    const { app, id } = payload;
    if (app && typeof app === 'object') {
      return { id, ...app };
    }
  }

  return payload;
}

export function listApps() {
  return requestJson('/v1/admin/apps');
}

export function saveApp(payload) {
  const { id, ...appPayload } = payload;
  const path = id ? `/v1/admin/apps/${id}` : '/v1/admin/apps';
  const method = id ? 'PUT' : 'POST';
  return requestJson(path, {
    method,
    body: JSON.stringify(appPayload),
  }).then(normalizeSavedApp);
}

export function listAuditEvents() {
  return requestJson('/v1/admin/audit-events');
}
