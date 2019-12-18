-- Copyright (C) 2019 vislee

local ngx_var               = ngx.var
local ngx_req_raw_header    = ngx.req.raw_header
local ngx_req_read_body     = ngx.req.read_body
local ngx_req_get_body      = ngx.req.get_body_data
local ngx_req_get_body_file = ngx.req.get_body_file
local ngx_resp_get_headers  = ngx.resp.get_headers


local tab_concat = table.concat
local str_sub    = string.sub

local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function(narr, nrec) return {} end
end
local ok, tab_clear = pcall(require, "table.clear")
if not ok then
    tab_clear = function(tab) for k, _ in pairs(tab) do tab[k] = nil end end
end


local http_status_line = {
    ["200"] = "200 OK\r\n",
    ["204"] = "204 No Content\r\n",
    ["301"] = "301 Moved Permanently\r\n",
    ["302"] = "302 Moved Temporarily\r\n",
    ["303"] = "303 See Other\r\n",
    ["304"] = "304 Not Modified\r\n",
    ["307"] = "307 Temporary Redirect\r\n",
    ["308"] = "308 Permanent Redirect\r\n",
    ["400"] = "400 Bad Request\r\n",
    ["403"] = "403 Forbidden\r\n",
    ["404"] = "404 Not Found\r\n",
    ["405"] = "405 Not Allowed\r\n",
    ["500"] = "500 Internal Server Error\r\n",
    ["502"] = "502 Bad Gateway\r\n",
    ["504"] = "504 Gateway Time-out\r\n"
}


local _get_status_line
_get_status_line = function(status)
    local line = http_status_line[tostring(status)]
    if not line then
        line = tostring(status) .. " undefined\r\n"
    end

    return line
end


local _M = tab_new(0, 2)
_M.version = "0.01"

local mt = { __index = _M }


function  _M.new(req_body_limit, resp_body_limit)
    if ngx.ctx._tee then
        return ngx.ctx._tee
    end

    local t = tab_new(0, 6)

    t._http_version = 'HTTP/' .. ngx.req.http_version()
    t._resp_body = tab_new(2, 0)
    t._req_body_limit = req_body_limit or 4096
    t._resp_body_limit = resp_body_limit or 4096
    t._resp_body_size = 0

    ngx.ctx._tee = setmetatable(t, mt)

    return ngx.ctx._tee
end


function _M.save_req_body(self, body)
    if not body then
        local file = ngx_req_get_body_file()
        if file then
            local f, err = io.open(file)
            if not err then
                body = f:read("*all")
                f:close()
            end
        end
    end

    if body then
        self._req_body = str_sub(body, 1, self._req_body_limit) .. ''
    end
end


function _M.save_resp_body(self, body)
    if not body then
        return
    end

    local has = self._resp_body_limit - self._resp_body_size
    if has <= 0 then
        return
    end

    local have = #body
    if has > have then
        has = have
    end

    self._resp_body[#self._resp_body + 1] = str_sub(body, 1, has)
    self._resp_body_size = self._resp_body_size + has
end


function _M.request(self)
    local req = tab_new(2, 0)

    req[1] = ngx_req_raw_header()
    req[2] = self._req_body

    return tab_concat(req, '')
end


function _M.response(self)
    local resp = tab_new(3, 0)
    resp[1] = self._http_version .. ' ' .. _get_status_line(ngx.status)

    local head = tab_new(50, 0)
    local h = ngx_resp_get_headers(50, true)
    for k, v in pairs(h) do
        head[#head+1] = k .. ': ' .. v
    end
    head[#head+1] = '\r\n'
    resp[2] = tab_concat(head, '\r\n')
    tab_clear(head)

    resp[3] = tab_concat(self._resp_body, '')

    return tab_concat(resp, '')
end

return _M
