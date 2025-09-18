
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

$ENV{TEST_NGINX_CWD} = cwd();

no_long_string();

our $HttpConfig = <<'_EOC_';
    lua_package_path '$TEST_NGINX_CWD/lib/?.lua;$TEST_NGINX_CWD/t/?.lua;;';
_EOC_

run_tests();

__DATA__

=== TEST 1: AES evp cipher
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local resty_crypto = require "resty.crypto"
            local resty_aes = require "resty.aes"
            local cipher = resty_aes.cipher()
            local aes, err = resty_crypto.new("secret", nil, cipher)
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local enc_data, err = aes:encrypt("abc")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.say(aes:decrypt(enc_data))
        }
    }
--- request
GET /t
--- response_body
abc
--- error_code: 200
--- no_error_log
[error]

