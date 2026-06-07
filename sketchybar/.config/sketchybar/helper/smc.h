#pragma once
// Minimal SMC client for AppleSMC, shared by temperature.h and power.h.
// Single connection per process; open at helper startup.

#include <IOKit/IOKitLib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#define KERNEL_INDEX_SMC 2

enum {
  kSMCReadKey         = 5,
  kSMCGetKeyFromIndex = 8,
  kSMCGetKeyInfo      = 9,
};

struct SMCVersion {
  uint8_t  major;
  uint8_t  minor;
  uint8_t  build;
  uint8_t  reserved[1];
  uint16_t release;
};

struct SMCPLimitData {
  uint16_t version;
  uint16_t length;
  uint32_t cpuPLimit;
  uint32_t gpuPLimit;
  uint32_t memPLimit;
};

struct SMCKeyInfoData {
  uint32_t dataSize;
  uint32_t dataType;
  uint8_t  dataAttributes;
};

struct SMCParamStruct {
  uint32_t              key;
  struct SMCVersion     vers;
  struct SMCPLimitData  pLimitData;
  struct SMCKeyInfoData keyInfo;
  uint8_t               result;
  uint8_t               status;
  uint8_t               data8;
  uint32_t              data32;
  uint8_t               bytes[32];
};

static io_connect_t g_smc_conn = 0;

static inline uint32_t smc_fourcc(const char *s) {
  return ((uint32_t)(uint8_t)s[0] << 24) |
         ((uint32_t)(uint8_t)s[1] << 16) |
         ((uint32_t)(uint8_t)s[2] << 8)  |
         ((uint32_t)(uint8_t)s[3]);
}

static inline bool smc_call(struct SMCParamStruct *in, struct SMCParamStruct *out) {
  if (!g_smc_conn) return false;
  size_t out_size = sizeof(struct SMCParamStruct);
  return IOConnectCallStructMethod(g_smc_conn, KERNEL_INDEX_SMC,
                                   in, sizeof(struct SMCParamStruct),
                                   out, &out_size) == KERN_SUCCESS;
}

static inline bool smc_init(void) {
  io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault,
                       IOServiceMatching("AppleSMC"));
  if (!svc) return false;
  kern_return_t kr = IOServiceOpen(svc, mach_task_self(), 0, &g_smc_conn);
  IOObjectRelease(svc);
  return kr == KERN_SUCCESS && g_smc_conn != 0;
}

// Reads an SMC key as float. Supports flt , sp78, ui16 data types.
static inline bool smc_read_float(const char *key_str, float *out) {
  struct SMCParamStruct in, info, val;
  memset(&in, 0, sizeof(in));
  memset(&info, 0, sizeof(info));
  memset(&val, 0, sizeof(val));

  in.key   = smc_fourcc(key_str);
  in.data8 = kSMCGetKeyInfo;
  if (!smc_call(&in, &info) || info.result != 0) return false;

  in.keyInfo.dataSize = info.keyInfo.dataSize;
  in.data8 = kSMCReadKey;
  if (!smc_call(&in, &val) || val.result != 0) return false;

  uint32_t type = info.keyInfo.dataType;
  uint32_t size = info.keyInfo.dataSize;

  if (type == smc_fourcc("flt ") && size == 4) {
    float f;
    memcpy(&f, val.bytes, 4);
    *out = f;
    return true;
  }
  if (type == smc_fourcc("sp78") && size == 2) {
    int16_t raw = (int16_t)(((uint16_t)val.bytes[0] << 8) | val.bytes[1]);
    *out = raw / 256.0f;
    return true;
  }
  if (type == smc_fourcc("ui16") && size == 2) {
    uint16_t v = ((uint16_t)val.bytes[0] << 8) | val.bytes[1];
    *out = (float)v;
    return true;
  }
  return false;
}

// Total number of SMC keys on this machine (read via the special "#KEY").
static inline uint32_t smc_key_count(void) {
  struct SMCParamStruct in, info, val;
  memset(&in, 0, sizeof(in));
  memset(&info, 0, sizeof(info));
  memset(&val, 0, sizeof(val));

  in.key   = smc_fourcc("#KEY");
  in.data8 = kSMCGetKeyInfo;
  if (!smc_call(&in, &info) || info.result != 0) return 0;
  in.keyInfo.dataSize = info.keyInfo.dataSize;
  in.data8 = kSMCReadKey;
  if (!smc_call(&in, &val) || val.result != 0) return 0;

  return ((uint32_t)val.bytes[0] << 24) |
         ((uint32_t)val.bytes[1] << 16) |
         ((uint32_t)val.bytes[2] << 8)  |
         ((uint32_t)val.bytes[3]);
}

// Writes the FourCC at `index` into `out` (5 bytes, NUL-terminated).
static inline bool smc_key_at_index(uint32_t index, char out[5]) {
  struct SMCParamStruct in, res;
  memset(&in, 0, sizeof(in));
  memset(&res, 0, sizeof(res));
  in.data8  = kSMCGetKeyFromIndex;
  in.data32 = index;
  if (!smc_call(&in, &res) || res.result != 0) return false;

  out[0] = (char)((res.key >> 24) & 0xff);
  out[1] = (char)((res.key >> 16) & 0xff);
  out[2] = (char)((res.key >> 8)  & 0xff);
  out[3] = (char)((res.key)       & 0xff);
  out[4] = 0;
  return true;
}
