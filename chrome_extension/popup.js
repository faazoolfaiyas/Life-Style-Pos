/**
 * Life Style POS - Popup Script
 * Controls the enable/disable toggle for the shortcut extension.
 */

(function () {
  'use strict';

  const toggle = document.getElementById('enableToggle');
  const statusText = document.getElementById('statusText');

  // Load saved state
  chrome.storage.sync.get(['shortcutsEnabled'], (result) => {
    const enabled = result.shortcutsEnabled !== false;
    toggle.checked = enabled;
    statusText.textContent = enabled ? 'Active' : 'Disabled';
    statusText.style.color = enabled
      ? 'rgba(99, 102, 241, 0.8)'
      : 'rgba(255, 80, 80, 0.6)';
  });

  // Save toggle state
  toggle.addEventListener('change', () => {
    const enabled = toggle.checked;
    chrome.storage.sync.set({ shortcutsEnabled: enabled });
    statusText.textContent = enabled ? 'Active' : 'Disabled';
    statusText.style.color = enabled
      ? 'rgba(99, 102, 241, 0.8)'
      : 'rgba(255, 80, 80, 0.6)';
  });
})();
