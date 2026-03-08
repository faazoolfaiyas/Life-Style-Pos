/**
 * Life Style POS - Shortcut Reference Overlay
 * 
 * A floating cheat sheet that shows all available keyboard shortcuts.
 * Toggle with ? or Ctrl+/
 */

(function () {
  'use strict';

  let overlayVisible = false;
  let overlayEl = null;

  const SHORTCUT_GROUPS = [
    {
      title: '🔍 Search & Scan',
      icon: '🔍',
      color: '#6366f1',
      shortcuts: [
        { keys: 'F1', desc: 'Focus search / scan bar' },
        { keys: 'Enter', desc: 'Submit scan' },
        { keys: 'Esc', desc: 'Clear search & refocus' },
      ],
    },
    {
      title: '🛒 Cart',
      icon: '🛒',
      color: '#10b981',
      shortcuts: [
        { keys: '↑ / ↓', desc: 'Navigate items' },
        { keys: '+ / -', desc: 'Change quantity' },
        { keys: 'Del', desc: 'Remove item' },
        { keys: 'Enter', desc: 'Edit price' },
      ],
    },
    {
      title: '📋 Operations',
      icon: '📋',
      color: '#f59e0b',
      shortcuts: [
        { keys: 'F5', desc: 'Apply discount' },
        { keys: 'F6', desc: 'Hold bill' },
        { keys: 'F7', desc: 'Save (no print)' },
        { keys: 'F8', desc: 'Print & complete' },
      ],
    },
    {
      title: '💳 Payment',
      icon: '💳',
      color: '#3b82f6',
      shortcuts: [
        { keys: 'F9', desc: 'Cash' },
        { keys: 'F10', desc: 'Card' },
        { keys: 'F11', desc: 'Transfer' },
        { keys: 'F12', desc: 'Credit' },
      ],
    },
    {
      title: '🗂️ Bills',
      icon: '🗂️',
      color: '#8b5cf6',
      shortcuts: [
        { keys: 'Ctrl+N', desc: 'New bill tab' },
        { keys: 'Ctrl+]', desc: 'Next bill tab' },
        { keys: 'Ctrl+[', desc: 'Previous bill tab' },
        { keys: 'Ctrl+W', desc: 'Close bill tab' },
      ],
    },
    {
      title: '⚡ Quick',
      icon: '⚡',
      color: '#ec4899',
      shortcuts: [
        { keys: 'F2', desc: 'Quick sale' },
        { keys: 'F3', desc: 'Bill history' },
        { keys: 'F4', desc: 'Pending bills' },
        { keys: 'Ctrl+P', desc: 'Toggle filters' },
      ],
    },
    {
      title: '💬 Dialogs',
      icon: '💬',
      color: '#14b8a6',
      shortcuts: [
        { keys: 'Tab', desc: 'Next field' },
        { keys: '↑ / ↓', desc: 'Move between fields' },
        { keys: '.', desc: 'Auto-fill payment exact' },
        { keys: 'Enter', desc: 'Submit dialog' },
      ],
    },
  ];

  function createOverlay() {
    const overlay = document.createElement('div');
    overlay.id = 'ls-shortcut-overlay';
    overlay.className = 'ls-overlay';

    // Close button
    const closeBtn = document.createElement('button');
    closeBtn.className = 'ls-overlay-close';
    closeBtn.textContent = '✕';
    closeBtn.onclick = () => toggleShortcutOverlay();
    overlay.appendChild(closeBtn);

    // Title
    const title = document.createElement('div');
    title.className = 'ls-overlay-title';
    title.innerHTML = '⌨️ Keyboard Shortcuts';
    overlay.appendChild(title);

    const subtitle = document.createElement('div');
    subtitle.className = 'ls-overlay-subtitle';
    subtitle.textContent = 'Press ? to toggle this panel';
    overlay.appendChild(subtitle);

    // Groups
    const groupsContainer = document.createElement('div');
    groupsContainer.className = 'ls-overlay-groups';

    SHORTCUT_GROUPS.forEach((group) => {
      const groupEl = document.createElement('div');
      groupEl.className = 'ls-overlay-group';

      const groupTitle = document.createElement('div');
      groupTitle.className = 'ls-overlay-group-title';
      groupTitle.style.borderLeftColor = group.color;
      groupTitle.textContent = group.title;
      groupEl.appendChild(groupTitle);

      group.shortcuts.forEach((shortcut) => {
        const row = document.createElement('div');
        row.className = 'ls-overlay-row';

        const keys = document.createElement('span');
        keys.className = 'ls-overlay-key';
        keys.style.borderColor = group.color + '60';
        keys.style.color = group.color;
        keys.textContent = shortcut.keys;

        const desc = document.createElement('span');
        desc.className = 'ls-overlay-desc';
        desc.textContent = shortcut.desc;

        row.appendChild(keys);
        row.appendChild(desc);
        groupEl.appendChild(row);
      });

      groupsContainer.appendChild(groupEl);
    });

    overlay.appendChild(groupsContainer);

    // Footer
    const footer = document.createElement('div');
    footer.className = 'ls-overlay-footer';
    footer.textContent = 'Life Style POS v1.0';
    overlay.appendChild(footer);

    return overlay;
  }

  // Global toggle function
  window.toggleShortcutOverlay = function () {
    if (!overlayEl) {
      overlayEl = createOverlay();
      document.body.appendChild(overlayEl);
    }

    overlayVisible = !overlayVisible;

    if (overlayVisible) {
      overlayEl.classList.add('ls-overlay-visible');
    } else {
      overlayEl.classList.remove('ls-overlay-visible');
    }
  };
})();
