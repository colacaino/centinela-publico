"use strict";

const crypto = require("node:crypto");
const {SecretManagerServiceClient} = require("@google-cloud/secret-manager");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const {LEVEL_LABELS, STATES, INCIDENT_TTL_SECONDS} = require("./constants");
const {validateLevel, incidentIdFor, retentionDate} = require("./incidents");
const {safeId, idempotencyKey, requestFingerprint, sha256} = require("./validation");

let secretManager = null;
const secretCache = new Map();
const CLOCK_SKEW_SECONDS = 120;

function canonicalRequest(input) {
  return [input.deviceId, input.nivel, String(input.timestamp), input.nonce, input.idempotencyKey].join("\n");
}

function validSignature(canonical, signature, secret) {
  if (!/^[a-fA-F0-9]{64}$/.test(signature)) return false;
  const expected = crypto.createHmac("sha256", secret).update(canonical).digest();
  const received = Buffer.from(signature, "hex");
  return received.length === expected.length && crypto.timingSafeEqual(received, expected);
}

async function deviceSecret(secretId) {
  const cached = secretCache.get(secretId);
  if (cached && cached.expiresAt > Date.now()) return cached.value;
  const projectId = process.env.ESP32_SECRET_PROJECT_ID || process.env.GCLOUD_PROJECT;
  if (!projectId) throw new Error("secret_project_not_configured");
  secretManager ||= new SecretManagerServiceClient();
  const [version] = await secretManager.accessSecretVersion({
    name: `projects/${projectId}/secrets/${secretId}/versions/latest`,
  });
  const value = version.payload && version.payload.data ? version.payload.data.toString("utf8") : "";
  if (value.length < 32) throw new Error("device_secret_invalid");
  secretCache.set(secretId, {value, expiresAt: Date.now() + 5 * 60_000});
  return value;
}

function parseBody(req) {
  const body = typeof req.body === "object" && req.body !== null ? req.body : {};
  const deviceId = safeId(body.deviceId, "deviceId");
  const nivel = validateLevel(body.nivel);
  const timestamp = Number.parseInt(String(body.timestamp || ""), 10);
  if (!Number.isSafeInteger(timestamp)) throw new Error("invalid_timestamp");
  const nonce = idempotencyKey(body.nonce);
  const key = idempotencyKey(body.idempotencyKey);
  const signature = String(body.signature || "").trim();
  return {deviceId, nivel, timestamp, nonce, idempotencyKey: key, signature};
}

