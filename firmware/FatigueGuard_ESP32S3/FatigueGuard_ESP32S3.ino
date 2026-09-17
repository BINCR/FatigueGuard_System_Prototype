/* Edge Impulse Arduino examples
 * Copyright (c) 2022 EdgeImpulse Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// These sketches are tested with 2.0.4 ESP32 Arduino Core
// https://github.com/espressif/arduino-esp32/releases/tag/2.0.4

/* Includes ---------------------------------------------------------------- */
#include <FatigueGuard_inferencing.h>
#include "edge-impulse-sdk/dsp/image/image.hpp"

#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>
#include <string.h>

// Select camera model
#define CAMERA_MODEL_ESP32S3_EYE
//#define CAMERA_MODEL_AI_THINKER

#if defined(CAMERA_MODEL_ESP32S3_EYE)

#define PWDN_GPIO_NUM     -1
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     15
#define SIOD_GPIO_NUM     4
#define SIOC_GPIO_NUM     5

#define Y9_GPIO_NUM       16
#define Y8_GPIO_NUM       17
#define Y7_GPIO_NUM       18
#define Y6_GPIO_NUM       12
#define Y5_GPIO_NUM       10
#define Y4_GPIO_NUM       8
#define Y3_GPIO_NUM       9
#define Y2_GPIO_NUM       11
#define VSYNC_GPIO_NUM    6
#define HREF_GPIO_NUM     7
#define PCLK_GPIO_NUM     13

#elif defined(CAMERA_MODEL_AI_THINKER)

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM       5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#else

#error "Camera model not selected"

#endif

/* Constant defines -------------------------------------------------------- */
#define EI_CAMERA_RAW_FRAME_BUFFER_COLS 320
#define EI_CAMERA_RAW_FRAME_BUFFER_ROWS 240
#define EI_CAMERA_FRAME_BYTE_SIZE 3

/* Edge Impulse and camera variables --------------------------------------- */
static bool debug_nn = false;
static bool is_initialised = false;

uint8_t *snapshot_buf;

/* Wi-Fi access point settings --------------------------------------------- */
const char *AP_SSID = "FatigueGuard-ESP32";
const char *AP_PASSWORD = "Fatigue123";

/* HTTP server ------------------------------------------------------------- */
WebServer server(80);
TaskHandle_t web_server_task_handle = nullptr;

/* Latest classification result ------------------------------------------- */
portMUX_TYPE result_mux = portMUX_INITIALIZER_UNLOCKED;

char latest_label[32] = "waiting";
float latest_confidence = 0.0f;

/* Camera configuration ---------------------------------------------------- */
static camera_config_t camera_config = {
    .pin_pwdn = PWDN_GPIO_NUM,
    .pin_reset = RESET_GPIO_NUM,
    .pin_xclk = XCLK_GPIO_NUM,
    .pin_sscb_sda = SIOD_GPIO_NUM,
    .pin_sscb_scl = SIOC_GPIO_NUM,

    .pin_d7 = Y9_GPIO_NUM,
    .pin_d6 = Y8_GPIO_NUM,
    .pin_d5 = Y7_GPIO_NUM,
    .pin_d4 = Y6_GPIO_NUM,
    .pin_d3 = Y5_GPIO_NUM,
    .pin_d2 = Y4_GPIO_NUM,
    .pin_d1 = Y3_GPIO_NUM,
    .pin_d0 = Y2_GPIO_NUM,
    .pin_vsync = VSYNC_GPIO_NUM,
    .pin_href = HREF_GPIO_NUM,
    .pin_pclk = PCLK_GPIO_NUM,

    .xclk_freq_hz = 20000000,
    .ledc_timer = LEDC_TIMER_0,
    .ledc_channel = LEDC_CHANNEL_0,

    .pixel_format = PIXFORMAT_JPEG,
    .frame_size = FRAMESIZE_QVGA,

    .jpeg_quality = 12,
    .fb_count = 1,
    .fb_location = CAMERA_FB_IN_PSRAM,
    .grab_mode = CAMERA_GRAB_WHEN_EMPTY,
};

/* Function declarations --------------------------------------------------- */
bool ei_camera_init(void);
void ei_camera_deinit(void);

bool ei_camera_capture(
    uint32_t img_width,
    uint32_t img_height,
    uint8_t *out_buf
);

void update_latest_result(
    const char *label,
    float confidence
);

