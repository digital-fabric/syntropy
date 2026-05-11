# frozen_string_literal: true

module Syntropy
  module HTTP
    # translated from https://golang.org/pkg/net/http/#pkg-constants
    # https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

    CONTINUE                        = 100 # RFC 7231, 6.2.1
    SWITCHING_PROTOCOLS             = 101 # RFC 7231, 6.2.2
    PROCESSING                      = 102 # RFC 2518, 10.1
    EARLY_HINTS                     = 103 # RFC 8297

    OK                              = 200 # RFC 7231, 6.3.1
    CREATED                         = 201 # RFC 7231, 6.3.2
    ACCEPTED                        = 202 # RFC 7231, 6.3.3
    NON_AUTHORITATIVE_INFO          = 203 # RFC 7231, 6.3.4
    NO_CONTENT                      = 204 # RFC 7231, 6.3.5
    RESET_CONTENT                   = 205 # RFC 7231, 6.3.6
    PARTIAL_CONTENT                 = 206 # RFC 7233, 4.1
    MULTI_STATUS                    = 207 # RFC 4918, 11.1
    ALREADY_REPORTED                = 208 # RFC 5842, 7.1
    IM_USED                         = 226 # RFC 3229, 10.4.1

    MULTIPLE_CHOICES                = 300 # RFC 7231, 6.4.1
    MOVED_PERMANENTLY               = 301 # RFC 7231, 6.4.2
    FOUND                           = 302 # RFC 7231, 6.4.3
    SEE_OTHER                       = 303 # RFC 7231, 6.4.4
    NOT_MODIFIED                    = 304 # RFC 7232, 4.1
    USE_PROXY                       = 305 # RFC 7231, 6.4.5

    TEMPORARY_REDIRECT              = 307 # RFC 7231, 6.4.7
    PERMANENT_REDIRECT              = 308 # RFC 7538, 3

    BAD_REQUEST                     = 400 # RFC 7231, 6.5.1
    UNAUTHORIZED                    = 401 # RFC 7235, 3.1
    PAYMENT_REQUIRED                = 402 # RFC 7231, 6.5.2
    FORBIDDEN                       = 403 # RFC 7231, 6.5.3
    NOT_FOUND                       = 404 # RFC 7231, 6.5.4
    METHOD_NOT_ALLOWED              = 405 # RFC 7231, 6.5.5
    NOT_ACCEPTABLE                  = 406 # RFC 7231, 6.5.6
    PROXY_AUTH_REQUIRED             = 407 # RFC 7235, 3.2
    REQUEST_TIMEOUT                 = 408 # RFC 7231, 6.5.7
    CONFLICT                        = 409 # RFC 7231, 6.5.8
    GONE                            = 410 # RFC 7231, 6.5.9
    LENGTH_REQUIRED                 = 411 # RFC 7231, 6.5.10
    PRECONDITION_FAILED             = 412 # RFC 7232, 4.2
    REQUEST_ENTITY_TOO_LARGE        = 413 # RFC 7231, 6.5.11
    REQUEST_URI_TOO_LONG            = 414 # RFC 7231, 6.5.12
    UNSUPPORTED_MEDIA_TYPE          = 415 # RFC 7231, 6.5.13
    REQUESTED_RANGE_NOT_SATISFIABLE = 416 # RFC 7233, 4.4
    EXPECTATION_FAILED              = 417 # RFC 7231, 6.5.14
    TEAPOT                          = 418 # RFC 7168, 2.3.3
    MISDIRECTED_REQUEST             = 421 # RFC 7540, 9.1.2
    UNPROCESSABLE_ENTITY            = 422 # RFC 4918, 11.2
    LOCKED                          = 423 # RFC 4918, 11.3
    FAILED_DEPENDENCY               = 424 # RFC 4918, 11.4
    TOO_EARLY                       = 425 # RFC 8470, 5.2.
    UPGRADE_REQUIRED                = 426 # RFC 7231, 6.5.15
    PRECONDITION_REQUIRED           = 428 # RFC 6585, 3
    TOO_MANY_REQUESTS               = 429 # RFC 6585, 4
    REQUEST_HEADER_FIELDS_TOO_LARGE = 431 # RFC 6585, 5
    UNAVAILABLE_FOR_LEGAL_REASONS   = 451 # RFC 7725, 3

    INTERNAL_SERVER_ERROR           = 500 # RFC 7231, 6.6.1
    NOT_IMPLEMENTED                 = 501 # RFC 7231, 6.6.2
    BAD_GATEWAY                     = 502 # RFC 7231, 6.6.3
    SERVICE_UNAVAILABLE             = 503 # RFC 7231, 6.6.4
    GATEWAY_TIMEOUT                 = 504 # RFC 7231, 6.6.5
    HTTP_VERSION_NOT_SUPPORTED      = 505 # RFC 7231, 6.6.6
    VARIANT_ALSO_NEGOTIATES         = 506 # RFC 2295, 8.1
    INSUFFICIENT_STORAGE            = 507 # RFC 4918, 11.5
    LOOP_DETECTED                   = 508 # RFC 5842, 7.2
    NOT_EXTENDED                    = 510 # RFC 2774, 7
    NETWORK_AUTHENTICATION_REQUIRED = 511 # RFC 6585, 6
  end
end
