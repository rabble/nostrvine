export function renderAppList(apps, activeId, onSelect) {
  const container = document.createElement('div');
  container.className = 'app-list';

  if (!apps.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'No approved or draft apps yet.';
    container.appendChild(empty);
    return container;
  }

  for (const app of apps) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'app-list-item';
    button.dataset.active = String(app.id === activeId);
    const title = document.createElement('strong');
    title.textContent = app.slug || 'Untitled app';
    const status = document.createElement('small');
    status.textContent = app.status || 'draft';
    button.append(title, status);
    button.addEventListener('click', () => onSelect(app));
    container.appendChild(button);
  }

  return container;
}
