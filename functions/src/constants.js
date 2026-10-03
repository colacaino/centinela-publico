"use strict";

const REGION = "southamerica-east1";
const ROLES = Object.freeze(["docente", "inspector", "direccion", "admin"]);
const LEVELS = Object.freeze(["1", "2", "3"]);
const STATES = Object.freeze({
  CREATED: "CREATED",
  NOTIFIED: "NOTIFIED",
  ACKNOWLEDGED: "ACKNOWLEDGED",
  RESOLVED: "RESOLVED",
  CANCELLED: "CANCELLED",
  EXPIRED: "EXPIRED",
});
const TERMINAL_STATES = Object.freeze([
  STATES.RESOLVED,
  STATES.CANCELLED,
  STATES.EXPIRED,
]);
const LEVEL_LABELS = Object.freeze({
  "1": "Emergencia médica",
  "2": "Riña / intruso",
  "3": "Arma / riesgo vital",
});
const RECIPIENT_ROLES = Object.freeze({
  "1": ["inspector", "admin"],
  "2": ["inspector", "direccion", "admin"],
  "3": ["inspector", "direccion", "admin"],
});

function boundedInteger(value, fallback, minimum, maximum) {
  const parsed = Number.parseInt(String(value || ""), 10);
  return Number.isFinite(parsed) ? Math.min(maximum, Math.max(minimum, parsed)) : fallback;
}

const INCIDENT_TTL_SECONDS = boundedInteger(
    process.env.INCIDENT_TTL_SECONDS,
    120,
    30,
    900,
);
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

module.exports = {
  REGION,
  ROLES,
  LEVELS,
  STATES,
  TERMINAL_STATES,
  LEVEL_LABELS,
  RECIPIENT_ROLES,
  INCIDENT_TTL_SECONDS,
  ENFORCE_APP_CHECK,
  boundedInteger,
};
