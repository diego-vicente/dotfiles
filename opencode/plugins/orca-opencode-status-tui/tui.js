// Why: process-lifetime guard so a recurring parse error on a malformed
// endpoint file does not spam OpenCode's stderr once per hook post.
// This guard lives inside the plugin source because the plugin runs in
// OpenCode's Node process (not Orca's) and has no access to server.ts's
// equivalent warnedVersions / warnedEnvs Sets.
let warnedBadEndpoint = false;

// Why: message.part.updated can fire many times per second during a
// streaming assistant reply, and each post() calls resolveHookCoords()
// which reads the endpoint file. The file only changes on Orca restart
// (rare), so a stat+mtime check is substantially cheaper than a full
// readFileSync+parse on every streamed part. On stat error we fall
// through to parse so the fail-open behavior is preserved.
let cachedEndpointKey = "";
let cachedEndpointValues = null;

function readEndpointFile() {
  const path = process.env.ORCA_AGENT_HOOK_ENDPOINT;
  if (!path) return null;
  try {
    const fs = require("fs");
    try {
      const stat = fs.statSync(path);
      // Why: cache key combines mtime + size + inode. renameSync (used by
      // writeEndpointFile on the Orca side) allocates a fresh inode on
      // POSIX and a new Windows file ID on NTFS, so ino changes on every
      // legitimate rewrite even when mtimeMs resolution is coarse and size
      // happens to match.
      const cacheKey = stat.mtimeMs + ":" + stat.size + ":" + stat.ino;
      if (cacheKey === cachedEndpointKey && cachedEndpointValues) {
        return cachedEndpointValues;
      }
      const contents = fs.readFileSync(path, "utf8");
      const out = {};
      for (const line of contents.split(/\r?\n/)) {
        // Why: Windows endpoint.cmd uses `set KEY=VALUE`; Unix endpoint.env
        // uses `KEY=VALUE`. Making `set ` optional lets the same parser
        // handle both without platform detection in the plugin. Allow
        // digits in the key for forward-compat with future ORCA_AGENT_HOOK_*
        // names that may contain numerics, and strip a trailing CR so
        // mixed-EOL files with lone `\r` do not leak CR into the value.
        const m = line.match(/^(?:set\s+)?([A-Z0-9_]+)=(.*)$/);
        if (m) out[m[1]] = m[2].replace(/\r$/, "");
      }
      cachedEndpointKey = cacheKey;
      cachedEndpointValues = out;
      return out;
    } catch (ioErr) {
      // Why: any stat or read failure (file yanked mid-read, permission
      // race, unlink between stat and readFileSync) must invalidate the
      // cache so a transient failure does not lock in a stale parse for
      // the remaining process lifetime; rethrow to the outer catch.
      cachedEndpointKey = "";
      cachedEndpointValues = null;
      throw ioErr;
    }
  } catch (err) {
    // Why: warn once per process if the file exists but is unreadable or
    // malformed — a persistent, silently-swallowed parse error would
    // otherwise leave the plugin falling back to stale process.env on
    // every post with no signal. ENOENT / missing env var is the normal
    // pre-install case; stay silent for it.
    if (err && err.code !== "ENOENT" && !warnedBadEndpoint) {
      warnedBadEndpoint = true;
      console.warn("[orca-hook] failed to parse endpoint file:", err.message);
    }
    return null;
  }
}

function resolveHookCoords() {
  // Why: prefer the on-disk endpoint file over process.env because env was
  // frozen when OpenCode was fork()ed — stale after an Orca restart. The
  // file is rewritten on every Orca start(), so sourcing it per post lets
  // a long-running OpenCode session reach the current server. Falls back
  // to process.env when the file is absent (first-run / pre-endpoint-file / Orca
  // never started writing the file).
  const fileEnv = readEndpointFile() || {};
  return {
    port: fileEnv.ORCA_AGENT_HOOK_PORT || process.env.ORCA_AGENT_HOOK_PORT,
    token: fileEnv.ORCA_AGENT_HOOK_TOKEN || process.env.ORCA_AGENT_HOOK_TOKEN,
    env: fileEnv.ORCA_AGENT_HOOK_ENV || process.env.ORCA_AGENT_HOOK_ENV || "",
    version: fileEnv.ORCA_AGENT_HOOK_VERSION || process.env.ORCA_AGENT_HOOK_VERSION || "",
    openCodeTui: process.env.ORCA_AGENT_HOOK_ENDPOINT ? fileEnv.ORCA_AGENT_HOOK_OPENCODE_TUI : process.env.ORCA_AGENT_HOOK_OPENCODE_TUI,
  };
}

function hookEndpointKey() {
  const coords = resolveHookCoords();
  return [coords.port || "", coords.token || "", coords.env, coords.version].join("\u0000");
}

function getStatusType(event) {
  return event?.properties?.status?.type ?? event?.status?.type ?? null;
}

const HOOK_POST_TIMEOUT_MS = 2000;
const SESSION_LOOKUP_TIMEOUT_MS = 2000;
const MAX_SESSION_ANCESTRY_DEPTH = 32;
const STATUS_RETRY_BASE_MS = 500;
const STATUS_RETRY_MAX_MS = 30000;
let desiredStatus = "idle";
let desiredHookEventName = "SessionIdle";
let desiredStatusKey = "idle:";
let desiredStatusProperties = {};
let desiredFactoryID = null;
let deliveredStatusKey = "idle:";
let deliveredEndpointKey = "";
let statusDeliveryDirty = false;
let statusRevision = 0;
let statusRetryAttempt = 0;
let statusRetryTimer = null;
let lifecycleQueue = Promise.resolve();
let busyRecoveryQueued = false;
let busyRecoveryUsed = false;
let busyRecoveryEndpointKey = "";
let stateArrivalRevision = 0;
// Recognized OpenCode 2 contexts bypass the legacy binder.
let reportingOpenCodeMajor = 0;
let reportingOpenCodeTui = false;
// Why: OpenCode can create directory-scoped factories and concurrent root
// sessions in one pane; module ownership lets waiting/busy aggregate safely.
let nextFactoryID = 0;
const activeFactoryIDs = new Set();
const disposingFactoryIDs = new Set();
const busyRootOwnerBySessionID = new Map();
// Why: a matching Idle must retire fail-open Busy even when the SDK client
// is unavailable, without granting an unrelated unknown Idle authority.
const provisionalBusyByKey = new Map();
// Why: a background child outlives the root turn that spawned it, so the
// pane must stay Busy on its behalf until its own exact Idle (or its
// factory's disposal) retires it — otherwise the root Idle completes a task
// tree that is still working.
const busyChildRootByKey = new Map();
const pendingAttentionByKey = new Map();
const rootSessionById = new Map();
const rootSessionLookupById = new Map();

// Why: message.part.updated re-sends the FULL accumulated text of the part
// after every streamed append, so posting each event forwards O(n^2) bytes
// per turn through Orca (loopback HTTP -> main JSON parse -> status compare
// -> IPC -> renderer store update -> React commit). On Windows that flood
// saturated both event loops and froze the whole UI a few seconds into a
// streaming reply. The dashboard only needs a bounded preview at a human
// cadence: cap the text and trailing-edge coalesce assistant parts.
const MESSAGE_PART_THROTTLE_MS = 250;
const MESSAGE_PART_MAX_CHARS = 4000;
let pendingAssistantPart = null;
let assistantPartFlushTimer = null;
let messagePartPostInFlight = null;
let deliveredMessagePartFactoryID = null;
let lastAssistantPartPostAt = 0;

function isOpenCodeCommandProcess(command) {
  // Why drop a leading path: a compiled binary reports its embedded entry script as argv[1].
  const args = process.argv.slice(1);
  if (args.length > 0 && /[\\/]/.test(args[0])) args.shift();
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === "--") return false;
    if (!args[index].startsWith("-")) return args[index] === command;
    if (args[index] === "--log-level") index += 1;
  }
  return false;
}
function isOpenCodeRunProcess() {
  return isOpenCodeCommandProcess("run");
}

function capMessagePartText(text) {
  return text.length > MESSAGE_PART_MAX_CHARS ? text.slice(0, MESSAGE_PART_MAX_CHARS) : text;
}

async function postMessagePart(properties, factoryID) {
  while (messagePartPostInFlight) await messagePartPostInFlight;
  const delivery = post("MessagePart", properties);
  messagePartPostInFlight = delivery;
  try {
    const delivered = await delivery;
    if (delivered) deliveredMessagePartFactoryID = factoryID;
  } finally {
    if (messagePartPostInFlight === delivery) messagePartPostInFlight = null;
  }
}

