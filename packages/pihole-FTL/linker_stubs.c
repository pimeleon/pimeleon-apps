#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

// Webserver / API / TLS / Auth Stubs
void webserver_init(void) {}
void webserver_cleanup(void) {}
void* webserver_thread(void* arg) { return NULL; }
void http_terminate(void) {}
void json_formatter(void* arg) {}
void send_http(void* arg) {}
void send_json_error(void* arg) {}
void send_http_internal_error(void) {}
void send_http_code(int code) {}
void pi_hole_extra_headers(void) {}
void send_json_unauthorized(void) {}
void read_and_parse_payload(void) {}
void get_http_method_str(int method) {}
void check_json_payload(void) {}
void verify_login(void) {}
void send_json_error_free(void* arg) {}
void mg_send_http_redirect(void* a, const char* b, int c) {}
void mg_send_http_ok(void* a, const char* b, long long c) {}
int mg_write(void* a, const void* b, size_t c) { return 0; }
void* mg_get_request_info(void* a) { return NULL; }
void mg_handle_form_request(void* a) {}
const char* mg_get_header(void* a, const char* b) { return NULL; }
int mg_get_var(void* a, const char* b, char* c, size_t d) { return -1; }
void mg_printf(void* a, const char* b, ...) {}
const char* mg_version(void) { return "stubbed"; }
int mg_check_feature(unsigned int feature) { return 0; }

// TLS/X509 Stubs
void TLS_init(void) {}
void TLS_thread_cleanup(void) {}
void read_certificate(void* a, void* b, void* c) {}
void generate_certificate(void) {}
void get_all_supported_ciphersuites(void) {}

// Security/Auth Stubs
void get_secure_randomness(void* buf, size_t len) {}
void generate_password(void* buf) {}
void verify_password(void* a, void* b) {}
void create_password(void* a) {}
void set_and_check_password(void* a) {}

// Version/Utility Stubs
void get_api_uri(void) {}
void get_prefix_webhome(void) {}
void get_api_string(void) {}
void sha256_raw_to_hex(const void* a, char* b, size_t c) {}
void run_performance_test(void) {}
void escape_html(void) {}
void escape_json(void) {}
void cJSON_unique_array(void) {}
void parse_groupIDs(void) {}
int get_int_var(void) { return 0; }
unsigned int get_uint_var(void) { return 0; }
uint64_t get_uint64_var_msg(void) { return 0; }
double get_double_var(void) { return 0.0; }
bool get_bool_var(void) { return false; }
const char* get_string_var(void) { return ""; }
int http_method(void* a) { return 0; }
bool startsWith(const char* a, const char* b) { return false; }
char* http_get_cookie_str(void* a, const char* b) { return NULL; }
int get_https_port(void) { return 443; }
