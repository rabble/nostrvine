function formatValue(value) {
  return value == null || value === '' ? '—' : String(value);
}

export function renderAuditList(rows) {
  const wrapper = document.createElement('div');

  if (!rows.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'No audit events yet.';
    wrapper.appendChild(empty);
    return wrapper;
  }

  const table = document.createElement('table');
  table.className = 'audit-table';
  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');
  for (const label of ['App', 'Origin', 'Method', 'Kind', 'Decision', 'Time']) {
    const th = document.createElement('th');
    th.textContent = label;
    headerRow.appendChild(th);
  }
  thead.appendChild(headerRow);
  table.appendChild(thead);

  const tbody = document.createElement('tbody');
  for (const row of rows) {
    const tr = document.createElement('tr');
    const cells = [
      formatValue(row.app_slug || row.app_id),
      formatValue(row.origin),
      formatValue(row.method),
      formatValue(row.event_kind),
      formatValue(row.decision),
      formatValue(row.created_at),
    ];

    cells.forEach((value, index) => {
      const td = document.createElement('td');
      if (index === 4) {
        const decision = document.createElement('span');
        decision.className = `decision ${String(value).toLowerCase()}`;
        decision.textContent = value;
        td.appendChild(decision);
      } else {
        td.textContent = value;
      }
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  }

  table.appendChild(tbody);
  wrapper.appendChild(table);
  return wrapper;
}