async function flushPendingAssistantPart(force = false) {
  if (assistantPartFlushTimer) {
    clearTimeout(assistantPartFlushTimer);
    assistantPartFlushTimer = null;
  }
  // Why: an idle/waiting transition must wait for every older preview;
  // keep one post in flight while later snapshots coalesce in memory.
  while (messagePartPostInFlight) await messagePartPostInFlight;
  const pending = pendingAssistantPart;
  pendingAssistantPart = null;
  if (!pending) return;
  if (
    !activeFactoryIDs.has(pending.factoryID) ||
    disposingFactoryIDs.has(pending.factoryID)
  ) return;
  if (!force && pending.authorityRevision !== stateArrivalRevision) return;
  lastAssistantPartPostAt = Date.now();
  await postMessagePart({
    role: pending.role,
    text: capMessagePartText(pending.text),
    messageID: pending.messageID,
    sessionID: pending.sessionID,
  }, pending.factoryID);
}

function queueAssistantPart(part) {
  // Why: keep only the latest snapshot — each event already contains the
  // full accumulated text, so intermediate snapshots are pure waste.
  pendingAssistantPart = part;
  const sinceLastPost = Date.now() - lastAssistantPartPostAt;
  if (sinceLastPost >= MESSAGE_PART_THROTTLE_MS) {
    void flushPendingAssistantPart();
    return;
  }
  if (!assistantPartFlushTimer) {
    assistantPartFlushTimer = setTimeout(() => {
      void flushPendingAssistantPart();
    }, MESSAGE_PART_THROTTLE_MS - sinceLastPost);
    if (assistantPartFlushTimer.unref) assistantPartFlushTimer.unref();
  }
}

// Why: message.part.updated fires for every Part (text, tool, reasoning)
// but does not include the message role — that lives on the parent
// message.updated event. Cache the role per messageID so the plugin can
// tag a TextPart as user vs assistant when POSTing. Capped at 128 entries
// so long-running sessions do not grow this map unboundedly.
const messageRoleById = new Map();
function rememberMessageRole(messageID, role) {
  if (!messageID || !role) return;
  if (messageRoleById.size >= 128) {
    const first = messageRoleById.keys().next().value;
    if (first !== undefined) messageRoleById.delete(first);
  }
  messageRoleById.set(messageID, role);
}

// Why: oh-my-opencode style tools spawn child sessions that emit their
// own session.idle / message events. Those child completions must not
// flip the root Orca pane to done or overwrite the parent turn preview.
// Resolve the full parentID chain so descendant attention can be attributed
// to the root while child completion and previews remain non-authoritative.
async function resolveRootSessionID(client, sessionID) {
  if (!sessionID) return null;
  if (rootSessionById.has(sessionID)) return rootSessionById.get(sessionID);
  if (!client?.session?.get && !client?.session?.list) return null;
  if (rootSessionLookupById.has(sessionID)) return rootSessionLookupById.get(sessionID);
  const lookup = lookupRootSessionID(client, sessionID);
  rootSessionLookupById.set(sessionID, lookup);
  try {
    return await lookup;
  } finally {
    if (rootSessionLookupById.get(sessionID) === lookup) {
      rootSessionLookupById.delete(sessionID);
    }
  }
}

async function isChildSession(client, sessionID) {
  const rootSessionID = await resolveRootSessionID(client, sessionID);
  return rootSessionID === null ? null : rootSessionID !== sessionID;
}

function rememberSessionRoot(sessionID, rootSessionID) {
  if (rootSessionById.size >= 128 && !rootSessionById.has(sessionID)) {
    const first = rootSessionById.keys().next().value;
    if (first !== undefined) rootSessionById.delete(first);
  }
  rootSessionById.set(sessionID, rootSessionID);
}

async function lookupRootSessionID(client, sessionID) {
  const controller = new AbortController();
  let timeout;
  const deadline = new Promise((_, reject) => {
    timeout = setTimeout(() => {
      controller.abort();
      reject(new Error("session lookup timed out"));
    }, SESSION_LOOKUP_TIMEOUT_MS);
    if (timeout.unref) timeout.unref();
  });
  try {
    const rootSessionID = await Promise.race([
      walkSessionParents(client, sessionID, controller.signal),
      deadline,
    ]);
    return rootSessionID;
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

async function walkSessionParents(client, sessionID, signal) {
  const lineage = [];
  let currentSessionID = sessionID;
  // Why: malformed or unexpectedly deep ancestry must not monopolize the
  // lifecycle FIFO even when every individual SDK lookup succeeds.
  while (lineage.length < MAX_SESSION_ANCESTRY_DEPTH) {
    const cachedRoot = rootSessionById.get(currentSessionID);
    if (cachedRoot) {
      for (const id of lineage) rememberSessionRoot(id, cachedRoot);
      return cachedRoot;
    }
    if (lineage.includes(currentSessionID)) return null;
    lineage.push(currentSessionID);
    const sessions = await lookupSessionList(client, currentSessionID, signal);
    const list = Array.isArray(sessions?.data) ? sessions.data : [];
    const session = list.find((entry) => entry?.id === currentSessionID);
    if (!session) return null;
    if (!session.parentID) {
      for (const id of lineage) rememberSessionRoot(id, currentSessionID);
      return currentSessionID;
    }
    currentSessionID = session.parentID;
  }
  return null;
}

async function lookupSessionList(client, sessionID, signal) {
  // Why: point lookup avoids the SDK list page dropping older children;
  // current SDKs put AbortSignal in a second options argument, while legacy
  // generated clients accept one request-options object.
  if (client?.session?.get) {
    const calls = client.session.get.length >= 2
      ? [
          [{ sessionID }, { signal }],
          [{ path: { id: sessionID }, signal }],
        ]
      : [[{ path: { id: sessionID }, signal }]];
    for (const args of calls) {
      try {
        const result = await client.session.get(...args);
        if (result?.data?.id === sessionID) return { data: [result.data] };
      } catch {
        if (signal.aborted) throw new Error("session lookup aborted");
        // Try the other supported SDK generation, then list fallback.
      }
    }
  }
  if (!client?.session?.list) return { data: [] };
  if (client.session.list.length >= 2) {
    return client.session.list({}, { signal });
  }
  return client.session.list({ signal });
}

async function post(hookEventName, extraProperties) {
  // Why: resolve coords per post — the endpoint file may have been
  // rewritten by a newer Orca since the last call. Pane/tab/worktree IDs
  // stay on process.env because they are per-PTY (stable for the life of
  // the OpenCode process), not per-Orca-instance.
  const coords = resolveHookCoords();
  const paneKey = process.env.ORCA_PANE_KEY;
  if (!coords.port || !coords.token || !paneKey) return false;
  const tmuxMatch = /^(.*),[0-9]+,[0-9]+$/.exec(process.env.TMUX || "");
  const tmuxPane = process.env.TMUX_PANE;
  if (reportingOpenCodeTui && coords.openCodeTui !== "1") return false;
  const url = `http://127.0.0.1:${coords.port}/hook/opencode`;
  const body = JSON.stringify({
    paneKey,
    ...(tmuxMatch && /^%[0-9]+$/.test(tmuxPane || "") ? { tmux: { socket: tmuxMatch[1], pane: tmuxPane } } : {}),
    launchToken: process.env.ORCA_AGENT_LAUNCH_TOKEN || "",
    tabId: process.env.ORCA_TAB_ID || "",
    worktreeId: process.env.ORCA_WORKTREE_ID || "",
    env: coords.env,
    version: coords.version,
    ...(reportingOpenCodeMajor ? { opencodeMajor: reportingOpenCodeMajor } : {}),
    ...(reportingOpenCodeTui ? { opencodeTui: 1 } : {}),
    ...(reportingOpenCodeMajor < 2 && isOpenCodeCommandProcess("serve") && coords.openCodeTui === "1" ? { opencodeSharedServer: 1 } : {}),
    payload: { hook_event_name: hookEventName, ...(extraProperties || {}) },
  });
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), HOOK_POST_TIMEOUT_MS);
  if (timeout.unref) timeout.unref();
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Orca-Agent-Hook-Token": coords.token,
      },
      body,
      signal: controller.signal,
    });
    return response.ok;
  } catch {
    // Why: OpenCode session events must never fail the agent run just
    // because Orca is unavailable or the local loopback request failed.
    return false;
  } finally {
    clearTimeout(timeout);
  }
}

function enqueueLifecycle(task) {
  // Why: OpenCode intentionally fire-and-forgets hook promises, so async
  // lookups and posts need their own FIFO to preserve event order.
  const run = lifecycleQueue.then(async () => {
    try {
      await task();
    } catch {
      // Hook delivery must never reject into OpenCode.
    }
  });
  lifecycleQueue = run;
  return run;
}

function clearStatusRetry() {
  if (statusRetryTimer) clearTimeout(statusRetryTimer);
  statusRetryTimer = null;
}

