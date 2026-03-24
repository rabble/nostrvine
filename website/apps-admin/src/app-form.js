function getControls(formEl) {
  if (!formEl) return [];
  if (formEl.elements && typeof formEl.elements.length === 'number') {
    return Array.from(formEl.elements);
  }
  if (typeof formEl.querySelectorAll === 'function') {
    return Array.from(formEl.querySelectorAll('input, textarea, select'));
  }
  return [];
}

function splitValues(raw) {
  return String(raw ?? '')
    .split(/\r?\n|,/)
    .map((value) => value.trim())
    .filter(Boolean);
}

function valuesFor(formEl, name) {
  return getControls(formEl)
    .filter((control) => control && control.name === name && !control.disabled)
    .flatMap((control) => splitValues(control.value));
}

function firstValueFor(formEl, name) {
  const control = getControls(formEl).find(
    (candidate) => candidate && candidate.name === name && !candidate.disabled,
  );
  return String(control?.value ?? '').trim();
}

function uniqueValues(values) {
  const seen = new Set();
  const output = [];
  for (const value of values) {
    if (seen.has(value)) continue;
    seen.add(value);
    output.push(value);
  }
  return output;
}

function parseKinds(values) {
  return uniqueValues(values)
    .map((value) => Number.parseInt(value, 10))
    .filter((value) => Number.isInteger(value));
}

function parseInteger(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) ? parsed : fallback;
}

function setTextValue(form, name, value) {
  const control = form.querySelector(`[name="${name}"]`);
  if (control) control.value = value ?? '';
}

function setListValue(form, name, values) {
  const control = form.querySelector(`[name="${name}"]`);
  if (control) control.value = (values || []).join('\n');
}

export function serializeForm(formEl) {
  const allowedOrigins = uniqueValues(valuesFor(formEl, 'allowed_origins'));
  const allowedMethods = uniqueValues(valuesFor(formEl, 'allowed_methods'));
  const promptRequiredFor = uniqueValues(valuesFor(formEl, 'prompt_required_for'));

  return {
    slug: firstValueFor(formEl, 'slug'),
    name: firstValueFor(formEl, 'name'),
    tagline: firstValueFor(formEl, 'tagline'),
    description: firstValueFor(formEl, 'description'),
    icon_url: firstValueFor(formEl, 'icon_url'),
    launch_url: firstValueFor(formEl, 'launch_url'),
    status: firstValueFor(formEl, 'status') || 'draft',
    sort_order: parseInteger(firstValueFor(formEl, 'sort_order')),
    allowed_origins: allowedOrigins,
    allowed_methods: allowedMethods,
    allowed_sign_event_kinds: parseKinds(valuesFor(formEl, 'allowed_sign_event_kinds')),
    prompt_required_for: promptRequiredFor,
  };
}

export function createAppForm() {
  const form = document.createElement('form');
  form.className = 'app-form';

  form.innerHTML = `
    <input type="hidden" name="id" />
    <div class="form-field">
      <label for="slug">Slug</label>
      <input id="slug" name="slug" autocomplete="off" required />
    </div>
    <div class="form-field">
      <label for="name">Name</label>
      <input id="name" name="name" autocomplete="off" required />
    </div>
    <div class="form-field">
      <label for="tagline">Tagline</label>
      <input id="tagline" name="tagline" autocomplete="off" />
    </div>
    <div class="form-field">
      <label for="description">Description</label>
      <textarea id="description" name="description" placeholder="What this app does and why it is allowed here."></textarea>
    </div>
    <div class="form-field">
      <label for="icon_url">Icon URL</label>
      <input id="icon_url" name="icon_url" autocomplete="off" placeholder="https://example.com/icon.png" />
    </div>
    <div class="form-field">
      <label for="launch_url">Launch URL</label>
      <input id="launch_url" name="launch_url" autocomplete="off" placeholder="https://example.com/app" required />
    </div>
    <div class="form-field">
      <label for="status">Status</label>
      <select id="status" name="status">
        <option value="draft">Draft</option>
        <option value="approved">Approved</option>
        <option value="revoked">Revoked</option>
      </select>
    </div>
    <div class="form-field">
      <label for="sort_order">Sort order</label>
      <input id="sort_order" name="sort_order" type="number" inputmode="numeric" value="0" />
    </div>
    <div class="form-field">
      <label for="allowed_origins">Allowed origins</label>
      <textarea id="allowed_origins" name="allowed_origins" placeholder="https://example.com"></textarea>
      <p class="form-help">One origin per line.</p>
    </div>
    <div class="form-field">
      <label for="allowed_methods">Allowed methods</label>
      <textarea id="allowed_methods" name="allowed_methods" placeholder="getPublicKey&#10;signEvent"></textarea>
      <p class="form-help">One method per line.</p>
    </div>
    <div class="form-field">
      <label for="allowed_sign_event_kinds">Allowed sign event kinds</label>
      <textarea id="allowed_sign_event_kinds" name="allowed_sign_event_kinds" placeholder="1&#10;4"></textarea>
      <p class="form-help">One numeric kind per line.</p>
    </div>
    <div class="form-field">
      <label for="prompt_required_for">Prompt required for</label>
      <textarea id="prompt_required_for" name="prompt_required_for" placeholder="nip44.decrypt"></textarea>
      <p class="form-help">One capability per line.</p>
    </div>
    <div class="form-actions">
      <button type="submit" class="button">Save app</button>
      <button type="button" class="button secondary" data-action="clear">Clear</button>
    </div>
  `;

  const submitButton = form.querySelector('button[type="submit"]');
  const clearButton = form.querySelector('[data-action="clear"]');

  function loadManifest(manifest = {}) {
    setTextValue(form, 'id', manifest.id || '');
    setTextValue(form, 'slug', manifest.slug || '');
    setTextValue(form, 'name', manifest.name || '');
    setTextValue(form, 'tagline', manifest.tagline || '');
    setTextValue(form, 'description', manifest.description || '');
    setTextValue(form, 'icon_url', manifest.icon_url || '');
    setTextValue(form, 'launch_url', manifest.launch_url || '');
    setTextValue(form, 'status', manifest.status || 'draft');
    setTextValue(form, 'sort_order', manifest.sort_order ?? 0);
    setListValue(form, 'allowed_origins', manifest.allowed_origins || []);
    setListValue(form, 'allowed_methods', manifest.allowed_methods || []);
    setListValue(form, 'allowed_sign_event_kinds', (manifest.allowed_sign_event_kinds || []).map(String));
    setListValue(form, 'prompt_required_for', manifest.prompt_required_for || []);
  }

  function clear() {
    loadManifest({
      id: '',
      slug: '',
      name: '',
      tagline: '',
      description: '',
      icon_url: '',
      launch_url: '',
      status: 'draft',
      sort_order: 0,
      allowed_origins: [],
      allowed_methods: [],
      allowed_sign_event_kinds: [],
      prompt_required_for: [],
    });
  }

  clearButton.addEventListener('click', clear);

  return {
    element: form,
    loadManifest,
    clear,
    setSubmitting(isSubmitting) {
      submitButton.disabled = isSubmitting;
      submitButton.textContent = isSubmitting ? 'Saving…' : 'Save app';
      clearButton.disabled = isSubmitting;
    },
  };
}