async function createDeviceIncident(db, deviceRef, device, input) {
  const incidentId = incidentIdFor(`device:${input.deviceId}`, input.idempotencyKey);
  const incidentRef = db.collection("incidentes").doc(incidentId);
  const nonceRef = deviceRef.collection("nonces").doc(sha256(input.nonce));
  const rateRef = db.collection("limites").doc(`dispositivo_${input.deviceId}`);
  const nowMillis = Date.now();
  const fingerprint = requestFingerprint({nivel: input.nivel, dispositivoId: input.deviceId});
  let roomName = "Ubicación no especificada";
  if (device.salaId) {
    const room = await db.collection("sedes").doc(device.sedeId).collection("salas").doc(device.salaId).get();
    if (room.exists && room.data().active !== false) roomName = String(room.data().nombre || device.salaId).slice(0, 120);
  }
  return db.runTransaction(async (transaction) => {
    const [existing, usedNonce, rate] = await Promise.all([
      transaction.get(incidentRef),
      transaction.get(nonceRef),
      transaction.get(rateRef),
    ]);
    if (existing.exists) {
      if (existing.data().requestFingerprint !== fingerprint) throw new Error("idempotency_conflict");
      return {incidentId, duplicate: true};
    }
    if (usedNonce.exists) throw new Error("replayed_nonce");
    const timestamps = rate.exists && Array.isArray(rate.data().timestamps) ?
      rate.data().timestamps.filter((value) => Number.isFinite(value) && value > nowMillis - 60_000) : [];
    const last = timestamps.length ? timestamps[timestamps.length - 1] : 0;
    if (timestamps.length >= 10 || nowMillis - last < 3_000) throw new Error("rate_limited");
    timestamps.push(nowMillis);
    const now = Timestamp.fromMillis(nowMillis);
    const expiresAt = Timestamp.fromMillis(nowMillis + INCIDENT_TTL_SECONDS * 1000);
    transaction.create(incidentRef, {
      schemaVersion: 2,
      nivel: input.nivel,
      etiqueta: LEVEL_LABELS[input.nivel],
      sedeId: device.sedeId,
      salaId: device.salaId || null,
      salaNombreSnapshot: roomName,
      origen: "esp32",
      emisorUid: null,
      nombreEmisorSnapshot: String(device.nombre || "Botón físico").slice(0, 120),
      dispositivoId: input.deviceId,
      simulacro: device.simulacro === true,
      estado: STATES.CREATED,
      createdAt: now,
      expiresAt,
      retentionDeleteAt: null,
      acknowledgedAt: null,
      acknowledgedBy: null,
      acknowledgedByName: null,
      resolvedAt: null,
      resolvedBy: null,
      cancelledAt: null,
      cancelledBy: null,
      cancellationReason: null,
      fanoutStatus: "PENDING",
      fanoutAttempts: 0,
      deliveredCount: 0,
      failedCount: 0,
      requestFingerprint: fingerprint,
      updatedAt: now,
    });
    transaction.create(incidentRef.collection("eventos").doc(), {
      type: "CREATED", at: now, actorUid: null, actorRole: null, source: "esp32", deviceId: input.deviceId,
    });
    transaction.create(nonceRef, {usedAt: now, retentionDeleteAt: retentionDate(now)});
    transaction.set(rateRef, {timestamps, updatedAt: now});
    return {incidentId, duplicate: false, expiresAt: expiresAt.toMillis()};
  });
}

async function receiveDeviceAlert(req, res) {
  res.set("Cache-Control", "no-store");
  if (req.method !== "POST") {
    res.status(405).json({ok: false, code: "method_not_allowed"});
    return;
  }
  if (Number(req.get("content-length") || 0) > 4096) {
    res.status(413).json({ok: false, code: "payload_too_large"});
    return;
  }
  let input;
  try {
    input = parseBody(req);
  } catch (error) {
    res.status(400).json({ok: false, code: "invalid_request"});
    return;
  }
  if (Math.abs(Math.floor(Date.now() / 1000) - input.timestamp) > CLOCK_SKEW_SECONDS) {
    res.status(401).json({ok: false, code: "stale_request"});
    return;
  }
  const db = getFirestore();
  const deviceRef = db.collection("dispositivos").doc(input.deviceId);
  const snapshot = await deviceRef.get();
  const device = snapshot.exists ? snapshot.data() : null;
  if (!device || device.active !== true || !device.sedeId || !device.secretId) {
    res.status(403).json({ok: false, code: "device_not_authorized"});
    return;
  }
  try {
    safeId(device.sedeId, "sedeId");
    safeId(device.secretId, "secretId");
    const secret = await deviceSecret(device.secretId);
    if (!validSignature(canonicalRequest(input), input.signature, secret)) {
      logger.warn("device_signature_rejected", {deviceId: input.deviceId});
      res.status(403).json({ok: false, code: "invalid_signature"});
      return;
    }
    const result = await createDeviceIncident(db, deviceRef, device, input);
    logger.info("device_incident_created", {
      incidentId: result.incidentId,
      deviceId: input.deviceId,
      siteId: device.sedeId,
      level: input.nivel,
      duplicate: result.duplicate,
    });
    res.status(200).json({ok: true, ...result});
  } catch (error) {
    const code = String(error.message || "");
    if (["replayed_nonce", "idempotency_conflict"].includes(code)) {
      res.status(409).json({ok: false, code});
      return;
    }
    if (code === "rate_limited") {
      res.status(429).json({ok: false, code});
      return;
    }
    logger.error("device_incident_failed", {deviceId: input.deviceId, code: error.code || code});
    res.status(500).json({ok: false, code: "internal"});
  }
}

module.exports = {canonicalRequest, validSignature, parseBody, createDeviceIncident, receiveDeviceAlert};
