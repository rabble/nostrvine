var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/_internal/utils.mjs
// @__NO_SIDE_EFFECTS__
function createNotImplementedError(name) {
  return new Error(`[unenv] ${name} is not implemented yet!`);
}
__name(createNotImplementedError, "createNotImplementedError");
// @__NO_SIDE_EFFECTS__
function notImplemented(name) {
  const fn = /* @__PURE__ */ __name(() => {
    throw /* @__PURE__ */ createNotImplementedError(name);
  }, "fn");
  return Object.assign(fn, { __unenv__: true });
}
__name(notImplemented, "notImplemented");
// @__NO_SIDE_EFFECTS__
function notImplementedClass(name) {
  return class {
    __unenv__ = true;
    constructor() {
      throw new Error(`[unenv] ${name} is not implemented yet!`);
    }
  };
}
__name(notImplementedClass, "notImplementedClass");

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/perf_hooks/performance.mjs
var _timeOrigin = globalThis.performance?.timeOrigin ?? Date.now();
var _performanceNow = globalThis.performance?.now ? globalThis.performance.now.bind(globalThis.performance) : () => Date.now() - _timeOrigin;
var nodeTiming = {
  name: "node",
  entryType: "node",
  startTime: 0,
  duration: 0,
  nodeStart: 0,
  v8Start: 0,
  bootstrapComplete: 0,
  environment: 0,
  loopStart: 0,
  loopExit: 0,
  idleTime: 0,
  uvMetricsInfo: {
    loopCount: 0,
    events: 0,
    eventsWaiting: 0
  },
  detail: void 0,
  toJSON() {
    return this;
  }
};
var PerformanceEntry = class {
  static {
    __name(this, "PerformanceEntry");
  }
  __unenv__ = true;
  detail;
  entryType = "event";
  name;
  startTime;
  constructor(name, options) {
    this.name = name;
    this.startTime = options?.startTime || _performanceNow();
    this.detail = options?.detail;
  }
  get duration() {
    return _performanceNow() - this.startTime;
  }
  toJSON() {
    return {
      name: this.name,
      entryType: this.entryType,
      startTime: this.startTime,
      duration: this.duration,
      detail: this.detail
    };
  }
};
var PerformanceMark = class PerformanceMark2 extends PerformanceEntry {
  static {
    __name(this, "PerformanceMark");
  }
  entryType = "mark";
  constructor() {
    super(...arguments);
  }
  get duration() {
    return 0;
  }
};
var PerformanceMeasure = class extends PerformanceEntry {
  static {
    __name(this, "PerformanceMeasure");
  }
  entryType = "measure";
};
var PerformanceResourceTiming = class extends PerformanceEntry {
  static {
    __name(this, "PerformanceResourceTiming");
  }
  entryType = "resource";
  serverTiming = [];
  connectEnd = 0;
  connectStart = 0;
  decodedBodySize = 0;
  domainLookupEnd = 0;
  domainLookupStart = 0;
  encodedBodySize = 0;
  fetchStart = 0;
  initiatorType = "";
  name = "";
  nextHopProtocol = "";
  redirectEnd = 0;
  redirectStart = 0;
  requestStart = 0;
  responseEnd = 0;
  responseStart = 0;
  secureConnectionStart = 0;
  startTime = 0;
  transferSize = 0;
  workerStart = 0;
  responseStatus = 0;
};
var PerformanceObserverEntryList = class {
  static {
    __name(this, "PerformanceObserverEntryList");
  }
  __unenv__ = true;
  getEntries() {
    return [];
  }
  getEntriesByName(_name, _type) {
    return [];
  }
  getEntriesByType(type) {
    return [];
  }
};
var Performance = class {
  static {
    __name(this, "Performance");
  }
  __unenv__ = true;
  timeOrigin = _timeOrigin;
  eventCounts = /* @__PURE__ */ new Map();
  _entries = [];
  _resourceTimingBufferSize = 0;
  navigation = void 0;
  timing = void 0;
  timerify(_fn, _options) {
    throw createNotImplementedError("Performance.timerify");
  }
  get nodeTiming() {
    return nodeTiming;
  }
  eventLoopUtilization() {
    return {};
  }
  markResourceTiming() {
    return new PerformanceResourceTiming("");
  }
  onresourcetimingbufferfull = null;
  now() {
    if (this.timeOrigin === _timeOrigin) {
      return _performanceNow();
    }
    return Date.now() - this.timeOrigin;
  }
  clearMarks(markName) {
    this._entries = markName ? this._entries.filter((e) => e.name !== markName) : this._entries.filter((e) => e.entryType !== "mark");
  }
  clearMeasures(measureName) {
    this._entries = measureName ? this._entries.filter((e) => e.name !== measureName) : this._entries.filter((e) => e.entryType !== "measure");
  }
  clearResourceTimings() {
    this._entries = this._entries.filter((e) => e.entryType !== "resource" || e.entryType !== "navigation");
  }
  getEntries() {
    return this._entries;
  }
  getEntriesByName(name, type) {
    return this._entries.filter((e) => e.name === name && (!type || e.entryType === type));
  }
  getEntriesByType(type) {
    return this._entries.filter((e) => e.entryType === type);
  }
  mark(name, options) {
    const entry = new PerformanceMark(name, options);
    this._entries.push(entry);
    return entry;
  }
  measure(measureName, startOrMeasureOptions, endMark) {
    let start;
    let end;
    if (typeof startOrMeasureOptions === "string") {
      start = this.getEntriesByName(startOrMeasureOptions, "mark")[0]?.startTime;
      end = this.getEntriesByName(endMark, "mark")[0]?.startTime;
    } else {
      start = Number.parseFloat(startOrMeasureOptions?.start) || this.now();
      end = Number.parseFloat(startOrMeasureOptions?.end) || this.now();
    }
    const entry = new PerformanceMeasure(measureName, {
      startTime: start,
      detail: {
        start,
        end
      }
    });
    this._entries.push(entry);
    return entry;
  }
  setResourceTimingBufferSize(maxSize) {
    this._resourceTimingBufferSize = maxSize;
  }
  addEventListener(type, listener, options) {
    throw createNotImplementedError("Performance.addEventListener");
  }
  removeEventListener(type, listener, options) {
    throw createNotImplementedError("Performance.removeEventListener");
  }
  dispatchEvent(event) {
    throw createNotImplementedError("Performance.dispatchEvent");
  }
  toJSON() {
    return this;
  }
};
var PerformanceObserver = class {
  static {
    __name(this, "PerformanceObserver");
  }
  __unenv__ = true;
  static supportedEntryTypes = [];
  _callback = null;
  constructor(callback) {
    this._callback = callback;
  }
  takeRecords() {
    return [];
  }
  disconnect() {
    throw createNotImplementedError("PerformanceObserver.disconnect");
  }
  observe(options) {
    throw createNotImplementedError("PerformanceObserver.observe");
  }
  bind(fn) {
    return fn;
  }
  runInAsyncScope(fn, thisArg, ...args) {
    return fn.call(thisArg, ...args);
  }
  asyncId() {
    return 0;
  }
  triggerAsyncId() {
    return 0;
  }
  emitDestroy() {
    return this;
  }
};
var performance = globalThis.performance && "addEventListener" in globalThis.performance ? globalThis.performance : new Performance();

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/@cloudflare/unenv-preset/dist/runtime/polyfill/performance.mjs
globalThis.performance = performance;
globalThis.Performance = Performance;
globalThis.PerformanceEntry = PerformanceEntry;
globalThis.PerformanceMark = PerformanceMark;
globalThis.PerformanceMeasure = PerformanceMeasure;
globalThis.PerformanceObserver = PerformanceObserver;
globalThis.PerformanceObserverEntryList = PerformanceObserverEntryList;
globalThis.PerformanceResourceTiming = PerformanceResourceTiming;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/console.mjs
import { Writable } from "node:stream";

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/mock/noop.mjs
var noop_default = Object.assign(() => {
}, { __unenv__: true });

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/console.mjs
var _console = globalThis.console;
var _ignoreErrors = true;
var _stderr = new Writable();
var _stdout = new Writable();
var log = _console?.log ?? noop_default;
var info = _console?.info ?? log;
var trace = _console?.trace ?? info;
var debug = _console?.debug ?? log;
var table = _console?.table ?? log;
var error = _console?.error ?? log;
var warn = _console?.warn ?? error;
var createTask = _console?.createTask ?? /* @__PURE__ */ notImplemented("console.createTask");
var clear = _console?.clear ?? noop_default;
var count = _console?.count ?? noop_default;
var countReset = _console?.countReset ?? noop_default;
var dir = _console?.dir ?? noop_default;
var dirxml = _console?.dirxml ?? noop_default;
var group = _console?.group ?? noop_default;
var groupEnd = _console?.groupEnd ?? noop_default;
var groupCollapsed = _console?.groupCollapsed ?? noop_default;
var profile = _console?.profile ?? noop_default;
var profileEnd = _console?.profileEnd ?? noop_default;
var time = _console?.time ?? noop_default;
var timeEnd = _console?.timeEnd ?? noop_default;
var timeLog = _console?.timeLog ?? noop_default;
var timeStamp = _console?.timeStamp ?? noop_default;
var Console = _console?.Console ?? /* @__PURE__ */ notImplementedClass("console.Console");
var _times = /* @__PURE__ */ new Map();
var _stdoutErrorHandler = noop_default;
var _stderrErrorHandler = noop_default;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/@cloudflare/unenv-preset/dist/runtime/node/console.mjs
var workerdConsole = globalThis["console"];
var {
  assert,
  clear: clear2,
  // @ts-expect-error undocumented public API
  context,
  count: count2,
  countReset: countReset2,
  // @ts-expect-error undocumented public API
  createTask: createTask2,
  debug: debug2,
  dir: dir2,
  dirxml: dirxml2,
  error: error2,
  group: group2,
  groupCollapsed: groupCollapsed2,
  groupEnd: groupEnd2,
  info: info2,
  log: log2,
  profile: profile2,
  profileEnd: profileEnd2,
  table: table2,
  time: time2,
  timeEnd: timeEnd2,
  timeLog: timeLog2,
  timeStamp: timeStamp2,
  trace: trace2,
  warn: warn2
} = workerdConsole;
Object.assign(workerdConsole, {
  Console,
  _ignoreErrors,
  _stderr,
  _stderrErrorHandler,
  _stdout,
  _stdoutErrorHandler,
  _times
});
var console_default = workerdConsole;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/_virtual_unenv_global_polyfill-@cloudflare-unenv-preset-node-console
globalThis.console = console_default;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/process/hrtime.mjs
var hrtime = /* @__PURE__ */ Object.assign(/* @__PURE__ */ __name(function hrtime2(startTime) {
  const now = Date.now();
  const seconds = Math.trunc(now / 1e3);
  const nanos = now % 1e3 * 1e6;
  if (startTime) {
    let diffSeconds = seconds - startTime[0];
    let diffNanos = nanos - startTime[0];
    if (diffNanos < 0) {
      diffSeconds = diffSeconds - 1;
      diffNanos = 1e9 + diffNanos;
    }
    return [diffSeconds, diffNanos];
  }
  return [seconds, nanos];
}, "hrtime"), { bigint: /* @__PURE__ */ __name(function bigint() {
  return BigInt(Date.now() * 1e6);
}, "bigint") });

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/process/process.mjs
import { EventEmitter } from "node:events";

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/tty/write-stream.mjs
var WriteStream = class {
  static {
    __name(this, "WriteStream");
  }
  fd;
  columns = 80;
  rows = 24;
  isTTY = false;
  constructor(fd) {
    this.fd = fd;
  }
  clearLine(dir3, callback) {
    callback && callback();
    return false;
  }
  clearScreenDown(callback) {
    callback && callback();
    return false;
  }
  cursorTo(x, y, callback) {
    callback && typeof callback === "function" && callback();
    return false;
  }
  moveCursor(dx, dy, callback) {
    callback && callback();
    return false;
  }
  getColorDepth(env2) {
    return 1;
  }
  hasColors(count3, env2) {
    return false;
  }
  getWindowSize() {
    return [this.columns, this.rows];
  }
  write(str, encoding, cb) {
    if (str instanceof Uint8Array) {
      str = new TextDecoder().decode(str);
    }
    try {
      console.log(str);
    } catch {
    }
    cb && typeof cb === "function" && cb();
    return false;
  }
};

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/tty/read-stream.mjs
var ReadStream = class {
  static {
    __name(this, "ReadStream");
  }
  fd;
  isRaw = false;
  isTTY = false;
  constructor(fd) {
    this.fd = fd;
  }
  setRawMode(mode) {
    this.isRaw = mode;
    return this;
  }
};

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/process/node-version.mjs
var NODE_VERSION = "22.14.0";

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/unenv/dist/runtime/node/internal/process/process.mjs
var Process = class _Process extends EventEmitter {
  static {
    __name(this, "Process");
  }
  env;
  hrtime;
  nextTick;
  constructor(impl) {
    super();
    this.env = impl.env;
    this.hrtime = impl.hrtime;
    this.nextTick = impl.nextTick;
    for (const prop of [...Object.getOwnPropertyNames(_Process.prototype), ...Object.getOwnPropertyNames(EventEmitter.prototype)]) {
      const value = this[prop];
      if (typeof value === "function") {
        this[prop] = value.bind(this);
      }
    }
  }
  emitWarning(warning, type, code) {
    console.warn(`${code ? `[${code}] ` : ""}${type ? `${type}: ` : ""}${warning}`);
  }
  emit(...args) {
    return super.emit(...args);
  }
  listeners(eventName) {
    return super.listeners(eventName);
  }
  #stdin;
  #stdout;
  #stderr;
  get stdin() {
    return this.#stdin ??= new ReadStream(0);
  }
  get stdout() {
    return this.#stdout ??= new WriteStream(1);
  }
  get stderr() {
    return this.#stderr ??= new WriteStream(2);
  }
  #cwd = "/";
  chdir(cwd2) {
    this.#cwd = cwd2;
  }
  cwd() {
    return this.#cwd;
  }
  arch = "";
  platform = "";
  argv = [];
  argv0 = "";
  execArgv = [];
  execPath = "";
  title = "";
  pid = 200;
  ppid = 100;
  get version() {
    return `v${NODE_VERSION}`;
  }
  get versions() {
    return { node: NODE_VERSION };
  }
  get allowedNodeEnvironmentFlags() {
    return /* @__PURE__ */ new Set();
  }
  get sourceMapsEnabled() {
    return false;
  }
  get debugPort() {
    return 0;
  }
  get throwDeprecation() {
    return false;
  }
  get traceDeprecation() {
    return false;
  }
  get features() {
    return {};
  }
  get release() {
    return {};
  }
  get connected() {
    return false;
  }
  get config() {
    return {};
  }
  get moduleLoadList() {
    return [];
  }
  constrainedMemory() {
    return 0;
  }
  availableMemory() {
    return 0;
  }
  uptime() {
    return 0;
  }
  resourceUsage() {
    return {};
  }
  ref() {
  }
  unref() {
  }
  umask() {
    throw createNotImplementedError("process.umask");
  }
  getBuiltinModule() {
    return void 0;
  }
  getActiveResourcesInfo() {
    throw createNotImplementedError("process.getActiveResourcesInfo");
  }
  exit() {
    throw createNotImplementedError("process.exit");
  }
  reallyExit() {
    throw createNotImplementedError("process.reallyExit");
  }
  kill() {
    throw createNotImplementedError("process.kill");
  }
  abort() {
    throw createNotImplementedError("process.abort");
  }
  dlopen() {
    throw createNotImplementedError("process.dlopen");
  }
  setSourceMapsEnabled() {
    throw createNotImplementedError("process.setSourceMapsEnabled");
  }
  loadEnvFile() {
    throw createNotImplementedError("process.loadEnvFile");
  }
  disconnect() {
    throw createNotImplementedError("process.disconnect");
  }
  cpuUsage() {
    throw createNotImplementedError("process.cpuUsage");
  }
  setUncaughtExceptionCaptureCallback() {
    throw createNotImplementedError("process.setUncaughtExceptionCaptureCallback");
  }
  hasUncaughtExceptionCaptureCallback() {
    throw createNotImplementedError("process.hasUncaughtExceptionCaptureCallback");
  }
  initgroups() {
    throw createNotImplementedError("process.initgroups");
  }
  openStdin() {
    throw createNotImplementedError("process.openStdin");
  }
  assert() {
    throw createNotImplementedError("process.assert");
  }
  binding() {
    throw createNotImplementedError("process.binding");
  }
  permission = { has: /* @__PURE__ */ notImplemented("process.permission.has") };
  report = {
    directory: "",
    filename: "",
    signal: "SIGUSR2",
    compact: false,
    reportOnFatalError: false,
    reportOnSignal: false,
    reportOnUncaughtException: false,
    getReport: /* @__PURE__ */ notImplemented("process.report.getReport"),
    writeReport: /* @__PURE__ */ notImplemented("process.report.writeReport")
  };
  finalization = {
    register: /* @__PURE__ */ notImplemented("process.finalization.register"),
    unregister: /* @__PURE__ */ notImplemented("process.finalization.unregister"),
    registerBeforeExit: /* @__PURE__ */ notImplemented("process.finalization.registerBeforeExit")
  };
  memoryUsage = Object.assign(() => ({
    arrayBuffers: 0,
    rss: 0,
    external: 0,
    heapTotal: 0,
    heapUsed: 0
  }), { rss: /* @__PURE__ */ __name(() => 0, "rss") });
  mainModule = void 0;
  domain = void 0;
  send = void 0;
  exitCode = void 0;
  channel = void 0;
  getegid = void 0;
  geteuid = void 0;
  getgid = void 0;
  getgroups = void 0;
  getuid = void 0;
  setegid = void 0;
  seteuid = void 0;
  setgid = void 0;
  setgroups = void 0;
  setuid = void 0;
  _events = void 0;
  _eventsCount = void 0;
  _exiting = void 0;
  _maxListeners = void 0;
  _debugEnd = void 0;
  _debugProcess = void 0;
  _fatalException = void 0;
  _getActiveHandles = void 0;
  _getActiveRequests = void 0;
  _kill = void 0;
  _preload_modules = void 0;
  _rawDebug = void 0;
  _startProfilerIdleNotifier = void 0;
  _stopProfilerIdleNotifier = void 0;
  _tickCallback = void 0;
  _disconnect = void 0;
  _handleQueue = void 0;
  _pendingMessage = void 0;
  _channel = void 0;
  _send = void 0;
  _linkedBinding = void 0;
};

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/node_modules/@cloudflare/unenv-preset/dist/runtime/node/process.mjs
var globalProcess = globalThis["process"];
var getBuiltinModule = globalProcess.getBuiltinModule;
var { exit, platform, nextTick } = getBuiltinModule(
  "node:process"
);
var unenvProcess = new Process({
  env: globalProcess.env,
  hrtime,
  nextTick
});
var {
  abort,
  addListener,
  allowedNodeEnvironmentFlags,
  hasUncaughtExceptionCaptureCallback,
  setUncaughtExceptionCaptureCallback,
  loadEnvFile,
  sourceMapsEnabled,
  arch,
  argv,
  argv0,
  chdir,
  config,
  connected,
  constrainedMemory,
  availableMemory,
  cpuUsage,
  cwd,
  debugPort,
  dlopen,
  disconnect,
  emit,
  emitWarning,
  env,
  eventNames,
  execArgv,
  execPath,
  finalization,
  features,
  getActiveResourcesInfo,
  getMaxListeners,
  hrtime: hrtime3,
  kill,
  listeners,
  listenerCount,
  memoryUsage,
  on,
  off,
  once,
  pid,
  ppid,
  prependListener,
  prependOnceListener,
  rawListeners,
  release,
  removeAllListeners,
  removeListener,
  report,
  resourceUsage,
  setMaxListeners,
  setSourceMapsEnabled,
  stderr,
  stdin,
  stdout,
  title,
  throwDeprecation,
  traceDeprecation,
  umask,
  uptime,
  version,
  versions,
  domain,
  initgroups,
  moduleLoadList,
  reallyExit,
  openStdin,
  assert: assert2,
  binding,
  send,
  exitCode,
  channel,
  getegid,
  geteuid,
  getgid,
  getgroups,
  getuid,
  setegid,
  seteuid,
  setgid,
  setgroups,
  setuid,
  permission,
  mainModule,
  _events,
  _eventsCount,
  _exiting,
  _maxListeners,
  _debugEnd,
  _debugProcess,
  _fatalException,
  _getActiveHandles,
  _getActiveRequests,
  _kill,
  _preload_modules,
  _rawDebug,
  _startProfilerIdleNotifier,
  _stopProfilerIdleNotifier,
  _tickCallback,
  _disconnect,
  _handleQueue,
  _pendingMessage,
  _channel,
  _send,
  _linkedBinding
} = unenvProcess;
var _process = {
  abort,
  addListener,
  allowedNodeEnvironmentFlags,
  hasUncaughtExceptionCaptureCallback,
  setUncaughtExceptionCaptureCallback,
  loadEnvFile,
  sourceMapsEnabled,
  arch,
  argv,
  argv0,
  chdir,
  config,
  connected,
  constrainedMemory,
  availableMemory,
  cpuUsage,
  cwd,
  debugPort,
  dlopen,
  disconnect,
  emit,
  emitWarning,
  env,
  eventNames,
  execArgv,
  execPath,
  exit,
  finalization,
  features,
  getBuiltinModule,
  getActiveResourcesInfo,
  getMaxListeners,
  hrtime: hrtime3,
  kill,
  listeners,
  listenerCount,
  memoryUsage,
  nextTick,
  on,
  off,
  once,
  pid,
  platform,
  ppid,
  prependListener,
  prependOnceListener,
  rawListeners,
  release,
  removeAllListeners,
  removeListener,
  report,
  resourceUsage,
  setMaxListeners,
  setSourceMapsEnabled,
  stderr,
  stdin,
  stdout,
  title,
  throwDeprecation,
  traceDeprecation,
  umask,
  uptime,
  version,
  versions,
  // @ts-expect-error old API
  domain,
  initgroups,
  moduleLoadList,
  reallyExit,
  openStdin,
  assert: assert2,
  binding,
  send,
  exitCode,
  channel,
  getegid,
  geteuid,
  getgid,
  getgroups,
  getuid,
  setegid,
  seteuid,
  setgid,
  setgroups,
  setuid,
  permission,
  mainModule,
  _events,
  _eventsCount,
  _exiting,
  _maxListeners,
  _debugEnd,
  _debugProcess,
  _fatalException,
  _getActiveHandles,
  _getActiveRequests,
  _kill,
  _preload_modules,
  _rawDebug,
  _startProfilerIdleNotifier,
  _stopProfilerIdleNotifier,
  _tickCallback,
  _disconnect,
  _handleQueue,
  _pendingMessage,
  _channel,
  _send,
  _linkedBinding
};
var process_default = _process;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/_virtual_unenv_global_polyfill-@cloudflare-unenv-preset-node-process
globalThis.process = process_default;

