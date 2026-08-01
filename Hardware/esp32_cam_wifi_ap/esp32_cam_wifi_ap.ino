#include "esp_camera.h"
#include <WiFi.h>
#include "esp_http_server.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// AI-Thinker ESP32-CAM Pin Definitions
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Wi-Fi Access Point Settings
const char* ssid = "EasyLens-Camera";
const char* password = ""; // Open network

httpd_handle_t stream_httpd = NULL;

#define PART_BOUNDARY "123456789000000000000987654321"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static esp_err_t stream_handler(httpd_req_t *req){
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t * _jpg_buf = NULL;
  char part_buf[128];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if(res != ESP_OK){
    return res;
  }

  // Stream loop
  while(true){
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      res = ESP_FAIL;
      break;
    } else {
      _jpg_buf_len = fb->len;
      _jpg_buf = fb->buf;
    }
    
    if(res == ESP_OK){
      size_t hlen = snprintf(part_buf, sizeof(part_buf), _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, part_buf, hlen);
    }
    if(res == ESP_OK){
      res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
    }
    if(res == ESP_OK){
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    
    if(fb){
      esp_camera_fb_return(fb);
      fb = NULL;
      _jpg_buf = NULL;
    }
    
    if(res != ESP_OK){
      break;
    }
    
    taskYIELD();
  }
  return res;
}

#define FLASH_GPIO_NUM 4

static esp_err_t led_handler(httpd_req_t *req) {
  char* buf;
  size_t buf_len;
  char val[32] = {0,};

  buf_len = httpd_req_get_url_query_len(req) + 1;
  if (buf_len > 1) {
    buf = (char*)malloc(buf_len);
    if (buf) {
      if (httpd_req_get_url_query_str(req, buf, buf_len) == ESP_OK) {
        if (httpd_query_key_value(buf, "val", val, sizeof(val)) == ESP_OK) {
          int led_val = atoi(val);
          digitalWrite(FLASH_GPIO_NUM, led_val ? HIGH : LOW);
          Serial.printf("LED Flash set to: %d\n", led_val);
        }
      }
      free(buf);
    }
  }

  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  httpd_resp_send(req, "OK", 2);
  return ESP_OK;
}

void startCameraServer(){
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 81;                      // Stream port
  config.ctrl_port = 32768;
  config.max_open_sockets = 1;                  // Single client stream lock to prevent drops
  config.lru_purge_enable = true;                // Purge stagnant sockets immediately
  config.task_priority = tskIDLE_PRIORITY + 5;  // Elevate stream priority
  config.recv_wait_timeout = 5;                 // 5s recv timeout
  config.send_wait_timeout = 5;                 // 5s send timeout

  httpd_uri_t stream_uri = {
    .uri       = "/stream",
    .method    = HTTP_GET,
    .handler   = stream_handler,
    .user_ctx  = NULL
  };

  httpd_uri_t led_uri = {
    .uri       = "/led",
    .method    = HTTP_GET,
    .handler   = led_handler,
    .user_ctx  = NULL
  };
  
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
    httpd_register_uri_handler(stream_httpd, &led_uri);
  }
}

void setup() {
  // Disable ESP32 Brownout Detector to prevent power-dip Wi-Fi disconnections & reboots
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);

  // Initialize flash LED pin
  pinMode(FLASH_GPIO_NUM, OUTPUT);
  digitalWrite(FLASH_GPIO_NUM, LOW);
  
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;              // 20MHz XCLK unlocks max 50-60 FPS sensor clock
  config.pixel_format = PIXFORMAT_JPEG;
  
  // MAX PERFORMANCE & ULTRA-HIGH RESOLUTION CONFIGURATION
  // Sets VGA (640x480) HD resolution and high quality regardless of PSRAM flag
  bool hasPsram = psramFound();
  config.frame_size = FRAMESIZE_VGA;             // 640x480 HD Ultra-Clear Resolution
  config.jpeg_quality = 10;                       // 10 delivers maximum sharp image detail
  config.fb_count = hasPsram ? 2 : 1;             // 2 frame buffers for PSRAM, 1 for internal SRAM
  config.grab_mode = CAMERA_GRAB_LATEST;          // Always grab newest frame for zero lag
  if (hasPsram) {
    config.fb_location = CAMERA_FB_IN_PSRAM;
  }

  // Camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // Hardware DSP Image Enhancements for Maximum Sharpness & Detail
  sensor_t * s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_brightness(s, 0);     // Normal bright clarity
    s->set_contrast(s, 2);       // Max Hardware Contrast boost (+2) for super crisp edges
    s->set_sharpness(s, 2);      // Max Hardware Sharpness boost (+2) for razor sharp video detail
    s->set_denoise(s, 1);        // Noise reduction filter enabled
    s->set_whitebal(s, 1);       // Enable auto white balance
    s->set_awb_gain(s, 1);       // Enable white balance gain
    s->set_gain_ctrl(s, 1);      // Enable auto gain control
    s->set_exposure_ctrl(s, 1);  // Enable auto exposure control
    s->set_hmirror(s, 0);        // Mirroring off
    s->set_vflip(s, 0);          // Vertical flip off
    
    // Low noise & max performance optimizations
    s->set_gainceiling(s, GAINCEILING_2X); // Low noise gain ceiling
    s->set_aec2(s, 0);           // Disable AEC2 to prevent shutter FPS drops
    s->set_bpc(s, 1);            // Black pixel correction
    s->set_wpc(s, 1);            // White pixel correction
    s->set_raw_gma(s, 1);        // Raw gamma correction
    s->set_lenc(s, 1);           // Lens correction
  }

  // Configure ESP32-CAM as Wi-Fi Access Point on Channel 6, single-client lock
  WiFi.softAP(ssid, password, 6, 0, 1);
  
  // Wi-Fi Connectivity & Latency Optimizations
  WiFi.setSleep(false);                 // Disable Wi-Fi radio sleep for instant low latency
  WiFi.setTxPower(WIFI_POWER_19_5dBm);  // Maximum RF power output
  
  IPAddress IP = WiFi.softAPIP();
  
  Serial.print("Access Point started! SSID: ");
  Serial.println(ssid);
  Serial.print("Camera Stream URL: http://");
  Serial.print(IP);
  Serial.println(":81/stream");

  startCameraServer();
}

void loop() {
  delay(1000);
}
