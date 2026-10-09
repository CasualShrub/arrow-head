const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../scripts/singletons/controller_manager.gd'), 'utf8');
const bridge = source.split('const WEB_HAPTICS := """')[1].split('"""')[0];
const settle = () => new Promise(resolve => setImmediate(resolve));

function setup(actuator, denied = false) {
 const context = {window: {}, document: {hidden: false}, navigator: {
  getGamepads() {
   if (denied) throw new Error('Permission denied');
   return [null, null, {vibrationActuator: actuator}];
  }
 }};
 vm.runInNewContext(bridge, context);
 return {haptics: context.window.arrowheadHaptics, document: context.document};
}

(async () => {
 const calls = [];
 let resets = 0;
 const actuator = {effects: ['dual-rumble'], playEffect(type, parameters) {
  calls.push({type, parameters});
  return Promise.resolve('complete');
 }, reset() {resets++; return Promise.resolve();}};
 const {haptics, document} = setup(actuator);
 haptics.play(2, 0.3, 0.7, 160, 0.75);
 assert.equal(calls[0].type, 'dual-rumble');
 assert.equal(calls[0].parameters.strongMagnitude, 0.7);
 assert.equal(calls[0].parameters.duration, 160);
 actuator.effects.push('trigger-rumble');
 haptics.play(2, 0.3, 0.7, 160, 0.75);
 assert.equal(calls[1].type, 'trigger-rumble');
 assert.equal(calls[1].parameters.rightTrigger, 0.75);
 assert.equal(calls[1].parameters.leftTrigger, 0.75);
 haptics.stop(2);
 assert.equal(resets, 1);
 document.hidden = true;
 haptics.play(2, 1, 1, 100, 1);
 assert.equal(calls.length, 2);

 calls.length = 0;
 const unsupported = setup({effects: ['trigger-rumble'], playEffect(type) {
  calls.push(type);
  return type === 'trigger-rumble' ? Promise.reject(new Error('Unsupported')) : Promise.resolve();
 }}).haptics;
 unsupported.play(2, 1, 1, 100, 1);
 await settle();
 assert.deepEqual(calls, ['trigger-rumble', 'dual-rumble']);
 calls.length = 0;
 unsupported.play(2, 1, 1, 100, 1);
 unsupported.stop(2);
 await settle();
 assert.deepEqual(calls, ['trigger-rumble']);

 const blocked = setup(null, true).haptics;
 blocked.play(2, 1, 1, 100, 1);
 blocked.stop(2);
 const missing = setup(null).haptics;
 missing.play(2, 1, 1, 100, 1);
 await settle();
 console.log('PASS: browser rumble, trigger fallback, cancellation, missing devices and denied permissions');
})().catch(error => {console.error(error); process.exitCode = 1;});