function scheduleStatusRetry(revision) {
  if (
    statusRetryTimer ||
    revision !== statusRevision ||
    !statusDeliveryDirty ||
    !activeFactoryIDs.has(desiredFactoryID)
  ) return;
  const delay = Math.min(
    STATUS_RETRY_BASE_MS * Math.pow(2, Math.min(statusRetryAttempt, 6)),
    STATUS_RETRY_MAX_MS
  );
  statusRetryAttempt = Math.min(statusRetryAttempt + 1, 7);
  statusRetryTimer = setTimeout(() => {
    statusRetryTimer = null;
    void enqueueLifecycle(async () => {
      if (
        revision !== statusRevision ||
        !statusDeliveryDirty ||
        !activeFactoryIDs.has(desiredFactoryID)
      ) return;
      await publishDesiredStatus(revision);
    });
  }, delay);
  if (statusRetryTimer.unref) statusRetryTimer.unref();
}

async function publishDesiredStatus(revision) {
  if (revision !== statusRevision) return;
  if (!activeFactoryIDs.has(desiredFactoryID)) return;
  const endpointKey = hookEndpointKey();
  if (
    !statusDeliveryDirty &&
    deliveredStatusKey === desiredStatusKey &&
    deliveredEndpointKey === endpointKey &&
    deliveredMessagePartFactoryID === null
  ) return;
  const delivered = await post(desiredHookEventName, desiredStatusProperties);
  if (revision !== statusRevision) return;
  if (!delivered) {
    statusDeliveryDirty = true;
    scheduleStatusRetry(revision);
    return;
  }
  clearStatusRetry();
  statusRetryAttempt = 0;
  deliveredStatusKey = desiredStatusKey;
  deliveredEndpointKey = endpointKey;
  deliveredMessagePartFactoryID = null;
  statusDeliveryDirty = false;
}

async function setDeliveryTarget(
  next,
  nextKey,
  hookEventName,
  extraProperties,
  factoryID
) {
  const endpointChanged = deliveredEndpointKey !== hookEndpointKey();
  if (
    nextKey === desiredStatusKey &&
    nextKey === deliveredStatusKey &&
    desiredFactoryID === factoryID &&
    !statusDeliveryDirty &&
    !endpointChanged &&
    deliveredMessagePartFactoryID === null
  ) return;
  const targetChanged = nextKey !== desiredStatusKey || desiredFactoryID !== factoryID;
  clearStatusRetry();
  if (targetChanged) {
    statusRetryAttempt = 0;
    busyRecoveryUsed = false;
    busyRecoveryEndpointKey = "";
  }
  desiredStatus = next;
  desiredHookEventName = hookEventName;
  desiredStatusKey = nextKey;
  desiredStatusProperties = extraProperties || {};
  desiredFactoryID = factoryID;
  statusDeliveryDirty =
    statusDeliveryDirty ||
    deliveredMessagePartFactoryID !== null ||
    deliveredStatusKey !== nextKey ||
    endpointChanged;
  const revision = ++statusRevision;
  await publishDesiredStatus(revision);
}

async function setStatus(next, extraProperties, factoryID) {
  const nextKey = next + ":" + (extraProperties?.sessionID || "");
  const hookEventName = next === "busy" ? "SessionBusy" : "SessionIdle";
  await setDeliveryTarget(next, nextKey, hookEventName, extraProperties, factoryID);
}

async function setAttention(hookEventName, properties, factoryID, sourceSessionID) {
  const requestID = properties?.id || properties?.sessionID || "";
  const requestKey = attentionKey(factoryID, hookEventName, requestID, sourceSessionID);
  await flushPendingAssistantPart(true);
  await setDeliveryTarget(
    "waiting",
    "waiting:" + requestKey,
    hookEventName,
    properties,
    factoryID
  );
}

function recoverBusyFromDelta(client, sessionID, factoryID) {
  if (busyRecoveryQueued) return lifecycleQueue;
  if (
    busyRecoveryUsed &&
    busyRecoveryEndpointKey === hookEndpointKey()
  ) return lifecycleQueue;
  busyRecoveryQueued = true;
  return enqueueLifecycle(async () => {
    try {
      if (!activeFactoryIDs.has(factoryID)) return;
      if (sessionID && (await isChildSession(client, sessionID)) === true) return;
      if (!activeFactoryIDs.has(factoryID)) return;
      const endpointKey = hookEndpointKey();
      const endpointChanged = deliveredEndpointKey !== endpointKey;
      if (desiredStatus !== "busy" || (!statusDeliveryDirty && !endpointChanged)) return;
      if (busyRecoveryUsed && !endpointChanged) return;
      busyRecoveryUsed = true;
      busyRecoveryEndpointKey = endpointKey;
      clearStatusRetry();
      statusDeliveryDirty = true;
      const revision = ++statusRevision;
      await publishDesiredStatus(revision);
    } finally {
      busyRecoveryQueued = false;
    }
  });
}

function currentAttention() {
  let latestQuestion = null;
  for (const attention of pendingAttentionByKey.values()) {
    if (attention.hookEventName === "PermissionRequest") return attention;
    latestQuestion = attention;
  }
  return latestQuestion;
}

function attentionKey(factoryID, hookEventName, requestID, sourceSessionID) {
  // Why: custom plugins may reuse request IDs across sessions or factories;
  // JSON tuple identity prevents one owner from hiding another blocker.
  return JSON.stringify([factoryID, hookEventName, requestID, sourceSessionID || ""]);
}

function clearAttentionForSession(sessionID, factoryID) {
  let rootSessionID = null;
  for (const [key, attention] of pendingAttentionByKey) {
    if (attention.sourceSessionID === sessionID && attention.factoryID === factoryID) {
      pendingAttentionByKey.delete(key);
      rootSessionID = attention.properties?.sessionID || sessionID;
    }
  }
  return rootSessionID;
}

// Why a second, wider clear: a descendant blocker is stored under its own
// sourceSessionID but displayed on the root it rolled up to, so the root turn
// ending can never retire it through the source match alone — a subagent question
// outlives the turn that raised it and pins the pane (#22371). Scoped to turn end
// on purpose: a live blocker must still outrank the root going Busy, because a
// subagent can be waiting on the user while the root keeps working.
function clearAttentionForTurnEnd(sessionID, factoryID) {
  let rootSessionID = null;
  for (const [key, attention] of pendingAttentionByKey) {
    const ownsAttention =
      attention.sourceSessionID === sessionID ||
      attention.properties?.sessionID === sessionID;
    if (ownsAttention && attention.factoryID === factoryID) {
      pendingAttentionByKey.delete(key);
      rootSessionID = attention.properties?.sessionID || sessionID;
    }
  }
  return rootSessionID;
}

function clearQuestionForToolPart(part, sessionID, factoryID) {
  if (
    part?.type !== "tool" ||
    part.tool !== "question" ||
    (part.state?.status !== "completed" && part.state?.status !== "error")
  ) return null;
  let rootSessionID = null;
  for (const [key, attention] of pendingAttentionByKey) {
    const tool = attention.properties?.tool;
    if (
      attention.hookEventName === "AskUserQuestion" &&
      attention.sourceSessionID === sessionID &&
      attention.factoryID === factoryID &&
      tool?.messageID === part.messageID &&
      tool?.callID === part.callID
    ) {
      pendingAttentionByKey.delete(key);
      rootSessionID = attention.properties?.sessionID || sessionID;
    }
  }
  return rootSessionID;
}

function clearAttentionForResolution(event, sessionID, factoryID) {
  const hookEventName =
    event.type === "permission.replied" ? "PermissionRequest" : "AskUserQuestion";
  const requestID = event.properties?.requestID || "";
  const key = attentionKey(factoryID, hookEventName, requestID, sessionID);
  const attention = pendingAttentionByKey.get(key);
  if (!attention || attention.sourceSessionID !== sessionID) return null;
  pendingAttentionByKey.delete(key);
  return attention.properties?.sessionID || sessionID;
}

function provisionalBusyKey(factoryID, sessionID) {
  return JSON.stringify([factoryID, sessionID || ""]);
}

function rememberProvisionalBusy(sessionID, factoryID) {
  const key = provisionalBusyKey(factoryID, sessionID);
  // Why: active ownership cannot be LRU-evicted without allowing false
  // Idle; exact matching Idle or factory disposal lifecycle-bounds it.
  provisionalBusyByKey.delete(key);
  provisionalBusyByKey.set(key, { sessionID, factoryID });
}

function clearProvisionalBusy(sessionID, factoryID) {
  return provisionalBusyByKey.delete(provisionalBusyKey(factoryID, sessionID));
}

function busyChildKey(factoryID, sessionID) {
  return JSON.stringify([factoryID, sessionID || ""]);
}

