/**
 * Life Style POS - Keyboard Shortcuts Content Script
 * 
 * Intercepts browser-level keyboard events and forwards them to the Flutter
 * web app canvas, suppressing browser defaults (e.g. F5 = refresh).
 * Also dispatches synthetic events for new shortcut bindings.
 */

(function () {
  'use strict';

  let enabled = true;

  // Load enabled state from storage
  chrome.storage.sync.get(['shortcutsEnabled'], (result) => {
    enabled = result.shortcutsEnabled !== false; // Default: enabled
  });

  // Listen for enable/disable toggles from popup
  chrome.storage.onChanged.addListener((changes) => {
    if (changes.shortcutsEnabled) {
      enabled = changes.shortcutsEnabled.newValue !== false;
      showToast(enabled ? '⌨️ Shortcuts Enabled' : '⌨️ Shortcuts Disabled');
    }
  });

  // ─── Utility: Find Flutter's glass pane (event target) ───
  function getFlutterTarget() {
    // Flutter 3.x uses flt-glass-pane inside shadow DOM
    const glassPane = document.querySelector('flt-glass-pane');
    if (glassPane && glassPane.shadowRoot) {
      // Target the platform view or canvas inside shadow root
      const canvas = glassPane.shadowRoot.querySelector('canvas');
      if (canvas) return canvas;
      return glassPane;
    }
    // Fallback: try direct canvas
    return document.querySelector('canvas') || document.body;
  }

  // ─── Utility: Dispatch synthetic keyboard event to Flutter ───
  function dispatchToFlutter(originalEvent, keyOverride) {
    const target = getFlutterTarget();
    const syntheticEvent = new KeyboardEvent(originalEvent.type, {
      key: keyOverride || originalEvent.key,
      code: originalEvent.code,
      keyCode: originalEvent.keyCode,
      which: originalEvent.which,
      ctrlKey: originalEvent.ctrlKey,
      shiftKey: originalEvent.shiftKey,
      altKey: originalEvent.altKey,
      metaKey: originalEvent.metaKey,
      bubbles: true,
      cancelable: true,
    });
    target.dispatchEvent(syntheticEvent);
  }

  // ─── Toast notification ───
  function showToast(message, duration = 1500) {
    // Remove existing toast
    const existing = document.getElementById('ls-shortcut-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.id = 'ls-shortcut-toast';
    toast.textContent = message;
    Object.assign(toast.style, {
      position: 'fixed',
      bottom: '24px',
      left: '50%',
      transform: 'translateX(-50%) translateY(20px)',
      background: 'rgba(0, 0, 0, 0.85)',
      color: '#fff',
      padding: '10px 24px',
      borderRadius: '8px',
      fontSize: '13px',
      fontFamily: "'Inter', 'Segoe UI', sans-serif",
      fontWeight: '500',
      zIndex: '999999',
      opacity: '0',
      transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
      pointerEvents: 'none',
      backdropFilter: 'blur(8px)',
      border: '1px solid rgba(255,255,255,0.1)',
      boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
      letterSpacing: '0.3px',
    });

    document.body.appendChild(toast);

    // Animate in
    requestAnimationFrame(() => {
      toast.style.opacity = '1';
      toast.style.transform = 'translateX(-50%) translateY(0)';
    });

    // Animate out
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(-50%) translateY(20px)';
      setTimeout(() => toast.remove(), 300);
    }, duration);
  }

  // ─── Shortcut labels for toast messages ───
  const SHORTCUT_LABELS = {
    'F1': '🔍 Focus Search Bar',
    'F2': '⚡ Quick Sale',
    'F3': '📋 Bill History',
    'F4': '⏸️ Pending Bills',
    'F5': '💸 Apply Discount',
    'F6': '📌 Hold Bill',
    'F7': '💾 Save Bill',
    'F8': '🖨️ Print & Complete',
    'F9': '💵 Cash Payment',
    'F10': '💳 Card Payment',
    'F11': '🔄 Transfer Payment',
    'F12': '📝 Credit Payment',
    'Ctrl+N': '📄 New Bill',
    'Ctrl+Tab': '➡️ Next Bill Tab',
    'Ctrl+Shift+Tab': '⬅️ Previous Bill Tab',
    'Ctrl+W': '❌ Close Bill Tab',
    'Ctrl+P': '🔍 Toggle Filters',
    'Escape': '🧹 Clear Search',
  };

  // ─── Key that should be suppressed at browser level ───
  const SUPPRESS_BROWSER = new Set([
    'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8',
    'F9', 'F10', 'F11', 'F12',
  ]);

  // ─── Main keydown handler (capture phase) ───
  document.addEventListener('keydown', (e) => {
    if (!enabled) return;

    // Don't intercept when typing in an actual input/textarea (non-Flutter)
    const isTyping = e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable;
    
    const key = e.key;
    const ctrl = e.ctrlKey || e.metaKey;
    const shift = e.shiftKey;

    // ─── F1: Focus Search Bar ───
    if (key === 'F1') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['F1']);
      return;
    }

    // ─── F2: Quick Sale ───
    if (key === 'F2') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['F2']);
      return;
    }

    // ─── F3: Bill History ───
    if (key === 'F3') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['F3']);
      return;
    }

    // ─── F4: Pending Bills ───
    if (key === 'F4') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['F4']);
      return;
    }

    // ─── F5: Discount (suppress browser refresh!) ───
    if (key === 'F5') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['F5']);
      return;
    }

    // ─── F6–F8: Hold / Save / Print ───
    if (key === 'F6' || key === 'F7' || key === 'F8') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS[key]);
      return;
    }

    // ─── F9–F12: Payment Methods ───
    if (key === 'F9' || key === 'F10' || key === 'F11' || key === 'F12') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS[key]);
      return;
    }

    // ─── Ctrl+N: New Bill ───
    if (ctrl && !shift && key === 'n') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['Ctrl+N']);
      return;
    }

    // ─── Ctrl+Tab: Next Bill Tab ───
    // Note: Ctrl+Tab is a Chrome built-in and cannot be fully intercepted
    // in content scripts. We'll use Ctrl+] as alternative.
    if (ctrl && !shift && key === ']') {
      e.preventDefault();
      e.stopPropagation();
      // Dispatch as Ctrl+Tab equivalent
      const synth = new KeyboardEvent('keydown', {
        key: ']',
        code: 'BracketRight',
        ctrlKey: true,
        bubbles: true,
        cancelable: true,
      });
      getFlutterTarget().dispatchEvent(synth);
      showToast('➡️ Next Bill Tab');
      return;
    }

    // ─── Ctrl+Shift+Tab: Prev Bill Tab → Ctrl+[ ───
    if (ctrl && !shift && key === '[') {
      e.preventDefault();
      e.stopPropagation();
      const synth = new KeyboardEvent('keydown', {
        key: '[',
        code: 'BracketLeft',
        ctrlKey: true,
        bubbles: true,
        cancelable: true,
      });
      getFlutterTarget().dispatchEvent(synth);
      showToast('⬅️ Previous Bill Tab');
      return;
    }

    // ─── Ctrl+W: Close Bill Tab ───
    if (ctrl && !shift && key === 'w') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['Ctrl+W']);
      return;
    }

    // ─── Ctrl+P: Toggle Filters (suppress browser print) ───
    if (ctrl && !shift && key === 'p') {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['Ctrl+P']);
      return;
    }

    // ─── Escape: Clear search ───
    if (key === 'Escape' && !ctrl && !shift && !isTyping) {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      showToast(SHORTCUT_LABELS['Escape']);
      return;
    }

    // ─── ? or Ctrl+/: Toggle overlay ───
    if ((key === '?' && shift) || (ctrl && key === '/')) {
      e.preventDefault();
      e.stopPropagation();
      if (typeof toggleShortcutOverlay === 'function') {
        toggleShortcutOverlay();
      }
      return;
    }

    // ─── Cart & Dialog Navigation (Force to Flutter, prevent browser scrolling) ───
    // Only intercept if we are NOT typing in a text field, so typing works normally.
    if (['ArrowUp', 'ArrowDown', '+', '=', '-', 'Delete', 'Enter'].includes(key) && !isTyping && !ctrl && !shift) {
      e.preventDefault();
      e.stopPropagation();
      dispatchToFlutter(e);
      return;
    }

  }, true); // Capture phase — fires before Flutter

  // ─── Initial toast ───
  window.addEventListener('load', () => {
    setTimeout(() => {
      showToast('⌨️ POS Shortcuts Active — Press ? for help', 3000);
    }, 2000);
  });

  console.log('[Life Style POS] Keyboard shortcut extension loaded.');
})();
