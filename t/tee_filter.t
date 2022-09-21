use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

log_level('debug');

repeat_each(1);
plan tests => repeat_each() * (2 * blocks() + 3);

no_long_string();

run_tests();

__DATA__

=== TEST 1: GET filter request args
--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t/ {

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        content_by_lua_block {
            ngx.say("OK")
            ngx.exit(ngx.OK)
        }

        log_by_lua_block {
            local filter = {
                args = {foo = "KV", book = "V", hello="KV"},
                headers = {x_hello_world = "KV", test="V"},
                cookie = {user = "V", password="KV"},
                form = {passwd = "V", asdfghjklzxcvbnmqwertyuiop="KV"}
            }
            local reqstr = "GET /t/web?book=r***s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
            local reqstr2 = "GET /t/web?book=r***s HTTP/1.1\r\nConnection: close\r\nHost: localhost\r\n\r\n"

            local req = require "resty.tee" .new():request(filter)
            if req ~= reqstr and req ~= reqstr2 then
                ngx.log(ngx.ERR, "=====req error======", req)
            end
        }
    }

--- timeout: 10
--- request
GET /t/web?book=redis
--- response_headers_like
--- error_code: 200
--- no_error_log
[error]


=== TEST 2: GET filter request headers

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t/ {

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        content_by_lua_block {
            local filter = {
                args = {foo = "KV", book = "V", hello="KV"},
                headers = {x_hello_world = "KV", test="V"},
                cookie = {user = "V", password="KV"},
                form = {passwd = "V", asdfghjklzxcvbnmqwertyuiop="KV"}
            }
            local req = require "resty.tee" .new():request(filter)
            ngx.say(req)
            ngx.exit(ngx.OK)
        }
    }

--- timeout: 10
--- request
GET /t/web?book=redis
--- more_headers
X-Hello-World: zxcvbnmasdfghjklqwertyuiop1234567890qwertyuiopasdfghjklzxcvbnm
--- response_body_like: X-\*\*llo-World: zxcv\*
--- error_code: 200
--- no_error_log
[error]



=== TEST 3: GET filter request cookie

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t/ {

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        content_by_lua_block {
            local filter = {
                args = {foo = "KV", book = "V", hello="KV"},
                headers = {x_hello_world = "KV", test="V"},
                cookie = {_user_id = "V", password="KV"},
                form = {passwd = "V", asdfghjklzxcvbnmqwertyuiop="KV"}
            }
            local req = require "resty.tee" .new():request(filter)
            ngx.say(req)
            ngx.exit(ngx.OK)
        }
    }

--- timeout: 10
--- request
GET /t/web?book=redis
--- more_headers
cookie: _user_id=qwertyuio1234567890qwertyuiopLKJHGFDSA; password=1qaz@WSX3edc
--- response_body_like: pa\*\*word=1qaz\*\*\*\*3edc
--- error_code: 200
--- no_error_log
[error]



=== TEST 4: POST filter request form

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t/ {

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        content_by_lua_block {
            local filter = {
                args = {foo = "KV", book = "V", hello="KV"},
                headers = {x_hello_world = "KV", test="V"},
                cookie = {_user_id = "V", password="KV"},
                form = {passwd = "KV", test_token_qwertyuiopasdfghjklzxcvbnm="V"}
            }
            local req = require "resty.tee" .new():request(filter)
            ngx.say(req)
            ngx.exit(ngx.OK)
        }
    }

--- timeout: 10
--- request
POST /t/web?book=redis&hello=world&foo=bar
test_token_qwertyuiopasdfghjklzxcvbnm=zxcvbnmasdfghjklqwertyuiop1234567890qwertyuiopasdfghjklzxcvbnm&user=vislee&passwd=1qaz@WSX3edc
--- more_headers
Content-Type: application/x-www-form-urlencoded
cookie: _user_id=qwertyuio1234567890qwertyuiopLKJHGFDSA; password=1qaz@WSX3edc
--- response_body_like: test_token_qwertyuiopasdfghjklzxcvbnm=zxcv\*
--- error_code: 200
--- no_error_log
[error]