function rememberBusyChild(sessionID, rootSessionID, factoryID) {
  const key = busyChildKey(factoryID, sessionID);
  // Why: repeated Busy for the same child is not a state change; report one
  // only when the pane actually gains a running descendant.
  if (busyChildRootByKey.get(key)?.sessionID === rootSessionID) return false;
  busyChildRootByKey.delete(key);
  busyChildRootByKey.set(key, { sessionID: rootSessionID, factoryID });
  return true;
}

function clearBusyChild(sessionID, factoryID) {
  return busyChildRootByKey.delete(busyChildKey(factoryID, sessionID));
}

function clearKnownBusyRoot(sessionID, factoryID) {
  if (busyRootOwnerBySessionID.get(sessionID) !== factoryID) return false;
  busyRootOwnerBySessionID.delete(sessionID);
  return true;
}

function latestBusyOwner() {
  let latest = null;
  // Why: a running descendant is reported under its ROOT id, and ranks
  // below a directly busy root so an ongoing turn keeps labelling the pane.
  for (const busyChild of busyChildRootByKey.values()) {
    latest = busyChild;
  }
  for (const [sessionID, factoryID] of busyRootOwnerBySessionID) {
    latest = { sessionID, factoryID };
  }
  for (const provisional of provisionalBusyByKey.values()) {
    latest = provisional;
  }
  return latest;
}

async function publishAggregateStatus(fallbackFactoryID, preferredSessionID) {
  const attention = currentAttention();
  if (attention) {
    await setAttention(
      attention.hookEventName,
      attention.properties,
      attention.factoryID,
      attention.sourceSessionID
    );
    return;
  }
  const busyOwner = latestBusyOwner();
  if (busyOwner) {
    await setStatus("busy", { sessionID: busyOwner.sessionID }, busyOwner.factoryID);
    return;
  }
  await setStatus("idle", { sessionID: preferredSessionID }, fallbackFactoryID);
}

async function publishOwnershipChange(fallbackFactoryID, preferredSessionID) {
  stateArrivalRevision += 1;
  // Why: exact blocker/Busy retirement is authoritative even if ancestry
  // lookup failed; every older preview must settle before its replacement.
  await flushPendingAssistantPart(true);
  await publishAggregateStatus(fallbackFactoryID, preferredSessionID);
}

async function handleLifecycleEvent(client, event, factoryID) {
  const sessionID = event.properties?.sessionID;
  const statusType = getStatusType(event);
  const isResolutionEvent =
    event.type === "permission.replied" ||
    event.type === "question.replied" ||
    event.type === "question.rejected";
  if (isResolutionEvent) {
    // Why: the stored owner already identifies the root, so replies clear
    // immediately even when OpenCode session lookup is slow or unavailable.
    const rootSessionID = clearAttentionForResolution(event, sessionID, factoryID);
    if (rootSessionID) await publishOwnershipChange(factoryID, rootSessionID);
    return;
  }
  const isAttentionEvent =
    event.type === "permission.asked" ||
    event.type === "question.asked";
  // Why: attention without OpenCode's required sessionID cannot be
  // correlated to a later reply/Idle, so it must not become UI authority.
  if (isAttentionEvent && !sessionID) return;
  const canFailOpen =
    statusType === "busy" || statusType === "retry" || isAttentionEvent;
  const rootSessionID = sessionID ? await resolveRootSessionID(client, sessionID) : null;
  const childState = rootSessionID === null ? null : rootSessionID !== sessionID;
  const isIdleEvent = event.type === "session.idle" || statusType === "idle";
  const resolvedProvisionalBusy =
    childState === false || (childState === true && isIdleEvent)
      ? clearProvisionalBusy(sessionID, factoryID)
      : false;
  if (resolvedProvisionalBusy && childState === false) {
    busyRootOwnerBySessionID.delete(sessionID);
    busyRootOwnerBySessionID.set(sessionID, factoryID);
  }
  // Why: child work rolls up to the pane; ignore its normal lifecycle noise,
  // but preserve blockers that still require the pane owner to respond.
  if (childState === true && !isAttentionEvent) {
    let attentionRootSessionID = null;
    let childBusyChanged = false;
    if (isIdleEvent) {
      attentionRootSessionID = clearAttentionForSession(sessionID, factoryID);
      childBusyChanged = clearBusyChild(sessionID, factoryID);
    } else if (statusType === "busy" || statusType === "retry") {
      childBusyChanged = rememberBusyChild(sessionID, rootSessionID, factoryID);
    }
    if (resolvedProvisionalBusy || attentionRootSessionID || childBusyChanged) {
      await publishOwnershipChange(factoryID, attentionRootSessionID || rootSessionID);
    }
    return;
  }
  if (childState === null && !canFailOpen) {
    if (isIdleEvent) {
      // Why: recorded ownership can safely retire a blocker during an SDK
      // outage without granting unknown child Idle authority over root state.
      const attentionRootSessionID = clearAttentionForSession(sessionID, factoryID);
      const clearedProvisionalBusy = clearProvisionalBusy(sessionID, factoryID);
      const clearedKnownBusyRoot = clearKnownBusyRoot(sessionID, factoryID);
      // Why: exact-session cleanup, so a child whose finishing Idle lands
      // during an SDK outage cannot pin the pane Busy forever.
      const clearedBusyChild = clearBusyChild(sessionID, factoryID);
      if (
        attentionRootSessionID ||
        clearedProvisionalBusy ||
        clearedKnownBusyRoot ||
        clearedBusyChild
      ) {
        await publishOwnershipChange(factoryID, attentionRootSessionID || sessionID);
      }
    }
    return;
  }
  if (childState === null && (statusType === "busy" || statusType === "retry")) {
    // Unknown lineage may be child work, so keep exact provisional ownership
    // only until matching Idle/disposal; other blockers still take priority.
    clearAttentionForSession(sessionID, factoryID);
    rememberProvisionalBusy(sessionID, factoryID);
    await publishAggregateStatus(factoryID, sessionID);
    return;
  }
  if (event.type === "permission.asked" || event.type === "question.asked") {
    stateArrivalRevision += 1;
    // Why: attention must share the lifecycle FIFO and retry target so a
    // delayed Busy post cannot overwrite a newer human blocker.
    const hookEventName =
      event.type === "permission.asked" ? "PermissionRequest" : "AskUserQuestion";
    // Why: show the blocker on the root turn while retaining its real child
    // owner for exact reply, tool-completion, and disposal cleanup.
    const properties = { ...(event.properties || {}), sessionID: rootSessionID || sessionID };
    const requestID = properties.id || sessionID || "";
    const key = attentionKey(factoryID, hookEventName, requestID, sessionID);
    // Why: unresolved blockers are live UI authority and cannot be evicted;
    // reply, exact Idle, tool completion, or factory disposal retires them.
    pendingAttentionByKey.set(key, {
      hookEventName,
      properties,
      factoryID,
      sourceSessionID: sessionID,
    });
    await publishAggregateStatus(factoryID, rootSessionID || sessionID);
    return;
  }
  if (isIdleEvent) {
    stateArrivalRevision += 1;
    const idleKey = "idle:" + (sessionID || "");
    // Why: current OpenCode emits canonical idle followed by deprecated
    // session.idle; a failed canonical post should keep its backoff.
    if (
      event.type === "session.idle" &&
      desiredStatusKey === idleKey &&
      statusDeliveryDirty &&
      statusRetryTimer
    ) return;
    // Why: flush the coalesced final reply snapshot before the idle
    // transition so the done-state preview shows the completed message.
    await flushPendingAssistantPart(true);
    clearAttentionForTurnEnd(sessionID, factoryID);
    if (busyRootOwnerBySessionID.get(sessionID) === factoryID) {
      busyRootOwnerBySessionID.delete(sessionID);
    }
    await publishAggregateStatus(factoryID, sessionID);
    return;
  }
  // Why: recoverable compaction failures emit session.error and continue;
  // canonical session.status is the authority for actual completion.
  if (event.type === "session.error") return;
  if (statusType === "busy" || statusType === "retry") {
    clearAttentionForSession(sessionID, factoryID);
    busyRootOwnerBySessionID.delete(sessionID);
    busyRootOwnerBySessionID.set(sessionID, factoryID);
    await publishAggregateStatus(factoryID, sessionID);
  }
}


function normalizeNextLifecycleEvent(event) {
  if (!event || typeof event.type !== "string") return event;
  const properties = event.properties || {};
  if (event.type === "permission.v2.asked") return { ...event, type: "permission.asked", properties: { ...properties, id: properties.id, permission: properties.action, patterns: properties.resources } };
  if (event.type === "permission.v2.replied") return { ...event, type: "permission.replied", properties: { ...properties } };
  if (event.type === "question.v2.asked") return { ...event, type: "question.asked", properties: { ...properties } };
  if (event.type === "question.v2.replied") return { ...event, type: "question.replied", properties: { ...properties } };
  if (event.type === "question.v2.rejected") return { ...event, type: "question.rejected", properties: { ...properties } };
  if (event.type === "session.next.step.started" || event.type === "session.next.tool.called" || event.type === "session.next.tool.progress" || event.type === "session.next.retried") {
    return { ...event, type: "session.status", properties: { ...properties, status: { type: "busy" } } };
  }
  return event;
}

