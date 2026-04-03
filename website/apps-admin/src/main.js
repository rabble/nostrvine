import { listApps, listAuditEvents, saveApp } from './api.js';
import { createAppForm, serializeForm } from './app-form.js';
import { renderAppList } from './app-list.js';
import { renderAuditList } from './audit-list.js';

const state = {
  apps: [],
  audits: [],
  selectedApp: null,
};

const statusEl = document.getElementById('status');
const appListEl = document.getElementById('app-list');
const appFormEl = document.getElementById('app-form');
const auditListEl = document.getElementById('audit-list');
const refreshButton = document.getElementById('refresh');
const newButton = document.getElementById('new-app');

const formController = createAppForm();
appFormEl.replaceChildren(formController.element);

function setStatus(message, tone = 'idle') {
  statusEl.textContent = message;
  statusEl.dataset.tone = tone;
}

function renderApps() {
  appListEl.replaceChildren(renderAppList(state.apps, state.selectedApp?.id, (app) => {
    state.selectedApp = app;
    formController.loadManifest(app);
    renderApps();
    setStatus(`Editing ${app.slug}.`);
  }));
}

function renderAudits() {
  auditListEl.replaceChildren(renderAuditList(state.audits));
}

async function refreshDirectory() {
  setStatus('Loading apps and audit events...');
  try {
    const [apps, audits] = await Promise.all([listApps(), listAuditEvents()]);
    state.apps = Array.isArray(apps) ? apps : apps.items || [];
    state.audits = Array.isArray(audits) ? audits : audits.items || [];
    if (state.selectedApp) {
      const refreshed = state.apps.find((app) => app.id === state.selectedApp.id);
      state.selectedApp = refreshed || state.apps[0] || null;
    } else {
      state.selectedApp = state.apps[0] || null;
    }
    if (state.selectedApp) {
      formController.loadManifest(state.selectedApp);
    } else {
      formController.clear();
    }
    renderApps();
    renderAudits();
    setStatus('Directory loaded.');
  } catch (error) {
    setStatus(error.message || 'Failed to load admin data.', 'error');
  }
}

formController.element.addEventListener('submit', async (event) => {
  event.preventDefault();
  formController.setSubmitting(true);

  try {
    const payload = serializeForm(formController.element);
    const appId = formController.element.querySelector('[name="id"]').value;
    if (appId) {
      payload.id = appId;
    }

    const saved = await saveApp(payload);
    state.selectedApp = saved;
    await refreshDirectory();
    setStatus(`Saved ${saved.slug}.`);
  } catch (error) {
    setStatus(error.message || 'Failed to save app.', 'error');
  } finally {
    formController.setSubmitting(false);
  }
});

refreshButton.addEventListener('click', refreshDirectory);
newButton.addEventListener('click', () => {
  state.selectedApp = null;
  formController.clear();
  renderApps();
  setStatus('Creating a new app.');
});

await refreshDirectory();