// src/handlers/viewTracking.ts
async function handleViewTracking(request, env2) {
  try {
    const body = await request.json();
    const { eventId, source = "web", creatorPubkey } = body;
    if (!eventId || !/^[a-f0-9]{64}$/i.test(eventId)) {
      return new Response(
        JSON.stringify({ error: "Invalid event ID" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
    const rateLimitKey = `rate:${hashIP(clientIP)}`;
    const rateLimitData = await env2.ANALYTICS_KV.get(rateLimitKey);
    if (rateLimitData) {
      const { count: count3, windowStart } = JSON.parse(rateLimitData);
      const now = Date.now();
      const windowAge = now - windowStart;
      if (windowAge < 6e4 && count3 >= 5) {
        return new Response(
          JSON.stringify({ error: "Rate limit exceeded" }),
          { status: 429, headers: { "Content-Type": "application/json" } }
        );
      }
      if (windowAge >= 6e4) {
        await env2.ANALYTICS_KV.put(
          rateLimitKey,
          JSON.stringify({ count: 1, windowStart: now }),
          { expirationTtl: 120 }
          // 2 minute TTL
        );
      } else {
        await env2.ANALYTICS_KV.put(
          rateLimitKey,
          JSON.stringify({ count: count3 + 1, windowStart }),
          { expirationTtl: 120 }
        );
      }
    } else {
      await env2.ANALYTICS_KV.put(
        rateLimitKey,
        JSON.stringify({ count: 1, windowStart: Date.now() }),
        { expirationTtl: 120 }
      );
    }
    const viewKey = `views:${eventId}`;
    const currentData = await env2.ANALYTICS_KV.get(viewKey, "json");
    const newCount = (currentData?.count || 0) + 1;
    const viewData = {
      count: newCount,
      lastUpdate: Date.now()
    };
    await env2.ANALYTICS_KV.put(viewKey, JSON.stringify(viewData));
    if (creatorPubkey && /^[a-f0-9]{64}$/i.test(creatorPubkey)) {
      await updateCreatorMetrics(env2, creatorPubkey, eventId);
    }
    console.log(`View recorded: ${eventId} from ${source}, total views: ${newCount}`);
    return new Response(
      JSON.stringify({
        success: true,
        eventId,
        views: newCount
        // Future: could return personalized recommendations if user opts in
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-cache",
          "Access-Control-Allow-Origin": "*"
        }
      }
    );
  } catch (error3) {
    console.error("View tracking error:", error3);
    return new Response(
      JSON.stringify({ error: "Failed to track view" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
__name(handleViewTracking, "handleViewTracking");
function hashIP(ip) {
  let hash = 0;
  for (let i = 0; i < ip.length; i++) {
    const char = ip.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash;
  }
  return Math.abs(hash).toString(36);
}
__name(hashIP, "hashIP");
async function updateCreatorMetrics(env2, creatorPubkey, eventId) {
  try {
    const creatorKey = `creator:${creatorPubkey}`;
    const currentData = await env2.ANALYTICS_KV.get(creatorKey, "json");
    const videoSetKey = `creator-videos:${creatorPubkey}`;
    const existingVideos = await env2.ANALYTICS_KV.get(videoSetKey);
    let videoIds = existingVideos ? JSON.parse(existingVideos) : [];
    const isNewVideo = !videoIds.includes(eventId);
    if (isNewVideo) {
      videoIds.push(eventId);
      await env2.ANALYTICS_KV.put(videoSetKey, JSON.stringify(videoIds));
    }
    const creatorData = {
      totalViews: (currentData?.totalViews || 0) + 1,
      videoCount: videoIds.length,
      lastUpdate: Date.now()
    };
    await env2.ANALYTICS_KV.put(creatorKey, JSON.stringify(creatorData));
    console.log(`Creator metrics updated: ${creatorPubkey.substring(0, 8)}... - ${creatorData.totalViews} total views, ${creatorData.videoCount} videos`);
  } catch (error3) {
    console.error("Failed to update creator metrics:", error3);
  }
}
__name(updateCreatorMetrics, "updateCreatorMetrics");

// src/services/trendingCalculator.ts
function calculateTrendingScore(viewData, currentTime) {
  const ageHours = (currentTime - viewData.lastUpdate) / (1e3 * 60 * 60);
  return viewData.count / (ageHours + 1);
}
__name(calculateTrendingScore, "calculateTrendingScore");
async function calculateTrending(env2) {
  const minViews = parseInt(env2.MIN_VIEWS_FOR_TRENDING || "10");
  const videos = [];
  try {
    const list = await env2.ANALYTICS_KV.list({ prefix: "views:", limit: 1e3 });
    for (const key of list.keys) {
      const eventId = key.name.replace("views:", "");
      const viewData = await env2.ANALYTICS_KV.get(key.name, "json");
      if (!viewData || viewData.count < minViews) {
        continue;
      }
      const score = calculateTrendingScore(viewData, Date.now());
      videos.push({
        eventId,
        views: viewData.count,
        score
        // Future: fetch title and hashtags from Nostr or cache
      });
    }
    videos.sort((a, b) => b.score - a.score);
    const trending = {
      videos: videos.slice(0, 20),
      updatedAt: Date.now()
    };
    await env2.ANALYTICS_KV.put(
      "trending:videos",
      JSON.stringify(trending),
      { expirationTtl: 300 }
      // 5 minute cache
    );
    console.log(`Trending calculated: ${trending.videos.length} videos`);
    return trending;
  } catch (error3) {
    console.error("Trending calculation error:", error3);
    return {
      videos: [],
      updatedAt: Date.now()
    };
  }
}
__name(calculateTrending, "calculateTrending");
async function getTrending(env2) {
  const cached = await env2.ANALYTICS_KV.get("trending:videos", "json");
  if (cached) {
    const age = Date.now() - cached.updatedAt;
    const maxAge = parseInt(env2.TRENDING_UPDATE_INTERVAL || "300") * 1e3;
    if (age < maxAge) {
      return cached;
    }
  }
  return calculateTrending(env2);
}
__name(getTrending, "getTrending");

// src/handlers/trending.ts
async function handleTrending(request, env2) {
  try {
    const trending = await getTrending(env2);
    const url = new URL(request.url);
    const limit = parseInt(url.searchParams.get("limit") || "20");
    const limitedVideos = trending.videos.slice(0, Math.min(limit, 50));
    return new Response(
      JSON.stringify({
        videos: limitedVideos,
        updatedAt: trending.updatedAt,
        // Future: could include user preferences if authenticated
        algorithm: "global_popularity"
        // Identifies this as non-personalized
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "public, max-age=60",
          // Cache for 1 minute
          "Access-Control-Allow-Origin": "*"
        }
      }
    );
  } catch (error3) {
    console.error("Trending API error:", error3);
    return new Response(
      JSON.stringify({ error: "Failed to get trending videos" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
__name(handleTrending, "handleTrending");
async function handleVideoStats(request, env2, eventId) {
  try {
    if (!eventId || !/^[a-f0-9]{64}$/i.test(eventId)) {
      return new Response(
        JSON.stringify({ error: "Invalid event ID" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    const viewKey = `views:${eventId}`;
    const viewData = await env2.ANALYTICS_KV.get(viewKey, "json");
    if (!viewData) {
      return new Response(
        JSON.stringify({
          eventId,
          views: 0,
          lastUpdate: null
          // Future: could include personalized engagement data
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        }
      );
    }
    return new Response(
      JSON.stringify({
        eventId,
        ...viewData
        // Future: trending rank, hashtags, similar videos
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "public, max-age=30",
          "Access-Control-Allow-Origin": "*"
        }
      }
    );
  } catch (error3) {
    console.error("Video stats error:", error3);
    return new Response(
      JSON.stringify({ error: "Failed to get video stats" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
__name(handleVideoStats, "handleVideoStats");

// src/handlers/trendingVines.ts
async function handleTrendingVines(request, env2) {
  try {
    const url = new URL(request.url);
    const limit = Math.min(parseInt(url.searchParams.get("limit") || "20"), 100);
    const minViews = parseInt(env2.MIN_VIEWS_FOR_TRENDING);
    const { keys } = await env2.ANALYTICS_KV.list({ prefix: "views:" });
    const trendingVines = [];
    const now = Date.now();
    for (const key of keys) {
      const eventId = key.name.replace("views:", "");
      try {
        const viewDataStr = await env2.ANALYTICS_KV.get(key.name);
        if (!viewDataStr) continue;
        const viewData = JSON.parse(viewDataStr);
        if (viewData.count < minViews) continue;
        const score = calculateTrendingScore(viewData, now);
        trendingVines.push({
          eventId,
          views: viewData.count,
          score
          // Note: title and hashtags could be fetched from Nostr events in the future
        });
      } catch (error3) {
        console.warn(`Failed to process vine ${eventId}:`, error3);
        continue;
      }
    }
    const topVines = trendingVines.sort((a, b) => b.score - a.score).slice(0, limit);
    const response = {
      vines: topVines,
      algorithm: "global_popularity",
      updatedAt: now,
      period: "24h",
      // Could make this configurable
      totalVines: trendingVines.length
    };
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=300",
        // 5 minute cache
        "Access-Control-Allow-Origin": "*"
      }
    });
  } catch (error3) {
    console.error("Trending vines error:", error3);
    return new Response(
      JSON.stringify({
        error: "Failed to fetch trending vines",
        vines: [],
        updatedAt: Date.now()
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      }
    );
  }
}
__name(handleTrendingVines, "handleTrendingVines");

// src/handlers/trendingViners.ts
async function handleTrendingViners(request, env2) {
  try {
    const url = new URL(request.url);
    const limit = Math.min(parseInt(url.searchParams.get("limit") || "20"), 100);
    const minViews = parseInt(env2.MIN_VIEWS_FOR_TRENDING);
    const { keys } = await env2.ANALYTICS_KV.list({ prefix: "creator:" });
    const trendingViners = [];
    const now = Date.now();
    for (const key of keys) {
      const pubkey = key.name.replace("creator:", "");
      try {
        const creatorDataStr = await env2.ANALYTICS_KV.get(key.name);
        if (!creatorDataStr) continue;
        const creatorData = JSON.parse(creatorDataStr);
        if (creatorData.totalViews < minViews) continue;
        const avgViewsPerVideo = creatorData.videoCount > 0 ? creatorData.totalViews / creatorData.videoCount : 0;
        const ageHours = (now - creatorData.lastUpdate) / (1e3 * 60 * 60);
        const recencyBoost = 1 / (ageHours * 0.1 + 1);
        const score = (creatorData.totalViews * 0.7 + avgViewsPerVideo * 0.3) * recencyBoost;
        trendingViners.push({
          pubkey,
          totalViews: creatorData.totalViews,
          videoCount: creatorData.videoCount,
          score,
          avgViewsPerVideo: Math.round(avgViewsPerVideo * 100) / 100
          // Round to 2 decimals
          // Note: displayName could be fetched from Nostr profiles in the future
        });
      } catch (error3) {
        console.warn(`Failed to process viner ${pubkey.substring(0, 8)}:`, error3);
        continue;
      }
    }
    const topViners = trendingViners.sort((a, b) => b.score - a.score).slice(0, limit);
    const response = {
      viners: topViners,
      algorithm: "creator_engagement",
      updatedAt: now,
      period: "24h",
      // Could make this configurable
      totalViners: trendingViners.length,
      metrics: {
        minViews,
        avgVideosPerCreator: trendingViners.length > 0 ? Math.round(trendingViners.reduce((sum, v) => sum + v.videoCount, 0) / trendingViners.length * 100) / 100 : 0
      }
    };
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=300",
        // 5 minute cache
        "Access-Control-Allow-Origin": "*"
      }
    });
  } catch (error3) {
    console.error("Trending viners error:", error3);
    return new Response(
      JSON.stringify({
        error: "Failed to fetch trending viners",
        viners: [],
        updatedAt: Date.now()
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      }
    );
  }
}
__name(handleTrendingViners, "handleTrendingViners");

// src/index.ts
var src_default = {
  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Max-Age": "86400"
        }
      });
    }
    try {
      if (path === "/analytics/view" && request.method === "POST") {
        return handleViewTracking(request, env2);
      }
      if (path === "/analytics/trending/videos" && request.method === "GET") {
        return handleTrending(request, env2);
      }
      if (path === "/analytics/trending/vines" && request.method === "GET") {
        return handleTrendingVines(request, env2);
      }
      if (path === "/analytics/trending/viners" && request.method === "GET") {
        return handleTrendingViners(request, env2);
      }
      const videoStatsMatch = path.match(/^\/analytics\/video\/([a-f0-9]{64})\/stats$/i);
      if (videoStatsMatch && request.method === "GET") {
        return handleVideoStats(request, env2, videoStatsMatch[1]);
      }
      if (path === "/analytics/health" && request.method === "GET") {
        return new Response(
          JSON.stringify({
            status: "healthy",
            environment: env2.ENVIRONMENT,
            timestamp: (/* @__PURE__ */ new Date()).toISOString()
            // Future: could add KV connection status, etc.
          }),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*"
            }
          }
        );
      }
      return new Response(
        JSON.stringify({ error: "Not found" }),
        {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        }
      );
    } catch (error3) {
      console.error("Worker error:", error3);
      return new Response(
        JSON.stringify({ error: "Internal server error" }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        }
      );
    }
  }
};

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env2, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env2);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env2, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env2);
  } catch (e) {
    const error3 = reduceError(e);
    return Response.json(error3, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-gmYowR/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// ../../../../.nvm/versions/node/v23.7.0/lib/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env2, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env2, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env2, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env2, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-gmYowR/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env2, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env2, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env2, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env2, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env2, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env2, ctx) => {
      this.env = env2;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
