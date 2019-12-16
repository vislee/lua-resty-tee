Name
====

lua-resty-tee - The traffic original output.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [save_req_body](#save_req_body)
    * [save_resp_body](#save_resp_body)
    * [request](#request)
    * [response](#response)
* [Author](#author)
* [Copyright and License](#copyright-and-license)


Status
======

This library is still under early development and is still experimental.


Description
===========

[Back to TOC](#table-of-contents)

Synopsis
========

```nginx

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

            local tee = require "resty.tee" .new()

            ngx.log(ngx.INFO, tee:request(), '\n', tee:response())
        }
    }
```

[Back to TOC](#table-of-contents)

Methods
=======

[Back to TOC](#table-of-contents)

new
---
`syntax: t = new()`

Creates a tee object.

[Back to TOC](#table-of-contents)

save_req_body
-------------

[Back to TOC](#table-of-contents)


save_resp_body
-------------

[Back to TOC](#table-of-contents)


request
-------

[Back to TOC](#table-of-contents)


response
--------

[Back to TOC](#table-of-contents)


Author
======

wenqiang li(vislee)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2019, by vislee.

[Back to TOC](#table-of-contents)
