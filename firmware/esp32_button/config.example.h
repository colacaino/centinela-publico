#pragma once

// Copia este archivo como config.h (está ignorado por Git) y reemplaza todo.
#define WIFI_SSID "REEMPLAZAR"
#define WIFI_PASSWORD "REEMPLAZAR"
#define ENDPOINT_URL "https://southamerica-east1-PROYECTO.cloudfunctions.net/alertaDesdeDispositivoV2"
#define DEVICE_ID "REEMPLAZAR_POR_ID_REGISTRADO"
#define DEVICE_SECRET "REEMPLAZAR_POR_SECRETO_ALEATORIO_DE_32_BYTES_O_MAS"

// No se encontró el firmware físico original. Debes validar estos GPIO contra
// la placa y el circuito reales antes de compilar.
#define BUTTON_GPIO -1
#define STATUS_LED_GPIO -1
#define ALERT_LEVEL "3"

// PEM de la CA raíz que valida el certificado HTTPS del endpoint. No uses
// setInsecure(); obtiene la CA vigente de la cadena TLS desplegada.
static const char TLS_ROOT_CA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
REEMPLAZAR_POR_CA_RAIZ_VIGENTE
-----END CERTIFICATE-----
)EOF";