void add_cors_headers(void);
void handle_root(void);
void handle_status(void);
void handle_options(void);
void start_wifi_api(void);
void web_server_task(void *parameter);

/* Save the latest classification result ---------------------------------- */
void update_latest_result(
    const char *label,
    float confidence
) {
    portENTER_CRITICAL(&result_mux);

    strncpy(
        latest_label,
        label,
        sizeof(latest_label) - 1
    );

    latest_label[sizeof(latest_label) - 1] = '\0';
    latest_confidence = confidence;

    portEXIT_CRITICAL(&result_mux);
}

/* Add browser/Flutter Web permissions ------------------------------------ */
void add_cors_headers(void) {
    server.sendHeader(
        "Access-Control-Allow-Origin",
        "*"
    );

    server.sendHeader(
        "Access-Control-Allow-Methods",
        "GET, OPTIONS"
    );

    server.sendHeader(
        "Access-Control-Allow-Headers",
        "Content-Type"
    );

    server.sendHeader(
        "Cache-Control",
        "no-store"
    );
}

/* Root API endpoint ------------------------------------------------------- */
void handle_root(void) {
    add_cors_headers();

    server.send(
        200,
        "application/json",
        "{\"device\":\"FatigueGuard ESP32-S3\","
        "\"status\":\"online\","
        "\"endpoint\":\"/status\"}"
    );
}

/* Classification API endpoint -------------------------------------------- */
void handle_status(void) {
    char label_copy[32];
    float confidence_copy;

    portENTER_CRITICAL(&result_mux);

    strncpy(
        label_copy,
        latest_label,
        sizeof(label_copy) - 1
    );

    label_copy[sizeof(label_copy) - 1] = '\0';
    confidence_copy = latest_confidence;

    portEXIT_CRITICAL(&result_mux);

    char json[128];

    snprintf(
        json,
        sizeof(json),
        "{\"label\":\"%s\",\"confidence\":%.5f}",
        label_copy,
        confidence_copy
    );

    add_cors_headers();

    server.send(
        200,
        "application/json",
        json
    );
}

/* Respond to browser OPTIONS requests ------------------------------------ */
void handle_options(void) {
    add_cors_headers();

    server.send(
        204,
        "text/plain",
        ""
    );
}