// Why: accept the factory argument as an optional opaque parameter instead
// of destructuring (`async ({ client }) => …`). OpenCode can invoke the
// plugin factory with undefined during startup, which makes the
// destructuring form throw synchronously and crash OpenCode with an opaque
// UnknownError before any event is ever dispatched.
export const OrcaOpenCodeStatusPlugin = async (_ctx) => {
  if (process.env.ORCA_OPENCODE_AGENT && process.env.ORCA_OPENCODE_AGENT !== 'opencode') return {};
  const client = _ctx?.client;
  const sessionsOutliveDispose = _ctx?.sessionsOutliveDispose === true;
  const factoryID = ++nextFactoryID;
  activeFactoryIDs.add(factoryID);
  let disposed = false;
  const nextTextByMessageID = new Map();
  return {
  event: async ({ event }) => {
    if (disposed || !event?.type) return;
    const authorityRevision = stateArrivalRevision;
    const statusType = getStatusType(event);

    // Why: cache the message role BEFORE the async isChildSession check.
    // OpenCode fires message.updated (user) and message.part.updated (text)
    // back-to-back; if we awaited isChildSession first, the part.updated
    // handler could reach messageRoleById.get(...) while the user message.updated
    // is still suspended on that await — so the part would see an empty cache
    // and drop the user prompt. Caching is a cheap Map.set with bounded size,
    // safe to run even for child sessions (the part POST still filters them).
    if (event.type === "message.updated") {
      const info = event.properties && event.properties.info;
      rememberMessageRole(info && info.id, info && info.role);
    }

    const sessionID = event.properties?.sessionID;
    const updatedPart = event.properties?.part;

    // OpenCode 2 publishes the next-generation event family through the
    // same plugin event hook. Convert those events into the existing
    // bounded Orca lifecycle and preview posts.
    if (event.type === "session.next.prompt.admitted") {
      if (!sessionID) return;
      if ((await isChildSession(client, sessionID)) !== false) return;
      if (disposed || authorityRevision !== stateArrivalRevision || desiredStatus === "waiting") return;
      const prompt = event.properties?.prompt?.text;
      if (typeof prompt !== "string" || !prompt) return;
      await postMessagePart({
        role: "user",
        text: capMessagePartText(prompt),
        messageID: event.properties?.messageID,
        sessionID,
      }, factoryID);
      return;
    }
    if (event.type === "session.next.text.started") {
      if (event.properties?.assistantMessageID) {
        if (nextTextByMessageID.size >= 128) nextTextByMessageID.delete(nextTextByMessageID.keys().next().value);
        nextTextByMessageID.set(event.properties.assistantMessageID, "");
      }
      return;
    }
    if (event.type === "session.next.text.delta") {
      const messageID = event.properties?.assistantMessageID;
      const delta = event.properties?.delta;
      if (typeof messageID !== "string" || typeof delta !== "string") return;
      nextTextByMessageID.set(messageID, capMessagePartText((nextTextByMessageID.get(messageID) || "") + delta));
      if (nextTextByMessageID.size > 128) nextTextByMessageID.delete(nextTextByMessageID.keys().next().value);
      return;
    }
    if (event.type === "session.next.text.ended") {
      if (!sessionID) return;
      if ((await isChildSession(client, sessionID)) !== false) return;
      const messageID = event.properties?.assistantMessageID;
      const text = typeof event.properties?.text === "string"
        ? event.properties.text
        : (typeof messageID === "string" ? nextTextByMessageID.get(messageID) : "");
      if (typeof messageID !== "string" || !text) return;
      nextTextByMessageID.delete(messageID);
      queueAssistantPart({ role: "assistant", text, messageID, sessionID, authorityRevision, factoryID });
      return;
    }
    if (event.type === "session.created") {
      const info = event.properties?.info;
      if (!info?.id || info.parentID) return;
      rememberSessionRoot(info.id, info.id);
      if (isOpenCodeRunProcess()) return; // a `run` goes Busy at once; its start row only blinks idle
      await enqueueLifecycle(() =>
        disposed ? undefined : post("SessionStart", { sessionID: info.id })
      );
      return;
    }

    if (
      event.type === "message.part.updated" &&
      updatedPart?.type === "tool" &&
      updatedPart.tool === "question" &&
      (updatedPart.state?.status === "completed" || updatedPart.state?.status === "error")
    ) {
      await enqueueLifecycle(async () => {
        if (disposed) return;
        // Why: stored ownership clears child questions without waiting on
        // ancestry lookup even though ordinary child message parts stay hidden.
        const rootSessionID = clearQuestionForToolPart(updatedPart, sessionID, factoryID);
        if (!rootSessionID) return;
        await publishOwnershipChange(factoryID, rootSessionID);
      });
      return;
    }

    if (
      event.type === "session.status" ||
      event.type === "session.idle" ||
      event.type === "session.error" ||
      event.type === "permission.asked" ||
      event.type === "question.asked" ||
      event.type === "permission.replied" ||
      event.type === "question.replied" ||
      event.type === "question.rejected" || event.type === "permission.v2.asked" || event.type === "permission.v2.replied" || event.type === "question.v2.asked" || event.type === "question.v2.replied" || event.type === "question.v2.rejected" || event.type === "session.next.step.started" || event.type === "session.next.tool.called" || event.type === "session.next.tool.progress" || event.type === "session.next.retried"
    ) {
      await enqueueLifecycle(() =>
        disposed ? undefined : handleLifecycleEvent(client, normalizeNextLifecycleEvent(event), factoryID)
      );
      return;
    }

    if (event.type === "message.part.delta") {
      const properties = event.properties || {};
      if (
        properties.field === "text" &&
        typeof properties.delta === "string" &&
        properties.delta.length > 0
      ) {
        await recoverBusyFromDelta(client, sessionID, factoryID);
      }
      return;
    }

    if (sessionID && (await isChildSession(client, sessionID)) !== false) {
      return;
    }
    if (disposed) return;
    if (authorityRevision !== stateArrivalRevision) return;
    if (desiredStatus === "waiting") return;

    if (event.type === "message.updated") {
      // Why: role is already cached above the isChildSession await so the
      // back-to-back message.part.updated for the same messageID is not
      // racing against this handler. Nothing more to do here — return to
      // avoid falling through to the part/session handlers below.
      return;
    }

    if (event.type === "message.part.updated") {
      // Why: a TextPart carries the actual user prompt or assistant reply
      // text. Skip non-text parts (tool, reasoning, file, …) so we only
      // forward what the dashboard renders. Role came from the earlier
      // message.updated event; if we never saw one (e.g. plugin loaded
      // mid-turn) the role is unknown, and mislabeling the part — a user
      // prompt displayed as the assistant reply, or vice versa — is worse
      // than silently dropping a single in-flight text chunk. The next
      // message.updated event will re-seed the role cache, so subsequent
      // parts in the same session flow normally.
      const part = event.properties && event.properties.part;
      if (!part || part.type !== "text" || !part.text) return;
      // Why: OpenCode injects a finished background task back into the
      // parent turn as a synthetic `<task id=…>` text part. It is machinery,
      // not what the human typed or the agent replied — OpenCode hides it
      // from its own prompt too — so it must not replace the pane preview.
      if (part.synthetic === true) return;
      const role = messageRoleById.get(part.messageID);
      if (!role) return;
      if (role === "user") {
        // Why: user prompts arrive as a single event, not a stream — post
        // immediately (still capped) so the throttle slot stays free for
        // the assistant reply that follows within the same window.
        await postMessagePart(
          { role, text: capMessagePartText(part.text), messageID: part.messageID, sessionID },
          factoryID
        );
        return;
      }
      queueAssistantPart({
        role,
        text: part.text,
        messageID: part.messageID,
        sessionID,
        authorityRevision,
        factoryID,
      });
      return;
    }

  },
  dispose: async () => {
    if (disposed) return;
    disposed = true;
    nextTextByMessageID.clear();
    disposingFactoryIDs.add(factoryID);
    await enqueueLifecycle(async () => {
      // An older MessagePart must settle before disposal publishes the
      // replacement state, or its late Working update could win.
      while (messagePartPostInFlight) await messagePartPostInFlight;
      for (const [sessionID, ownerID] of busyRootOwnerBySessionID) {
        if (ownerID === factoryID) busyRootOwnerBySessionID.delete(sessionID);
      }
      for (const [key, provisional] of provisionalBusyByKey) {
        if (provisional.factoryID === factoryID) provisionalBusyByKey.delete(key);
      }
      for (const [key, busyChild] of busyChildRootByKey) {
        if (busyChild.factoryID === factoryID) busyChildRootByKey.delete(key);
      }
      for (const [key, attention] of pendingAttentionByKey) {
        if (attention.factoryID === factoryID) pendingAttentionByKey.delete(key);
      }
      if (pendingAssistantPart?.factoryID === factoryID) {
        if (assistantPartFlushTimer) clearTimeout(assistantPartFlushTimer);
        assistantPartFlushTimer = null;
        pendingAssistantPart = null;
      }
      const ownsDeliveredMessagePart = deliveredMessagePartFactoryID === factoryID;
      // Why: OpenCode 1 disposes only on instance teardown, which cancels every run, so a final
      // Idle is true. OpenCode 2 also disposes on a hot reload mid-turn, so it publishes nothing.
      if (sessionsOutliveDispose) {
        if (desiredFactoryID === factoryID) {
          clearStatusRetry();
          statusRevision += 1;
        }
      } else if (desiredFactoryID === factoryID || ownsDeliveredMessagePart) {
        clearStatusRetry();
        statusRevision += 1;
        // A MessagePart may have changed the listener to Working after the
        // same lifecycle key was delivered; force that key to be reasserted.
        statusDeliveryDirty = ownsDeliveredMessagePart;
        busyRecoveryUsed = false;
        busyRecoveryEndpointKey = "";
        const fallbackFactoryID = Array.from(activeFactoryIDs).find((id) => id !== factoryID);
        if (fallbackFactoryID !== undefined) {
          await publishAggregateStatus(
            fallbackFactoryID,
            desiredStatusProperties?.sessionID
          );
        } else {
          if (!deliveredStatusKey.startsWith("idle:") || ownsDeliveredMessagePart) {
            await setStatus(
              "idle",
              { sessionID: desiredStatusProperties?.sessionID },
              factoryID
            );
          }
          clearStatusRetry();
          desiredStatus = "idle";
          desiredHookEventName = "SessionIdle";
          desiredStatusKey = "idle:";
          desiredStatusProperties = {};
          desiredFactoryID = null;
        }
      }
      activeFactoryIDs.delete(factoryID);
      disposingFactoryIDs.delete(factoryID);
    });
  },
  };
};
const ORCA_TUI_PLUGIN_ENTRY = new URL("./orca-opencode-status-tui/tui.js", import.meta.url);
const ORCA_STATUS_AGENT = "opencode";

