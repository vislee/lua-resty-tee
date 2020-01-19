use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

log_level('debug');

repeat_each(1);
plan tests => repeat_each() * (2 * blocks() + 1);

no_long_string();

run_tests();

__DATA__

=== TEST 1: GET request and no resp body

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }


    log_format main '$time_local  '
    '$hostname#?#  :'
    '$tee_req#?#  :'
    '$tee_resp';


    server {
        listen 127.0.0.1:8082;

        location /{
            return 204;
        }
    }

--- config
    location /t/ {

        set $tee_req '';
        set $tee_resp '';

        access_log /tmp/access.log main;

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        proxy_pass http://127.0.0.1:8082/;

        body_filter_by_lua_block {
            local tee = require "resty.tee" .new()
            tee:save_resp_body(ngx.arg[1])
        }

        log_by_lua_block {

            local reqstr = "GET /t/webids?hello=vis HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"

            local respstr = "HTTP/1.1 204 No Content\r\nconnection: close\r\ncontent-type: text/plain\r\n\r\n"

            local tee = require "resty.tee" .new()

            if tee:request() ~= reqstr then
                ngx.log(ngx.ERR, "=====req error======", tee:request())
            end

            ngx.var.tee_req = tee:request()

            if tee:response() ~= respstr then
                ngx.log(ngx.ERR, "====resp error ====", tee:response())
            end

            ngx.var.tee_resp = tee:response()
        }
    }

--- timeout: 10
--- request
GET /t/webids?hello=vis
--- response_headers_like
--- error_code: 204
--- no_error_log
[error]



=== TEST 2: test POST request and having resp body

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }


    log_format main '$time_local  '
    '$hostname#?#  :'
    '$tee_req#?#  :'
    '$tee_resp';


    server {
        listen 127.0.0.1:8082;

        location /{

            content_by_lua_block {
                ngx.print("okokxxx")
                ngx.exit(ngx.HTTP_OK)
            }
        }
    }

--- config
    location /t/ {

        set $tee_req '';
        set $tee_resp '';

        access_log /tmp/access.log main;

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        proxy_pass http://127.0.0.1:8082/;

        body_filter_by_lua_block {
            local tee = require "resty.tee" .new()
            tee:save_resp_body(ngx.arg[1])
        }

        log_by_lua_block {

            local reqstr = "POST /t/webids?hello=vis HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: 12\r\n\r\nhello"

            local respstr = "HTTP/1.1 200 OK\r\nconnection: close\r\ncontent-length: 7\r\ncontent-type: text/plain\r\n\r\nokok"

            local tee = require "resty.tee" .new()

            if tee:request() ~= reqstr then
                ngx.log(ngx.ERR, "=====req error======", tee:request())
            end

            ngx.var.tee_req = tee:request()

            if tee:response() ~= respstr then
                ngx.log(ngx.ERR, "====resp error ====", tee:response())
            end

            ngx.var.tee_resp = tee:response()
        }
    }

--- timeout: 10
--- request
POST /t/webids?hello=vis
helloxxxxxxx
--- response_headers_like
--- response_body_like: okok
--- error_code: 200
--- no_error_log
[error]



=== TEST 3: multi header

--- http_config
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }


    log_format main '$time_local  '
    '$hostname#?#  :'
    '$tee_req#?#  :'
    '$tee_resp';


    server {
        listen 127.0.0.1:8082;

        location /{
            add_header 'Set-Cookie' 'a=b; httponly';
            add_header 'Set-Cookie' 'b=b; httponly';
            return 204;
        }
    }

--- config
    location /t/ {

        set $tee_req '';
        set $tee_resp '';

        access_log /tmp/access.log main;

        access_by_lua_block {
            local tee = require "resty.tee" .new(5, 4)
            ngx.req.read_body()
            tee:save_req_body(ngx.req.get_body_data())
        }

        proxy_pass http://127.0.0.1:8082/;

        body_filter_by_lua_block {
            local tee = require "resty.tee" .new()
            tee:save_resp_body(ngx.arg[1])
        }

        log_by_lua_block {

            local reqstr = "GET /t/webids?hello=vis HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nX-Forwarded-For: 1.1.1.1,2.2.2.2\r\nX-Forwarded-For: 3.3.3.3,4.4.4.4\r\n\r\n"

            local respstr = "HTTP/1.1 204 No Content\r\nconnection: close\r\ncontent-type: text/plain\r\nSet-Cookie: a=b; httponly, b=b; httponly\r\n\r\n"

            local tee = require "resty.tee" .new()

            if tee:request() ~= reqstr then
                ngx.log(ngx.ERR, "=====req error======", tee:request())
            end

            ngx.var.tee_req = tee:request()

            if tee:response() ~= respstr then
                ngx.log(ngx.ERR, "====resp error ====", tee:response())
            end

            ngx.var.tee_resp = tee:response()
        }
    }

--- timeout: 10
--- request
GET /t/webids?hello=vis
--- more_headers
X-Forwarded-For: 1.1.1.1,2.2.2.2
X-Forwarded-For: 3.3.3.3,4.4.4.4
--- response_headers_like
--- error_code: 204
--- no_error_log
[error]
