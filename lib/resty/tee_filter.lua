-- Copyright (C) 2022 vislee

local ngx_gsub              = ngx.re.gsub
local ngx_req_get_method    = ngx.req.get_method
local ngx_req_get_uri_args  = ngx.req.get_uri_args
local ngx_req_get_post_args = ngx.req.get_post_args
local ngx_req_get_headers   = ngx.req.get_headers

local tab_concat = table.concat
local str_lower  = string.lower
local str_gsub   = string.gsub
local str_rep    = string.rep

local type          = type
local byte          = string.byte
local sub           = string.sub

local EQUAL         = byte("=")
local SEMICOLON     = byte(";")
local SPACE         = byte(" ")
local HTAB          = byte("\t")

local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function(narr, nrec) return {} end
end
local new_tab = tab_new

local ok, tab_clear = pcall(require, "table.clear")
if not ok then
    tab_clear = function(tab) for k, _ in pairs(tab) do tab[k] = nil end end
end


local _M = {}

local filter_key = function(k)
    if k == nil or type(k) ~= "string" then
        return k
    end

    local reg, rep
    local size = #k

    if size < 4 then  -- 1,2,3
        reg = "(.).{0,2}(.)"
        rep = tab_concat({"$1", str_rep('*', size - 2), "$2"}, "")
    else  -- 4,5,6,...,512
        reg = "(.{2}).{2}(.{0,508})"
        rep = "$1**$2"
    end

    local nk, n, err = ngx_gsub(k, reg, rep, "jo")
    if err ~= nil or n < 1 then
        return k
    end
    return nk
end
_M.filter_key = filter_key


local filter_val = function(v)
    if v == nil then
        return v
    end

    if type(v) == "table" then
        v = tab_concat(v, ", ")
    end

    local reg, rep
    local size = #v

    if size < 3 then -- 1,2
        return str_rep('*', size)
    elseif size < 6 then -- 3,4,5
        reg = "(.).{1,3}(.)"
        rep = tab_concat({"$1", str_rep('*', size - 2), "$2"}, "")
    elseif size < 9 then -- 6,7,8
        reg = "(.{2}).{1,4}(.{2})"
        rep = tab_concat({"$1", str_rep('*', size - 4), "$2"}, "")
    elseif size < 64 then-- 9,10,11 ...,63
        reg = "(.{4}).{1,64}(.{4})"
        rep = tab_concat({"$1", str_rep('*', size - 8), "$2"}, "")
    else -- 64,65 ... 1024
        reg = "(.{16}).{1,1004}(.{4})"
        rep = tab_concat({"$1", str_rep('*', size - 20), "$2"}, "")
    end

    local nv, n, err = ngx_gsub(v, reg, rep, "jo")
    if err ~= nil or n < 1 then
        return v
    end

    return nv
end
_M.filter_val = filter_val


-- Copyright (C) 2013-2016 Jiale Zhi (calio), CloudFlare Inc.
local function get_cookie_table(text_cookie)
    if type(text_cookie) ~= "string" then
        -- log(ERR, format("expect text_cookie to be \"string\" but found %s",
        --         type(text_cookie)))
        return {}
    end

    local EXPECT_KEY    = 1
    local EXPECT_VALUE  = 2
    local EXPECT_SP     = 3

    local n = 0
    local len = #text_cookie

    for i=1, len do
        if byte(text_cookie, i) == SEMICOLON then
            n = n + 1
        end
    end

    local cookie_table  = new_tab(0, n + 1)

    local state = EXPECT_SP
    local i = 1
    local j = 1
    local key, value

    while j <= len do
        if state == EXPECT_KEY then
            if byte(text_cookie, j) == EQUAL then
                key = sub(text_cookie, i, j - 1)
                state = EXPECT_VALUE
                i = j + 1
            end
        elseif state == EXPECT_VALUE then
            if byte(text_cookie, j) == SEMICOLON
                    or byte(text_cookie, j) == SPACE
                    or byte(text_cookie, j) == HTAB
            then
                value = sub(text_cookie, i, j - 1)
                cookie_table[key] = value

                key, value = nil, nil
                state = EXPECT_SP
                i = j + 1
            end
        elseif state == EXPECT_SP then
            if byte(text_cookie, j) ~= SPACE
                and byte(text_cookie, j) ~= HTAB
            then
                state = EXPECT_KEY
                i = j
                j = j - 1
            end
        end
        j = j + 1
    end

    if key ~= nil and value == nil then
        cookie_table[key] = sub(text_cookie, i)
    end

    return cookie_table