async function setupLegacyOpenCodeTui(api) {
  const noop = async () => {};
  if (!/^1\./.test(String(api?.app?.version || "")) || !process.argv.includes("attach")) return noop;
  const session = api.state?.session;
  if (typeof session?.get !== "function" || typeof session.status !== "function" || typeof api.event?.on !== "function") return noop;
  reportingOpenCodeTui = true;
  const root = (id) => {
    const visited = [];
    let current = id;
    while (visited.length < MAX_SESSION_ANCESTRY_DEPTH && !visited.includes(current)) {
      visited.push(current);
      const parent = session.get(current)?.parentID;
      if (!parent) {
        for (const member of visited) rememberSessionRoot(member, current);
        return current;
      }
      current = parent;
    }
    return undefined;
  };
  const eventTypes = ["session.created", "session.deleted", "session.status", "session.idle", "session.error", "message.updated", "message.part.updated", "permission.asked", "permission.replied", "question.asked", "question.replied", "question.rejected", "server.connected"];
  const ctx = {
    app: api.app,
    legacyOpenCodeTui: true,
    ui: { router: { current: () => {
      const route = api.route.current;
      return route?.name === "session" ? { type: "session", sessionID: route.params?.sessionID } : { type: "home" };
    } } },
    data: {
      session: {
        get: (id) => session.get(id),
        root,
        family: (id) => [...rootSessionById.keys()].filter((member) => member !== id && root(member) === id),
        status: (id) => {
          const type = session.status(id)?.type;
          return type === "busy" || type === "retry" ? "running" : "idle";
        },
        permission: { list: (id) => session.permission(id) },
        form: { list: (id) => session.question(id) },
      },
      listen: (listener) => {
        const unsubscribers = eventTypes.map((type) => api.event.on(type, (input) => {
          const event = input?.details || input;
          const properties = event?.properties || {};
          const infoSessionID = type === "session.created" || type === "session.deleted" ? properties.info?.id : properties.info?.sessionID;
          const sessionID = properties.sessionID || infoSessionID || properties.part?.sessionID;
          if (sessionID) root(sessionID);
          if (type === "message.updated") rememberMessageRole(properties.info?.id, properties.info?.role);
          listener({ details: { type, data: { ...properties, sessionID, ...(type === "session.created" ? properties.info : {}) } } });
        }));
        return () => unsubscribers.forEach((unsubscribe) => { if (typeof unsubscribe === "function") unsubscribe(); });
      },
    },
  };
  const dispose = await setupOpenCode2Tui(ctx);
  api.lifecycle?.onDispose?.(dispose);
  return dispose;
}


// Why: OpenCode owns a form under a session id, and Orca retires a blocker when
// that session goes idle. An owner that is not a real session has no idle, so a
// blocker minted for it can only ever be retired by an exact reply — add an id
// here to drop forms Orca could otherwise strand. OpenCode's own schema calls
// "global" a temporary MCP-elicitation sentinel it intends to replace with real
// session ids; when it does, this set stops matching and those forms block.
const NON_SESSION_FORM_OWNERS = new Set(["global"]);

// Why one translation: the TUI reporter builds its Needs input payloads with it, so a blocker
// reaches Orca in the same shape whichever process reported it.
function translateOpenCode2Event(inputType, data) {
  let type = inputType;
  let properties = data || {};
  if (type === "session.created") {
    properties = { info: { ...properties, id: properties.sessionID } };
  } else if (type === "session.execution.started") {
    type = "session.status";
    properties = { ...properties, status: { type: "busy" } };
  } else if (type === "session.execution.succeeded" || type === "session.execution.failed" || type === "session.execution.interrupted") {
    type = "session.status";
    properties = { ...properties, status: { type: "idle" } };
  } else if (type === "permission.asked") {
    properties = { ...properties, permission: properties.action, patterns: properties.resources };
  } else if (type === "form.created") {
    const form = properties.form;
    // Why: block on every form whose owner is a real session. "metadata" is
    // optional in OpenCode's schema and its "kind" is a convention no
    // producer is obliged to stamp, so an unknown shape must surface a
    // blocker the user can clear rather than vanish while OpenCode waits.
    if (!form || NON_SESSION_FORM_OWNERS.has(form.sessionID)) return null;
    // A malformed form must not throw: that would kill the subscription.
    const fields = Array.isArray(form.fields) ? form.fields : [];
    type = "question.asked";
    properties = {
      ...form,
      questions: fields.map((field) => ({
        header: field.title || form.title,
        question: field.description || field.title || form.title,
        options: (field.options || []).map((option) => ({ label: option.label || option.value, description: option.description || "" })),
        multiple: field.type === "multiselect",
      })),
    };
  } else if (type === "form.replied" || type === "form.cancelled") {
    // A resolution for an ignored form is inert: the blocker key carries the
    // form id, so it simply matches nothing.
    type = type === "form.replied" ? "question.replied" : "question.rejected";
    properties = { ...properties, requestID: properties.id };
  } else if (type === "session.text.started" || type === "session.text.delta" || type === "session.text.ended") {
    type = type.replace("session.", "session.next.");
  }
  return { type, properties };
}

// Why: every OpenCode 2 server runs as a "serve" process (the shared service or a
// --standalone child) whose env names only the pane that spawned it, so each full TUI
// reports its own pane through the TUI copy of this plugin instead.
async function tuiReportsPaneLifecycle() {
  if (!process.argv.includes("serve")) return false;
  try {
    const { statSync } = await import("node:fs");
    // Why: an installer that predates the TUI copy (e.g. an older SSH relay) writes only
    // this file; without the TUI copy nothing else would report, so keep reporting.
    return statSync(ORCA_TUI_PLUGIN_ENTRY).isFile();
  } catch {
    return false;
  }
}

