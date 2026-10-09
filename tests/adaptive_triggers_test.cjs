const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../scripts/components/dualsense_web.gd'), 'utf8').split('const SOURCE := """')[1].split('"""')[0];
const native = fs.readFileSync(path.join(__dirname, '../native/dualsense/trigger_report.h'), 'utf8');
const nativeCurve = native.match(/const float curve\[10\] = \{([^}]+)\}/)[1].split(',').map(Number);
const webCurve = source.match(/const curve = \[([^\]]+)\]/)[1].split(',').map(Number);
assert.deepEqual(nativeCurve, webCurve, 'Native and web must have the same bow profile');
const settle = () => new Promise(resolve => setImmediate(resolve));

function setup({bluetooth = false, policy = true, hid = true, denied = false} = {}) {
  const nodes = [], events = {}, timers = [], reports = [];
  let now = 0, sendHook;
  const device = {
    opened: false,
    collections: [{outputReports: [{reportId: bluetooth ? 0x31 : 0x02}]}],
    async open() { this.opened = true; },
    async close() { this.opened = false; },
    async sendReport(id, data) {
      reports.push({id, data: Array.from(data)});
      if (sendHook) await sendHook();
    },
  };
  const listen = {
    addEventListener: (name, handler) => { events[name] = handler; },
    removeEventListener: name => { delete events[name]; },
  };
  const document = {
    ...listen, hidden: false, hasFocus: () => true,
    permissionsPolicy: {allowsFeature: () => policy},
    body: {appendChild() {}},
    createElement: tag => {
      const node = {tag, style: {}, appendChild() {}, remove() { this.removed = true; }};
      nodes.push(node);
      return node;
    },
  };
  const navigator = hid ? {hid: {
    ...listen,
    requestDevice: async () => { if (denied) throw Error('denied'); return [device]; },
  }} : {};
  const window = {...listen, isSecureContext: true};
  vm.runInNewContext(source, {window, document, navigator, performance: {now: () => now},
    setInterval: fn => { timers.push(fn); return timers.length; }, clearInterval() {}});
  const api = window.arrowheadTriggers;
  return {api, document, device, reports, events, navigator,
    hook(fn) { sendHook = fn; },
    advance(ms) { now += ms; timers.forEach(fn => fn()); },
    expire() { this.advance(1200); },
    async connect() {
      api.showConnect();
      const button = nodes.find(n => n.tag === 'button' && n.textContent === 'Connect DualSense');
      if (button) button.onclick({currentTarget: button});
      await settle();
    },
  };
}

function forces(report, offset = 0, left = false) {
  offset += left ? 11 : 0;
  const data = Uint8Array.from(report.data);
  const view = new DataView(data.buffer);
  const mask = view.getUint16(offset + 11, true);
  const packed = view.getUint32(offset + 13, true);
  return Array.from({length: 10}, (_, i) => mask & (1 << i) ? ((packed >>> (3 * i)) & 7) + 1 : 0);
}

