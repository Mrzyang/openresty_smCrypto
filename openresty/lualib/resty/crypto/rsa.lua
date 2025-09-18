-- Copyright (C) by Jianhao Dai (Toruneko)

local BN = require "resty.crypto.bn"
local ERR = require "resty.crypto.error"

local ffi = require "ffi"
local ffi_gc = ffi.gc
local ffi_null = ffi.null
local C = ffi.C

local _M = { _VERSION = '1.0.0' }

ffi.cdef [[
typedef struct rsa_st RSA;
RSA *RSA_new(void);
void RSA_free(RSA *rsa);
int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, BN_GENCB *cb);
]]

local function RSA_free(rsa)
    ffi_gc(rsa, C.RSA_free)
end

local function RSA_new()
    local rsa = C.RSA_new()
    if rsa == ffi_null then
        return nil, ERR.get_error()
    end
    RSA_free(rsa)
    return rsa
end

function _M.new()
    return RSA_new()
end

function _M.free(rsa)
    RSA_free(rsa)
end

function _M.generate_key(rsa, bits)
    local bn, err = BN.new()
    if not bn then
        return false, err
    end
    -- Set public exponent to 65537
    local ok, err = BN.set_word(bn, 65537)
    if not ok then
        return false, err
    end

    -- Generate key
    if C.RSA_generate_key_ex(rsa, bits, bn, nil) ~= 1 then
        return false, ERR.get_error()
    end

    return true
end

return _M