end


local get_filter_cookie = function(text_cookie, filter_cookie)
    if text_cookie == nil or type(text_cookie) ~= "string" then
        return text_cookie
    end

    if filter_cookie == nil or type(filter_cookie) ~= "table" or not next(filter_cookie) then
        return text_cookie
    end

    local c = get_cookie_table(text_cookie)
    local t = {}
    for k, v in pairs(c) do
        local fv = filter_cookie[k]
        if fv == nil then
            t[#t+1] = tab_concat({k, v}, "=")
        elseif fv == "V" then
            t[#t+1] = tab_concat({k, filter_val(v)}, "=")
        else
            t[#t+1] = tab_concat({filter_key(k), filter_val(v)}, "=")
        end
    end

    return tab_concat(t, "; ")
end


local get_filter_request = function(self, filter)
    local req = tab_new(2, 0)

    local get_request_uri = function(args)
        if args == nil or type(args) ~= "table" or not next(args) then
            return ngx.var.request_uri
        end

        local ra = ngx_req_get_uri_args(0)
        if not next(ra) then
            return ngx.var.request_uri
        end

        local t = tab_new(#ra, 0)
        for k, v in pairs(ra) do
            local fv = args[k]
            if fv == nil then
                t[#t+1] = tab_concat({k, v}, "=")
            elseif fv == "V" then
                t[#t+1] = tab_concat({k, filter_val(v)}, "=")
            else
                t[#t+1] = tab_concat({filter_key(k), filter_val(v)}, "=")
            end
        end

        local s = ngx.var.request_uri
        if next(t) then
            s = tab_concat({ngx.var.uri, tab_concat(t, "&")}, "?")
        end
        tab_clear(t)

        return s
    end


    local get_post_args = function(form)
        if form == nil or type(form) ~= "table" or not next(form) then
            return self._req_body
        end
        local pa = ngx_req_get_post_args(0)
        if not next(pa) then
            return self._req_body
        end

        local t = tab_new(#pa, 0)
        for k, v in pairs(pa) do
            local fv = form[k]
            if fv == nil then
                t[#t+1] = tab_concat({k, v}, "=")
            elseif fv == "V" then
                t[#t+1] = tab_concat({k, filter_val(v)}, "=")
            else
                t[#t+1] = tab_concat({filter_key(k), filter_val(v)}, "=")
            end
        end

        local s = tab_concat(t, "&")
        tab_clear(t)
        return s
    end

    local head = tab_new(51, 0)
    head[1] = tab_concat({(ngx_req_get_method() or "UNK"), get_request_uri(filter.args), self._http_version}, " ")

    local h = ngx_req_get_headers(0, true)
    for k, v in pairs(h) do
        if k == "cookie" then
            v = get_filter_cookie(v, filter.cookie)
        end
        local fv = filter.headers and filter.headers[str_gsub(str_lower(k), '-', '_')]
        if fv == nil then
            head[#head+1] = tab_concat({k, v}, ": ")
        elseif fv == "V" then
            head[#head+1] = tab_concat({k, filter_val(v)}, ": ")
        else
            head[#head+1] = tab_concat({filter_key(k), filter_val(v)}, ": ")
        end
    end
    head[#head+1] = '\r\n'

    req[1] = tab_concat(head, '\r\n')
    tab_clear(head)

    req[2] = get_post_args(filter.form)

    return tab_concat(req, '')
end
_M.get_filter_request = get_filter_request


return _M