(async () => {
  const usb = setup();
  await usb.connect();
  assert(usb.api.ready, 'USB connection not ready');
  usb.api.bow(.65);
  await settle();
  let report = usb.reports.at(-1);
  assert.equal(report.id, 0x02);
  assert.equal(report.data.length, 47);
  assert.equal(report.data[0], 0x0c, 'Must enable both trigger effect writes');
  assert.equal(report.data[10], 0x21);
  assert.deepEqual(forces(report), [0, 2, 3, 3, 4, 5, 5, 5, 5, 5], 'Bow should build through the trigger travel');
  assert(report.data.slice(1, 10).every(n => n === 0));
  assert.equal(report.data[21], 0x05, 'Drawing must leave L2 free');
  assert(report.data.slice(22).every(n => n === 0), 'Drawing must not change other outputs');
  usb.api.bow(1);
  await settle();
  assert.deepEqual(forces(usb.reports.at(-1)), [0, 3, 4, 5, 6, 7, 8, 8, 8, 8]);
  assert.equal(forces(usb.reports.at(-1))[9], 8, 'Trigger must hold tension through the final zone until the 95% input threshold');
  usb.api.kick(1);
  await settle();
  report = usb.reports.at(-1);
  assert.deepEqual(report.data.slice(10, 14), [0x06, 10, 255, 20], 'Shot must start automatic trigger vibration immediately');
  assert.deepEqual(report.data.slice(21, 32), report.data.slice(10, 21), 'L2 must receive the same direct kick');
  assert(report.data.slice(1, 10).every(n => n === 0));
  assert(report.data.slice(32).every(n => n === 0), 'Kick must not change lights, motors or mic');
  usb.advance(100);
  usb.api.kick(1);
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x06);
  usb.advance(159);
  usb.api.kick(1);
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x06);
  usb.advance(1);
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x05, 'Repeated kick commands must not extend the 260 ms burst');
  assert.equal(usb.reports.at(-1).data[21], 0x05);
  usb.api.kick(1);
  await settle();
  usb.api.bow(1);
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x21, 'Equal-strength effect change was lost');
  assert.equal(usb.reports.at(-1).data[21], 0x05, 'L2 must also return to neutral');
  usb.api.bow(0);
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x05, 'Release must reset trigger to neutral');
  assert.equal(usb.reports.at(-1).data[21], 0x05, 'L2 must also return to neutral');
  usb.api.kick(1);
  await settle();
  usb.events.blur();
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x05, 'Blur must release');
  assert.equal(usb.reports.at(-1).data[21], 0x05, 'L2 must also return to neutral');
  usb.advance(300);
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x05, 'Cancelled impact must not start a deferred pulse');
  usb.api.bow(.65);
  await settle();
  usb.expire();
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x05, 'Expired heartbeat must release');
  assert.equal(usb.reports.at(-1).data[21], 0x05, 'L2 must also return to neutral');
  usb.api.kick(.5);
  await settle();
  assert.equal(usb.reports.at(-1).data[12], 128, 'Direct vibration must respect the strength setting');
  usb.advance(80);
  await settle();
  assert.equal(usb.reports.at(-1).data[23], 128, 'L2 must respect the strength setting');
  usb.api.bow(0);
  await settle();
  usb.api.kick(1);
  await settle();
  const beforeStall = usb.reports.length;
  usb.advance(500);
  await settle();
  assert(usb.reports.slice(beforeStall).every(r => r.data[10] === 0x05), 'A stalled frame must not start an overdue pulse');
  usb.document.hidden = true;
  const count = usb.reports.length;
  usb.api.bow(1);
  await settle();
  assert.equal(usb.reports.length, count, 'Hidden page must not re-arm');
  usb.document.hidden = false;
  let finish;
  usb.hook(() => new Promise(resolve => { finish = resolve; }));
  usb.api.bow(.65);
  await settle();
  usb.api.kick(1);
  usb.api.bow(0);
  usb.hook(null);
  finish();
  await settle();
  assert.equal(usb.reports.at(-1).data[10], 0x05, 'A pending bow write must not follow reset');
  assert.equal(usb.reports.at(-1).data[21], 0x05, 'L2 must also return to neutral');
  await usb.api.shutdown();
  assert(!usb.device.opened);

  const bt = setup({bluetooth: true});
  await bt.connect();
  bt.api.bow(.65);
  await settle();
  report = bt.reports.at(-1);
  assert.equal(report.id, 0x31);
  assert.equal(report.data.length, 77);
  assert.equal(report.data[0], 0x10);
  assert.equal(report.data[1], 0x10);
  assert.deepEqual(forces(report, 2), [0, 2, 3, 3, 4, 5, 5, 5, 5, 5]);
  assert.equal(Buffer.from(report.data).readUInt32LE(73), 0x57ba71c6, 'Bluetooth CRC fixture');
  bt.api.kick(1);
  await settle();
  report = bt.reports.at(-1);
  assert.deepEqual(report.data.slice(12, 16), [0x06, 10, 255, 20]);
  assert.deepEqual(report.data.slice(23, 34), report.data.slice(12, 23));
  assert.equal(Buffer.from(report.data).readUInt32LE(73), 0x9234cdb1, 'Bluetooth automatic-trigger CRC fixture');
  bt.events.disconnect({device: bt.device});
  assert(!bt.api.ready);
  await bt.api.shutdown();

  for (const options of [{hid: false}, {policy: false}, {denied: true}]) {
    const blocked = setup(options);
    await blocked.connect();
    blocked.api.bow(1);
    await settle();
    assert(!blocked.api.ready);
    assert.equal(blocked.reports.length, 0);
    await blocked.api.shutdown();
  }
  const lost = setup();
  await lost.connect();
  lost.hook(() => { throw Error('disconnected'); });
  lost.api.bow(.65);
  await settle();
  assert(!lost.api.ready);
  assert(!lost.device.opened);
  await lost.api.shutdown();
  console.log('PASS: adaptive trigger USB/Bluetooth encoding, bow curve, paired kick, CRC, release, focus, watchdog, pending writes and unsupported/denied access');
})().catch(error => { console.error(error); process.exitCode = 1; });
