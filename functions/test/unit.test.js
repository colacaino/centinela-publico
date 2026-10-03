"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {canonicalRequest, validSignature} = require("../src/esp32");
const {incidentIdFor, isExpired} = require("../src/incidents");
const {Timestamp} = require("firebase-admin/firestore");
const {boundedInteger, RECIPIENT_ROLES} = require("../src/constants");

test("la clave de idempotencia produce un identificador estable y aislado", () => {
  assert.equal(incidentIdFor("user-a", "request-1234"), incidentIdFor("user-a", "request-1234"));
  assert.notEqual(incidentIdFor("user-a", "request-1234"), incidentIdFor("user-b", "request-1234"));
  assert.match(incidentIdFor("user-a", "request-1234"), /^inc_[a-f0-9]{40}$/);
});

test("HMAC valida el contenido canónico y rechaza alteraciones", () => {
  const input = {
    deviceId: "device_01",
    nivel: "3",
    timestamp: 1_800_000_000,
    nonce: "nonce-12345678",
    idempotencyKey: "request-12345678",
  };
  const secret = "a-secure-test-secret-with-at-least-32-bytes";
  const canonical = canonicalRequest(input);
  const signature = crypto.createHmac("sha256", secret).update(canonical).digest("hex");
  assert.equal(validSignature(canonical, signature, secret), true);
  assert.equal(validSignature(canonical.replace("\n3\n", "\n2\n"), signature, secret), false);
  assert.equal(validSignature(canonical, "not-a-signature", secret), false);
});

test("la vigencia usa expiresAt y no el reloj del emisor", () => {
  assert.equal(isExpired({expiresAt: Timestamp.fromMillis(Date.now() - 1)}, Date.now()), true);
  assert.equal(isExpired({expiresAt: Timestamp.fromMillis(Date.now() + 10_000)}, Date.now()), false);
});

test("el TTL se acota y los roles por nivel son explícitos", () => {
  assert.equal(boundedInteger("1", 120, 30, 900), 30);
  assert.equal(boundedInteger("9999", 120, 30, 900), 900);
  assert.deepEqual(RECIPIENT_ROLES["1"], ["inspector", "admin"]);
  assert.deepEqual(RECIPIENT_ROLES["3"], ["inspector", "direccion", "admin"]);
});
