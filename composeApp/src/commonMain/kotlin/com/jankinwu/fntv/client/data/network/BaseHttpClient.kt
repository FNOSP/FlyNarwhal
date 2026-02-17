package com.jankinwu.fntv.client.data.network

import io.ktor.client.HttpClient

expect val fnOfficialClient: HttpClient
expect val fnOfficialInsecureClient: HttpClient
expect val apiModule: org.koin.core.module.Module
