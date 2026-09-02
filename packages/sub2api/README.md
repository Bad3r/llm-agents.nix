# sub2api

`sub2api` is a self-hosted AI API gateway for distributing and managing
subscription quotas across services such as Claude, OpenAI, and Gemini.

This package provides the server binary and its embedded web frontend. It does
not provision a database, cache, or service manager. A working deployment also
requires PostgreSQL and Redis; see the [upstream deployment
documentation](https://github.com/Wei-Shaw/sub2api/blob/main/deploy/README.md)
for configuration and deployment examples.

The upstream project warns that some uses may conflict with upstream provider
terms of service. Use it only in compliance with the applicable terms and
local laws.
