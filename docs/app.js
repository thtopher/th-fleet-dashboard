// TH Fleet Dashboard - app.js
// Fetches status.json and renders gateway status table

const REFRESH_INTERVAL_MS = 30000; // 30 seconds
const WORKFLOW_BASE = 'https://github.com/thtopher/th-fleet-dashboard/actions/workflows/';

const STATUS_LABELS = {
  'up': 'Up',
  'degraded': 'Degraded', 
  'down': 'Down',
  'not-deployed': 'Not Deployed',
  'unknown': 'Unknown'
};

function formatRelativeTime(isoString) {
  if (!isoString) return '—';
  const date = new Date(isoString);
  const now = new Date();
  const diffMs = now - date;
  const diffSec = Math.floor(diffMs / 1000);
  
  if (diffSec < 60) return `${diffSec}s ago`;
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`;
  return `${Math.floor(diffSec / 86400)}d ago`;
}

function formatGatewayName(key) {
  // topher-winnicot -> Topher / Winnicot
  const parts = key.split('-');
  return parts.map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(' / ');
}

function renderStatus(status) {
  const dot = document.createElement('span');
  dot.className = `status-dot status-${status}`;
  
  const label = document.createElement('span');
  label.textContent = STATUS_LABELS[status] || status;
  
  const container = document.createElement('div');
  container.className = 'status-cell';
  container.appendChild(dot);
  container.appendChild(label);
  return container;
}

function renderActionButton(action, isStale) {
  if (!action) {
    return document.createTextNode('—');
  }
  
  const btn = document.createElement('a');
  btn.className = 'action-btn';
  
  if (!action.enabled || isStale) {
    btn.className += ' disabled';
    btn.textContent = action.enabled ? 'Stale' : 'Not Deployed';
    btn.href = '#';
  } else {
    btn.textContent = 'Restart →';
    btn.href = WORKFLOW_BASE + action.name + '.yml';
    btn.target = '_blank';
  }
  
  return btn;
}

function renderTable(data, isStale) {
  const tbody = document.getElementById('fleet-body');
  tbody.innerHTML = '';
  
  const gateways = data.gateways || {};
  const actions = data.actions || [];
  
  // Build action lookup by target
  const actionMap = {};
  actions.forEach(a => { actionMap[a.target] = a; });
  
  for (const [key, gw] of Object.entries(gateways)) {
    const tr = document.createElement('tr');
    if (isStale) tr.className = 'stale-row';
    
    // Gateway name
    const tdName = document.createElement('td');
    tdName.textContent = formatGatewayName(key);
    tr.appendChild(tdName);
    
    // Status
    const tdStatus = document.createElement('td');
    tdStatus.appendChild(renderStatus(isStale ? 'unknown' : gw.status));
    tr.appendChild(tdStatus);
    
    // Last checked
    const tdChecked = document.createElement('td');
    tdChecked.textContent = formatRelativeTime(gw.last_checked_at);
    tr.appendChild(tdChecked);
    
    // Detail
    const tdDetail = document.createElement('td');
    tdDetail.className = 'detail-text';
    tdDetail.textContent = gw.details || (gw.pid ? `PID ${gw.pid}` : '—');
    tr.appendChild(tdDetail);
    
    // Action
    const tdAction = document.createElement('td');
    tdAction.appendChild(renderActionButton(actionMap[key], isStale));
    tr.appendChild(tdAction);
    
    tbody.appendChild(tr);
  }
}

function updateLastUpdated(isoString) {
  const el = document.getElementById('last-updated');
  if (!isoString) {
    el.textContent = 'No data';
    return;
  }
  el.textContent = `Last poll: ${formatRelativeTime(isoString)}`;
}

function showStaleBanner(message) {
  const banner = document.getElementById('stale-banner');
  const msgEl = document.getElementById('stale-message');
  msgEl.textContent = message;
  banner.hidden = false;
}

function hideStaleBanner() {
  document.getElementById('stale-banner').hidden = true;
}

async function fetchStatus() {
  try {
    const resp = await fetch('status.json?t=' + Date.now());
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    return await resp.json();
  } catch (err) {
    console.error('Failed to fetch status.json:', err);
    return null;
  }
}

async function refresh() {
  const data = await fetchStatus();
  
  if (!data) {
    showStaleBanner('Failed to load status.json. Dashboard may be misconfigured.');
    return;
  }
  
  const updatedAt = new Date(data.updated_at);
  const now = new Date();
  const ageMs = now - updatedAt;
  const pollIntervalMs = (data.poll_interval_seconds || 60) * 1000;
  const staleThresholdMs = pollIntervalMs * 2;
  
  const isStale = ageMs > staleThresholdMs;
  
  if (isStale) {
    const ageMin = Math.floor(ageMs / 60000);
    const expectedSec = data.poll_interval_seconds || 60;
    showStaleBanner(
      `Poller on Hostinger VPS may be down — last update ${ageMin}m ago (expected every ${expectedSec}s).`
    );
  } else {
    hideStaleBanner();
  }
  
  updateLastUpdated(data.updated_at);
  renderTable(data, isStale);
}

// Initial load
refresh();

// Auto-refresh
setInterval(refresh, REFRESH_INTERVAL_MS);