async function setupOpenCode2Status(ctx) {
  const noop = async () => {};
  if (isOpenCode2TuiContext(ctx)) {
    reportingOpenCodeMajor = 2;
    return setupOpenCode2Tui(ctx);
  }
  let hooks;
  // Why: OpenCode may probe setup() with no context during startup, and the setup
  // API shape can drift between releases. Never throw from setup — a throw surfaces
  // as an 'orca-opencode-status' plugin failed error in the TUI, which is worse
  // than silently running without status reporting.
  try {
    if (!ctx || typeof ctx.session?.hook !== "function" || typeof ctx.event?.subscribe !== "function") return noop;
    reportingOpenCodeMajor = 2;
    if (await tuiReportsPaneLifecycle()) return noop;
    const controller = new AbortController();
    // Why the envelope: OpenCode 2's plugin adapter unwraps a single-property
    // { data } success schema, so ctx.session.get resolves to the bare record —
    // but the shared lineage lookup only accepts result?.data?.id === sessionID.
    // Without it, resolveRootSessionID returns null for every session and a
    // subagent's work publishes as if it were the root's.
    const client = { session: { get: async (input, options) => { const result = await ctx.session.get(input, options); return result && typeof result.id === "string" ? { data: result } : result; } } };
    // Why: this host disposes plugins on a hot reload while turns keep running.
    hooks = await OrcaOpenCodeStatusPlugin({ client, sessionsOutliveDispose: true });
    if (!hooks || typeof hooks.event !== "function") return noop;
    const promptRegistration = await ctx.session.hook("prompt", async (properties) => {
      await hooks.event({ event: { type: "session.next.prompt.admitted", properties } });
    });
    const consume = async () => {
      for await (const input of ctx.event.subscribe({ signal: controller.signal })) {
        if (controller.signal.aborted) break;
        const translated = translateOpenCode2Event(input.type, input.data);
        if (!translated) continue;
        await hooks.event({ event: translated });
      }
    };
    const consuming = consume().catch((error) => {
      if (!controller.signal.aborted) console.warn("[orca-hook] event subscription failed:", error.message);
    });
    return async () => {
      try {
        controller.abort();
        // Each owner must finish cleanup even when an earlier disposer rejects.
        try {
          await promptRegistration?.dispose?.();
        } finally {
          try {
            await consuming;
          } finally {
            await hooks.dispose?.();
          }
        }
      } catch {
        // Why: cleanup runs during plugin unload; a throw here also fails the plugin.
      }
    };
  } catch {
    try { await hooks?.dispose?.(); } catch {}
    return noop;
  }
}


const TUI_TICK_MS = 100;
const TUI_PERMISSION_SETTLE_MS = 500;
const TUI_EARLY_ROOTS_MAX = 32;
const TUI_RESOLVED_REQUESTS_MAX = 256;
const TUI_ENDPOINT_CHECK_TICKS = 50;

function isOpenCode2TuiContext(ctx) {
  return typeof ctx?.ui?.router?.current === "function" && typeof ctx?.data?.listen === "function";
}

function boundedSet(set, value, max) {
  set.delete(value);
  set.add(value);
  if (set.size > max) set.delete(set.values().next().value);
}

// Memory survives hot reloads and ends with the TUI.
function paneStatusMemory(ctx) {
  const initial = { owned: [], last: "idle:", lastRoot: "", started: false, endings: [] };
  if (typeof ctx.storage?.memory === "function") return ctx.storage.memory("pane-status", { initial });
  // Why started: without memory a reload looks like a TUI start, and must not reset the pane.
  const local = { ...initial, started: true };
  return [local, (mutate) => mutate(local)];
}