/* Keep HTTP responsive while ML inference is running --------------------- */
void web_server_task(void *parameter) {
    while (true) {
        server.handleClient();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

/* Start ESP32 Wi-Fi hotspot and HTTP server ------------------------------- */
void start_wifi_api(void) {
    WiFi.mode(WIFI_AP);

    IPAddress local_ip(192, 168, 4, 1);
    IPAddress gateway(192, 168, 4, 1);
    IPAddress subnet(255, 255, 255, 0);

    WiFi.softAPConfig(
        local_ip,
        gateway,
        subnet
    );

    bool ap_started = WiFi.softAP(
        AP_SSID,
        AP_PASSWORD
    );

    if (!ap_started) {
        Serial.println(
            "Failed to start Wi-Fi access point"
        );

        return;
    }

    server.on(
        "/",
        HTTP_GET,
        handle_root
    );

    server.on(
        "/status",
        HTTP_GET,
        handle_status
    );

    server.on(
        "/status",
        HTTP_OPTIONS,
        handle_options
    );

    server.onNotFound([]() {
        add_cors_headers();

        server.send(
            404,
            "application/json",
            "{\"error\":\"Not found\"}"
        );
    });

    server.begin();

    BaseType_t task_created = xTaskCreatePinnedToCore(
        web_server_task,
        "FatigueGuardWebServer",
        8192,
        nullptr,
        1,
        &web_server_task_handle,
        0
    );

    Serial.println();
    Serial.println(
        "FatigueGuard Wi-Fi API started"
    );

    Serial.print("Wi-Fi name: ");
    Serial.println(AP_SSID);

    Serial.print("Wi-Fi password: ");
    Serial.println(AP_PASSWORD);

    Serial.print("Status URL: http://");
    Serial.print(WiFi.softAPIP());
    Serial.println("/status");

    if (task_created != pdPASS) {
        Serial.println(
            "Failed to start HTTP server task"
        );
    }
}

/* Arduino setup ----------------------------------------------------------- */
void setup() {
    Serial.begin(115200);

    // Prevent the board from waiting forever when powered without a PC.
    unsigned long serial_wait_started = millis();

    while (
        !Serial &&
        millis() - serial_wait_started < 3000
    ) {
        delay(10);
    }

    Serial.println(
        "Edge Impulse Inferencing Demo"
    );

    if (ei_camera_init() == false) {
        ei_printf(
            "Failed to initialize Camera!\r\n"
        );
    }
    else {
        ei_printf(
            "Camera initialized\r\n"
        );
    }

    start_wifi_api();

    ei_printf(
        "\nStarting continuous inference in 2 seconds...\n"
    );

    ei_sleep(2000);
}

/* Capture image and run inference ---------------------------------------- */
void loop() {
    if (ei_sleep(5) != EI_IMPULSE_OK) {
        return;
    }

    snapshot_buf = (uint8_t *)malloc(
        EI_CAMERA_RAW_FRAME_BUFFER_COLS *
        EI_CAMERA_RAW_FRAME_BUFFER_ROWS *
        EI_CAMERA_FRAME_BYTE_SIZE
    );

    if (snapshot_buf == nullptr) {
        ei_printf(
            "ERR: Failed to allocate snapshot buffer!\n"
        );

        update_latest_result(
            "uncertain",
            0.0f
        );

        return;
    }

    ei::signal_t signal;

    signal.total_length =
        EI_CLASSIFIER_INPUT_WIDTH *
        EI_CLASSIFIER_INPUT_HEIGHT;

    signal.get_data = &ei_camera_get_data;

    if (
        ei_camera_capture(
            (size_t)EI_CLASSIFIER_INPUT_WIDTH,
            (size_t)EI_CLASSIFIER_INPUT_HEIGHT,
            snapshot_buf
        ) == false
    ) {
        ei_printf(
            "Failed to capture image\r\n"
        );

        update_latest_result(
            "uncertain",
            0.0f
        );

        free(snapshot_buf);
        return;
    }

    ei_impulse_result_t result = {0};

    EI_IMPULSE_ERROR err = run_classifier(
        &signal,
        &result,
        debug_nn
    );

    if (err != EI_IMPULSE_OK) {
        ei_printf(
            "ERR: Failed to run classifier (%d)\n",
            err
        );

        update_latest_result(
            "uncertain",
            0.0f
        );

        free(snapshot_buf);
        return;
    }

    ei_printf(
        "Predictions "
        "(DSP: %d ms., "
        "Classification: %d ms., "
        "Anomaly: %d ms.):\n",
        result.timing.dsp,
        result.timing.classification,
        result.timing.anomaly
    );

#if EI_CLASSIFIER_OBJECT_DETECTION == 1

    ei_printf(
        "Object detection bounding boxes:\r\n"
    );

    const char *best_label = "uncertain";
    float best_confidence = 0.0f;

    for (
        uint32_t i = 0;
        i < result.bounding_boxes_count;
        i++
    ) {
        ei_impulse_result_bounding_box_t bb =
            result.bounding_boxes[i];

        if (bb.value == 0) {
            continue;
        }

        ei_printf(
            "  %s (%f) "
            "[x: %u, y: %u, width: %u, height: %u]\r\n",
            bb.label,
            bb.value,
            bb.x,
            bb.y,
            bb.width,
            bb.height
        );

        if (bb.value > best_confidence) {
            best_confidence = bb.value;
            best_label = bb.label;
        }
    }

    if (best_confidence < 0.50f) {
        update_latest_result(
            "uncertain",
            best_confidence
        );
    }
    else {
        update_latest_result(
            best_label,
            best_confidence
        );
    }

#else

    ei_printf("Predictions:\r\n");

    const char *best_label = "uncertain";
    float best_confidence = 0.0f;

    for (
        uint16_t i = 0;
        i < EI_CLASSIFIER_LABEL_COUNT;
        i++
    ) {
        ei_printf(
            "  %s: ",
            ei_classifier_inferencing_categories[i]
        );

        ei_printf(
            "%.5f\r\n",
            result.classification[i].value
        );

        if (
            result.classification[i].value >
            best_confidence
        ) {
            best_confidence =
                result.classification[i].value;

            best_label =
                ei_classifier_inferencing_categories[i];
        }
    }

    if (best_confidence < 0.50f) {
        update_latest_result(
            "uncertain",
            best_confidence
        );
    }
    else {
        update_latest_result(
            best_label,
            best_confidence
        );
    }

#endif

#if EI_CLASSIFIER_HAS_ANOMALY

    ei_printf(
        "Anomaly prediction: %.3f\r\n",
        result.anomaly
    );

#endif

#if EI_CLASSIFIER_HAS_VISUAL_ANOMALY

    ei_printf("Visual anomalies:\r\n");

    for (
        uint32_t i = 0;
        i < result.visual_ad_count;
        i++
    ) {
        ei_impulse_result_bounding_box_t bb =
            result.visual_ad_grid_cells[i];

        if (bb.value == 0) {
            continue;
        }

        ei_printf(
            "  %s (%f) "
            "[x: %u, y: %u, width: %u, height: %u]\r\n",
            bb.label,
            bb.value,
            bb.x,
            bb.y,
            bb.width,
            bb.height
        );
    }

#endif

    free(snapshot_buf);
}

/* Initialize camera ------------------------------------------------------- */
bool ei_camera_init(void) {
    if (is_initialised) {
        return true;
    }

#if defined(CAMERA_MODEL_ESP_EYE)

    pinMode(13, INPUT_PULLUP);
    pinMode(14, INPUT_PULLUP);

#endif

    esp_err_t err = esp_camera_init(
        &camera_config
    );

    if (err != ESP_OK) {
        Serial.printf(
            "Camera init failed with error 0x%x\n",
            err
        );

        return false;
    }

    sensor_t *sensor = esp_camera_sensor_get();

    if (sensor->id.PID == OV3660_PID) {
        sensor->set_vflip(sensor, 1);
        sensor->set_brightness(sensor, 1);
        sensor->set_saturation(sensor, 0);
    }

#if defined(CAMERA_MODEL_M5STACK_WIDE)

    sensor->set_vflip(sensor, 1);
    sensor->set_hmirror(sensor, 1);

#elif defined(CAMERA_MODEL_ESP_EYE)

    sensor->set_vflip(sensor, 1);
    sensor->set_hmirror(sensor, 1);
    sensor->set_awb_gain(sensor, 1);

#endif

    is_initialised = true;
    return true;
}

/* Deinitialize camera ----------------------------------------------------- */
void ei_camera_deinit(void) {
    esp_err_t err = esp_camera_deinit();

    if (err != ESP_OK) {
        ei_printf(
            "Camera deinit failed\n"
        );

        return;
    }

    is_initialised = false;
}

/* Capture, convert, crop and resize camera image -------------------------- */
bool ei_camera_capture(
    uint32_t img_width,
    uint32_t img_height,
    uint8_t *out_buf
) {
    bool do_resize = false;

    if (!is_initialised) {
        ei_printf(
            "ERR: Camera is not initialized\r\n"
        );

        return false;
    }

    camera_fb_t *frame_buffer =
        esp_camera_fb_get();

    if (!frame_buffer) {
        ei_printf(
            "Camera capture failed\n"
        );

        return false;
    }

    bool converted = fmt2rgb888(
        frame_buffer->buf,
        frame_buffer->len,
        PIXFORMAT_JPEG,
        snapshot_buf
    );

    esp_camera_fb_return(frame_buffer);

    if (!converted) {
        ei_printf(
            "Conversion failed\n"
        );

        return false;
    }

    if (
        img_width != EI_CAMERA_RAW_FRAME_BUFFER_COLS ||
        img_height != EI_CAMERA_RAW_FRAME_BUFFER_ROWS
    ) {
        do_resize = true;
    }

    if (do_resize) {
        ei::image::processing::crop_and_interpolate_rgb888(
            out_buf,
            EI_CAMERA_RAW_FRAME_BUFFER_COLS,
            EI_CAMERA_RAW_FRAME_BUFFER_ROWS,
            out_buf,
            img_width,
            img_height
        );
    }

    return true;
}

/* Pass image pixels to Edge Impulse -------------------------------------- */
static int ei_camera_get_data(
    size_t offset,
    size_t length,
    float *out_ptr
) {
    size_t pixel_ix = offset * 3;
    size_t pixels_left = length;
    size_t out_ptr_ix = 0;

    while (pixels_left != 0) {
        out_ptr[out_ptr_ix] =
            (snapshot_buf[pixel_ix + 2] << 16) +
            (snapshot_buf[pixel_ix + 1] << 8) +
            snapshot_buf[pixel_ix];

        out_ptr_ix++;
        pixel_ix += 3;
        pixels_left--;
    }

    return 0;
}

#if !defined(EI_CLASSIFIER_SENSOR) || \
    EI_CLASSIFIER_SENSOR != EI_CLASSIFIER_SENSOR_CAMERA

#error "Invalid model for current sensor"

#endif