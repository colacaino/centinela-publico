"use strict";

const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {REGION, ENFORCE_APP_CHECK} = require("./src/constants");
const incidents = require("./src/incidents");
const users = require("./src/users");
const installations = require("./src/installations");
const notifications = require("./src/notifications");
const esp32 = require("./src/esp32");
const maintenance = require("./src/maintenance");

initializeApp();
setGlobalOptions({region: REGION, maxInstances: 20});

const callableOptions = {
  region: REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
};

exports.crearIncidenteV2 = onCall(callableOptions, incidents.createIncident);
exports.reconocerIncidenteV2 = onCall(callableOptions, incidents.acknowledgeIncident);
exports.resolverIncidenteV2 = onCall(callableOptions, incidents.resolveIncident);
exports.cancelarIncidenteV2 = onCall(callableOptions, incidents.cancelIncident);

exports.registrarInstalacionV2 = onCall(callableOptions, installations.registerInstallation);
exports.desactivarInstalacionV2 = onCall(callableOptions, installations.deactivateInstallation);

exports.crearUsuarioV2 = onCall(callableOptions, users.createUser);
exports.actualizarUsuarioV2 = onCall(callableOptions, users.updateUser);
exports.establecerUsuarioActivoV2 = onCall(callableOptions, users.setUserActive);
exports.eliminarUsuarioV2 = onCall(callableOptions, users.deleteUser);
exports.cambiarContrasenaInicialV2 = onCall(callableOptions, users.changeInitialPassword);

exports.notificarIncidenteV2 = onDocumentCreated(
    {
      document: "incidentes/{incidentId}",
      region: REGION,
      retry: true,
      maxInstances: 20,
    },
    notifications.notifyCreatedIncident,
);

exports.expirarIncidentesV2 = onSchedule(
    {
      schedule: "every 1 minutes",
      region: REGION,
      timeZone: "America/Santiago",
      retryCount: 3,
    },
    maintenance.expireIncidents,
);

exports.alertaDesdeDispositivoV2 = onRequest(
    {
      region: REGION,
      invoker: "public",
      secrets: ["CENTINELA_ESP32_DEVICE"],
      maxInstances: 10,
      timeoutSeconds: 30,
    },
    esp32.receiveDeviceAlert,
);