async function setupOpenCode2Tui(ctx) {
  const noop = async () => {};
  // Why: post() needs this pane's key, so a TUI outside an Orca pane has nothing to report.
  if (!process.env.ORCA_PANE_KEY) return noop;
  if (process.env.ORCA_OPENCODE_AGENT && process.env.ORCA_OPENCODE_AGENT !== ORCA_STATUS_AGENT) return noop;
  // Legacy attach contexts enter only through the checked API adapter.
  if (/^1\./.test(String(ctx.app?.version || "")) && !ctx.legacyOpenCodeTui) return noop;
  const data = ctx.data.session;
  if (typeof data?.status !== "function" || typeof data.root !== "function") return noop;
  let factoryID;
  try {
    const [memory, setMemory] = paneStatusMemory(ctx);
    factoryID = ++nextFactoryID;
    activeFactoryIDs.add(factoryID);
    let disposed = false;
    let lastLevel = null;
    let ticks = 0;
    const early = new Map();
    // Why: a permission/form list fetched on reconnect can land after the reply event and restore it.
    const resolved = new Set();
    const permissionSeenAt = new Map();

    const rootOf = (sessionID) => data.root(sessionID) || sessionID;
    const family = (root) => new Set([root, ...(typeof data.family === "function" ? data.family(root) || [] : [])]);
    const running = (root) => [...family(root)].some((id) => data.status(id) === "running");
    const currentRoute = () => {
      const route = ctx.ui.router.current();
      return route?.type === "session" && typeof route.sessionID === "string" ? rootOf(route.sessionID) : undefined;
    };
    const blocker = (root, seenPermissions) => {
      let form;
      for (const member of family(root)) {
        const permission = (data.permission?.list?.(member) || []).find((request) => {
          if (resolved.has(request.id)) return false;
          seenPermissions.add(request.id);
          if (!permissionSeenAt.has(request.id)) permissionSeenAt.set(request.id, Date.now());
          // Auto replies arrive after the request; only an unanswered request needs attention.
          return Date.now() - permissionSeenAt.get(request.id) >= TUI_PERMISSION_SETTLE_MS;
        });
        if (permission) return { request: permission, isPermission: true };
        form ??= (data.form?.list?.(member) || []).find((request) => !resolved.has(request.id));
      }
      return form ? { request: form, isPermission: false } : null;
    };
    const levelKey = (level) =>
      (level.kind === "waiting" ? "waiting:" + level.blocker.request.id + ":" + level.root : level.kind + ":" + level.root) +
      (level.rootFields.root_state ? ":" + JSON.stringify(level.rootFields) : "");

    function rootFields(level) {
      if (!level.root) return {};
      const rootRunning = data.status(level.root) === "running";
      const rootState = rootRunning
        ? level.kind === "waiting" && level.blocker.request.sessionID === level.root ? "waiting" : "working"
        : "done";
      const session = data.get?.(level.root);
      const ending = (memory.endings || []).find(([id]) => id === level.root);
      const idleAt = session?.time?.idle;
      const sameTurn = Number.isFinite(idleAt) && ending?.[2] === idleAt;
      // Current session data repairs a whole turn missed while the plugin was unloaded.
      const errorName = !rootRunning && (session?.outcome === "failed"
        ? (sameTurn && ending[1]) || "UnknownError"
        : session?.outcome === "interrupted" && sameTurn ? ending[1] : "");
      return { root_state: rootState, ...(errorName ? { root_turn_error_name: errorName } : {}) };
    }

    function own(root, owned) {
      const seen = early.get(root);
      early.delete(root);
      if (seen?.created) void enqueueLifecycle(() => post("SessionStart", { sessionID: root }));
      if (seen?.prompt) postPrompt(root, seen.prompt);
      return [...owned, root];
    }

    // Why derive, not infer: OpenCode's session data is the single copy of running/blocked/lineage
    // and self-corrects on reconnect; nothing here latches a start or end event.
    function derive() {
      const route = currentRoute();
      let owned = [...memory.owned];
      if (route && !owned.includes(route) && running(route)) owned = own(route, owned);
      // Why keep a root past navigation: a pane that started a turn must still reach Done
      // when the user browses to another session mid-turn.
      owned = owned.filter((root) => root === route || running(root));
      if (owned.join("\n") !== memory.owned.join("\n")) setMemory((draft) => { draft.owned = owned; });
      const active = owned.filter(running);
      const seenPermissions = new Set();
      let waiting;
      for (const root of active) {
        // Why only while running: a blocker the session data kept after its turn ended is stale.
        const found = blocker(root, seenPermissions);
        if (found && !waiting) waiting = { kind: "waiting", root, blocker: found };
      }
      for (const id of permissionSeenAt.keys()) {
        if (!seenPermissions.has(id)) permissionSeenAt.delete(id);
      }
      if (waiting) return waiting;
      const busy = active.at(-1);
      return busy ? { kind: "busy", root: busy } : { kind: "idle", root: memory.lastRoot };
    }

    function publish() {
      if (disposed) return;
      if (ctx.legacyOpenCodeTui && resolveHookCoords().openCodeTui !== "1") return;
      let level;
      try {
        level = derive();
        level.rootFields = rootFields(level);
      } catch {
        // Why: a data read that throws must not kill the listener or the tick.
        return;
      }
      const key = levelKey(level);
      if (key === memory.last) return;
      setMemory((draft) => {
        draft.last = key;
        if (level.kind !== "idle") draft.lastRoot = level.root;
      });
      lastLevel = level;
      void enqueueLifecycle(() => deliver(level, true));
    }

    async function deliver(level, changed) {
      // Retires assistant text queued under the previous level (see flushPendingAssistantPart).
      if (changed) stateArrivalRevision += 1;
      const properties = level.root ? { sessionID: level.root, ...level.rootFields } : {};
      if (level.kind === "waiting") {
        const { request, isPermission } = level.blocker;
        const translated = ctx.legacyOpenCodeTui ? { properties: request } : isPermission
          ? translateOpenCode2Event("permission.asked", request)
          : translateOpenCode2Event("form.created", { form: request });
        if (!translated) return;
        const hookEventName = isPermission ? "PermissionRequest" : "AskUserQuestion";
        await flushPendingAssistantPart(true);
        await setDeliveryTarget("waiting", levelKey(level), hookEventName, { ...translated.properties, ...properties }, factoryID);
        return;
      }
      if (level.kind === "idle") await flushPendingAssistantPart(true);
      await setDeliveryTarget(level.kind, levelKey(level), level.kind === "busy" ? "SessionBusy" : "SessionIdle", properties, factoryID);
    }

    function postPrompt(root, prompt) {
      void enqueueLifecycle(() =>
        postMessagePart({ role: "user", text: capMessagePartText(prompt.text), messageID: prompt.messageID, sessionID: root }, factoryID),
      );
    }

    function remember(root, update) {
      const seen = { ...(early.get(root) || {}), ...update };
      early.delete(root);
      early.set(root, seen);
      if (early.size > TUI_EARLY_ROOTS_MAX) early.delete(early.keys().next().value);
    }

    // Content only; status comes from derive().
    function observe(event) {
      const properties = event.data || {};
      const sessionID = properties.sessionID;
      if (event.type === "server.connected") {
        // Why: OpenCode re-syncs blockers only for the sessions it displays; an owned session the
        // user navigated away from would otherwise keep a request answered while disconnected.
        for (const root of memory.owned) {
          for (const member of family(root)) {
            void data.permission?.sync?.(member)?.catch?.(() => {});
            void data.form?.sync?.(member)?.catch?.(() => {});
          }
        }
        return;
      }
      if (event.type === "permission.replied") return boundedSet(resolved, properties.requestID, TUI_RESOLVED_REQUESTS_MAX);
      if (event.type === "form.replied" || event.type === "form.cancelled") {
        return boundedSet(resolved, properties.id, TUI_RESOLVED_REQUESTS_MAX);
      }
      if (typeof sessionID !== "string" || !sessionID) return;
      if (event.type === "session.deleted") {
        early.delete(sessionID);
        if (memory.owned.includes(sessionID)) {
          setMemory((draft) => { draft.owned = draft.owned.filter((id) => id !== sessionID); });
        }
        return;
      }
      if (event.type === "session.created") {
        if (!properties.parentID) remember(sessionID, { created: true });
        return;
      }
      const root = rootOf(sessionID);
      const isOwned = memory.owned.includes(root);
      if (ctx.legacyOpenCodeTui && event.type === "message.part.updated") {
        const part = properties.part;
        const role = messageRoleById.get(part?.messageID);
        if (sessionID !== root || part?.type !== "text" || part.synthetic === true || typeof part.text !== "string" || !part.text || memory.last.startsWith("waiting:")) return;
        if (role === "user") {
          const prompt = { text: part.text, messageID: part.messageID };
          if (isOwned) postPrompt(root, prompt); else remember(root, { prompt });
        } else if (role === "assistant" && isOwned) {
          void enqueueLifecycle(() => queueAssistantPart({ role, text: part.text, messageID: part.messageID, sessionID: root, factoryID, authorityRevision: stateArrivalRevision }));
        }
        return;
      }
      if (sessionID === root && (isOwned || currentRoute() === root)) {
        if (event.type === "session.execution.started" || event.type === "session.execution.succeeded" || event.type === "session.execution.failed" || event.type === "session.execution.interrupted") {
          const errorName = event.type === "session.execution.failed"
            ? (typeof properties.error?.type === "string" && properties.error.type) || "UnknownError"
            : event.type === "session.execution.interrupted" && properties.reason === "user" ? "MessageAbortedError" : "";
          // A hot reload keeps the terminal verdict; only this root's next turn replaces it.
          setMemory((draft) => {
            draft.endings = (draft.endings || []).filter(([id]) => id !== root);
            if (errorName) draft.endings = [...draft.endings, [root, errorName, event.created ?? data.get?.(root)?.time?.idle]].slice(-TUI_EARLY_ROOTS_MAX);
          });
        }
      }
      if (event.type === "session.inbox.enqueued") {
        // Why TUI-only: the server takes the prompt from session.hook("prompt"), which a TUI lacks.
        const item = properties.item;
        if (sessionID !== root || item?.type !== "user" || typeof item.payload?.text !== "string" || !item.payload.text) return;
        const prompt = { text: item.payload.text, messageID: properties.inboxID };
        if (!isOwned) return remember(root, { prompt });
        if (!memory.last.startsWith("waiting:")) postPrompt(root, prompt);
        return;
      }
      if (event.type === "session.text.ended" && isOwned && sessionID === root && typeof properties.text === "string" && properties.text) {
        // Why: Orca reads any MessagePart as Working, which would bury this pane's Needs input.
        if (memory.last.startsWith("waiting:")) return;
        const part = { role: "assistant", text: properties.text, messageID: properties.assistantMessageID, sessionID: root, factoryID };
        // Why queued: the reply must not overtake this turn's SessionStart, prompt or Busy.
        void enqueueLifecycle(() => queueAssistantPart({ ...part, authorityRevision: stateArrivalRevision }));
      }
    }

    // Why synchronous: OpenCode applies each event to its session data before plugin listeners
    // run, so deciding here never trails the data, and no queue of events can build up.
    const unsubscribe = ctx.data.listen(({ details } = {}) => {
      if (disposed || !details || typeof details.type !== "string") return;
      try {
        observe(details);
        publish();
      } catch {
        // A malformed event must not break the listener.
      }
    });
    // Why a tick: a route change has no event, and a reconnect re-hydrates the data without one.
    const tick = setInterval(() => {
      try {
        publish();
        // Why: an Orca restart moves the hook endpoint; the delivery layer re-posts an unchanged
        // level only when asked, which the old event-driven path did on every lifecycle event.
        if (++ticks % TUI_ENDPOINT_CHECK_TICKS === 0 && lastLevel && desiredFactoryID === factoryID && deliveredEndpointKey !== hookEndpointKey()) {
          const level = lastLevel;
          void enqueueLifecycle(() => deliver(level, false));
        }
      } catch {}
    }, TUI_TICK_MS);
    if (tick.unref) tick.unref();
    publish();
    if (!memory.started) {
      setMemory((draft) => { draft.started = true; });
      // Why: clears a status an earlier process left on this pane (e.g. a pre-upgrade shared service
      // posting another pane's turn here). Connected idle, never a completion; reloads skip it.
      if (memory.last === "idle:") {
        const route = currentRoute();
        void enqueueLifecycle(() => post("SessionStart", route ? { sessionID: route } : {}));
      }
    }
    return async () => {
      try {
        disposed = true;
        clearInterval(tick);
        if (typeof unsubscribe === "function") unsubscribe();
        // Why publish nothing: a hot reload disposes this mid-turn and the next generation
        // re-derives from the same memory. Unconfirmed delivery is re-derived by that generation.
        await releaseTuiStatusDelivery(factoryID, () => setMemory((draft) => { draft.last = ""; }));
      } catch {
        // Why: cleanup runs during plugin unload; a throw here also fails the plugin.
      }
    };
  } catch {
    if (factoryID !== undefined) activeFactoryIDs.delete(factoryID);
    return noop;
  }
}



// Why queued: levels derived before disposal still post, in order, before the identity retires.
function releaseTuiStatusDelivery(factoryID, forgetUndelivered) {
  return enqueueLifecycle(async () => {
    disposingFactoryIDs.add(factoryID);
    while (messagePartPostInFlight) await messagePartPostInFlight;
    if (pendingAssistantPart?.factoryID === factoryID) {
      if (assistantPartFlushTimer) clearTimeout(assistantPartFlushTimer);
      assistantPartFlushTimer = null;
      pendingAssistantPart = null;
    }
    if (desiredFactoryID === factoryID) {
      if (statusDeliveryDirty) forgetUndelivered();
      clearStatusRetry();
      statusRevision += 1;
    }
    activeFactoryIDs.delete(factoryID);
    disposingFactoryIDs.delete(factoryID);
  });
}


// OpenCode 1 requires a callable default; OpenCode 2 validates a plugin object.
const orcaServerPlugin = process.env.ORCA_OPENCODE_PLUGIN_API === "v1" ? OrcaOpenCodeStatusPlugin : {
  id: "orca-opencode-status",
  server: OrcaOpenCodeStatusPlugin,
  setup: setupOpenCode2Status,
};

const { server: _orcaServerOnly, ...orcaTuiPlugin } = orcaServerPlugin;
export default { id: "orca-opencode-status", setup: setupOpenCode2Status, ...orcaTuiPlugin, tui: setupLegacyOpenCodeTui };
