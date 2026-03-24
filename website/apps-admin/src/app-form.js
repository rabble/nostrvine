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
    slug: valuesFor(formEl, 'slug')[0] || '',
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
    setListValue(form, 'allowed_origins', manifest.allowed_origins || []);
    setListValue(form, 'allowed_methods', manifest.allowed_methods || []);
    setListValue(form, 'allowed_sign_event_kinds', (manifest.allowed_sign_event_kinds || []).map(String));
    setListValue(form, 'prompt_required_for', manifest.prompt_required_for || []);
  }

  function clear() {
    loadManifest({
      id: '',
      slug: '',
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
