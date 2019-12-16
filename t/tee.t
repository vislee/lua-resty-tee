use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

log_level('debug');

repeat_each(1);
plan tests => repeat_each() * (3 * blocks());

no_long_string();

run_tests();

__DATA__

=== TEST 1: test

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }


    server {
        listen 127.0.0.1:8082;

        location /{

            content_by_lua_block {
                ngx.print("okok")
                ngx.exit(ngx.HTTP_OK)
            }
        }
    }

--- config
    location /t/ {

        access_by_lua_block {
            local tee = require "resty.tee" .new()
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        proxy_pass http://127.0.0.1:8082/;

        body_filter_by_lua_block {
            local tee = require "resty.tee" .new()
            tee:save_resp_body(ngx.arg[1])
        }

        log_by_lua_block {

            local reqstr = "POST /t/webids?hello=vis HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: 5\r\n\r\nhello"
    
            local respstr = "HTTP/1.1 200 OK\r\nconnection: close\r\ncontent-length: 4\r\ncontent-type: text/plain\r\n\r\nokok"


            local tee = require "resty.tee" .new()

            if tee:request() ~= reqstr then
                ngx.log(ngx.ERR, "=====req error======", tee:request())
            end

            if tee:response() ~= respstr then
                ngx.log(ngx.ERR, "====resp error ====", tee:response())
            end
        }
    }

--- timeout: 10
--- request
POST /t/webids?hello=vis
hello
--- response_headers_like
--- response_body_like: okok
--- error_code: 200
--- no_error_log
[error]
