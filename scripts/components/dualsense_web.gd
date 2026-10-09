extends RefCounted

const SOURCE := """
window.arrowheadTriggers = (() => {
 // Match the native tension through the final zone.
 const curve = [0, .375, .5, .625, .75, .875, 1, 1, 1, 1];
 let device = null, bluetooth = false, sequence = 0, serial = Promise.resolve();
 let revision = 0, strength = 0, lease = 0, modal = null, session = 0;
 let mode = 0x05;
 const api = {ready: false, status: ''};
 const clamp = value => Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;
 function unavailable() {
  if (!window.isSecureContext) return 'Adaptive triggers need HTTPS or localhost.';
  const policy = document.permissionsPolicy || document.featurePolicy;
  if (policy && !policy.allowsFeature('hid')) return 'This embedded page blocks controller access. Open a standalone build in Chrome or Edge.';
  if (!navigator.hid) return 'Adaptive triggers need desktop Chrome or Edge. Normal controls still work.';
  return '';
 }
 function packet(value, effectMode = 0x21) {
  const data = new Uint8Array(bluetooth ? 77 : 47);
  const offset = bluetooth ? 2 : 0;
  if (bluetooth) {
   data[0] = (sequence++ % 16) << 4;
   data[1] = 0x10;
  }
  data[offset] = 0x0c; // Update both trigger effects.
  const effect = offset + 10, leftEffect = offset + 21;
  const view = new DataView(data.buffer);
  data[effect] = data[leftEffect] = 0x05;
  if (effectMode === 0x06) {
   const force = Math.round(value * 255);
   if (force) {
    // Match DualSense Tester's automatic trigger: frequency, force, start.
    data.set([0x06, 10, force, 20], effect);
    data.set([0x06, 10, force, 20], leftEffect);
   }
  } else {
   let mask = 0, forces = 0;
   curve.forEach((amount, zone) => {
    const force = Math.round(amount * value * 8);
    if (force) { mask |= 1 << zone; forces |= (force - 1) << (zone * 3); }
   });
   if (mask) {
    data[effect] = 0x21;
    view.setUint16(effect + 1, mask, true);
    view.setUint32(effect + 3, forces, true);
   }
  }
  if (bluetooth) {
   let crc = 0xffffffff;
   for (const byte of [0xa2, 0x31, ...data.subarray(0, 73)]) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
   }
   view.setUint32(73, (~crc) >>> 0, true);
  }
  return data;
 }
 function queue(value, effectMode = 0x21) {
  const target = device, token = ++revision;
  serial = serial.then(async () => {
   if (!target?.opened || target !== device || token !== revision) return;
   try { await target.sendReport(bluetooth ? 0x31 : 0x02, packet(value, effectMode)); }
   catch (_) {
    api.ready = false;
    api.status = 'Controller access was lost. Reconnect the DualSense.';
    strength = 0;
    try { await target.sendReport(bluetooth ? 0x31 : 0x02, packet(0)); } catch (_) {}
    try { await target.close(); } catch (_) {}
    if (device === target) device = null;
   }
  });
  return serial;
 }
 function setEffect(value, effectMode) {
  value = api.ready && !document.hidden && document.hasFocus() ? clamp(value) : 0;
  if (!value) effectMode = 0x05;
  if (effectMode !== 0x06) lease = performance.now() + 1000;
  if (value === strength && mode === effectMode) return;
  mode = effectMode;
  strength = value;
  if (effectMode === 0x06) lease = performance.now() + 260;
  queue(value, effectMode);
 }
 api.bow = value => setEffect(value, 0x21);
 api.kick = value => setEffect(value, 0x06);
 const stop = () => api.bow(0);
 const watchdog = setInterval(() => { if (performance.now() >= lease) stop(); }, 20);

 function removeModal() { modal?.remove(); modal = null; }
 async function connect() {
  const token = ++session;
  try {
   const devices = await navigator.hid.requestDevice({filters: [
    {vendorId: 0x054c, productId: 0x0ce6},
    {vendorId: 0x054c, productId: 0x0df2}
   ]});
   const selected = devices[0];
   if (!selected || token !== session) { api.status = 'Connection cancelled. Normal controls still work.'; return; }
   await queue(0);
   if (device && device !== selected && device.opened) await device.close();
   if (!selected.opened) await selected.open();
   if (token !== session) { await selected.close(); return; }
   const reportIds = [];
   const collect = collections => collections.forEach(c => {
    for (const report of c.outputReports || []) reportIds.push(report.reportId);
    collect(c.children || []);
   });
   collect(selected.collections);
   if (!reportIds.includes(0x02) && !reportIds.includes(0x31)) {
    await selected.close();
    api.status = 'This device does not expose DualSense trigger reports.';
    return;
   }
   device = selected;
   bluetooth = !reportIds.includes(0x02);
   sequence = 0;
   strength = 0;
   mode = 0x05;
   await queue(0);
   api.ready = device === selected && selected.opened;
   if (api.ready) api.status = 'DualSense connected (' + (bluetooth ? 'Bluetooth' : 'USB') + '). R2 tension is ready.';
  } catch (_) {
   api.ready = false;
   api.status = 'Could not connect. Check browser permission and reconnect your DualSense.';
  } finally { removeModal(); }
 }
 api.showConnect = () => {
  stop();
  const reason = unavailable();
  if (reason) { api.status = reason; return; }
  if (modal) return;
  modal = document.createElement('div');
  modal.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;background:#101000cc;color:#edf0ab;font:18px sans-serif';
  const box = document.createElement('div');
  box.style.cssText = 'padding:28px;max-width:430px;background:#393b06;border:2px solid #edf0ab;border-radius:16px;text-align:center';
  const message = document.createElement('p');
  message.textContent = 'Connect your DualSense, then click below to allow R2 resistance. The browser requires a mouse click for this step.';
  box.appendChild(message);
  const button = (text, action) => {
   const el = document.createElement('button');
   el.textContent = text;
   el.style.cssText = 'padding:12px 18px;margin:8px;background:#85870d;color:#fffbd5;border:1px solid #edf0ab;border-radius:6px;font:inherit;cursor:pointer';
   el.onclick = action;
   box.appendChild(el);
   return el;
  };
  button('Connect DualSense', event => { event.currentTarget.disabled = true; connect(); });
  button('Cancel', () => { session++; removeModal(); });
  modal.appendChild(box);
  document.body.appendChild(modal);
 };
 function disconnected(event) {
  if (event.device !== device) return;
  revision++;
  strength = 0;
  device = null;
  api.ready = false;
  api.status = 'DualSense disconnected. Connect it again to restore resistance.';
 }
 api.shutdown = async () => {
  session++;
  removeModal();
  stop();
  await serial;
  if (device?.opened) { try { await device.close(); } catch (_) {} }
  device = null;
  api.ready = false;
  clearInterval(watchdog);
  window.removeEventListener('blur', stop);
  window.removeEventListener('pagehide', stop);
  document.removeEventListener('visibilitychange', stop);
  navigator.hid?.removeEventListener('disconnect', disconnected);
 };
 window.addEventListener('blur', stop);
 window.addEventListener('pagehide', stop);
 document.addEventListener('visibilitychange', stop);
 navigator.hid?.addEventListener('disconnect', disconnected);
 api.status = unavailable() || 'Connect DualSense to enable R2 resistance.';
 return api;
})();
"""
