-- Copyright (C) by Hiroaki Nakamura (hnakamur)

local zlib = require "ffi-zlib"
local setmetatable = setmetatable

local _M = {}

local mt = { __index = _M }

function _M.new(self, config)
    return setmetatable({
        idp_dest_url = config.idp_dest_url,
        sp_entity_id = config.sp_entity_id,
        sp_saml_finish_url = config.sp_saml_finish_url,
        request_id_generator = config.request_id_generator
    }, mt)
end

function _M.redirect_to_idp_to_login(self)
    local request_id, err = self:issue_request_id()
    if err ~= nil then
        return nil, err
    end

    local req, err = self:create_compress_base64encode_request(request_id)
    if err ~= nil then
        return nil, err
    end
    local url_before_login = ngx.var.uri .. ngx.var.is_args .. (ngx.var.args ~= nil and ngx.var.args or "")
    local url = self.idp_dest_url .. "?" .. ngx.encode_args({SAMLRequest = req, RelayState = url_before_login})
    return ngx.redirect(url)
end

function _M.issue_request_id(self)
    local request_id_generator = self.request_id_generator
    return request_id_generator()
end

function _M.create_compress_base64encode_request(self, request_id)
    local request_xml = self:create_request_xml(request_id)
    local compressed, err = self:compress(request_xml)
    if err ~= nil then
        return nil, err
    end

    return ngx.encode_base64(compressed)
end

function _M.create_request_xml(self, request_id)
    local now = ngx.utctime()
    local issue_instant = string.sub(now, 1, #"yyyy-mm-dd") .. "T" .. string.sub(now, -#"hh:mm:ss") .. "Z"

    return string.format(
        [[<samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" AssertionConsumerServiceURL="%s" Destination="%s" ID="%s" IssueInstant="%s" ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Version="2.0">
<saml:Issuer xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">%s</saml:Issuer>
<samlp:NameIDPolicy AllowCreate="1"/>
</samlp:AuthnRequest>]],
        self.sp_saml_finish_url,
        self.idp_dest_url,
        request_id,
        issue_instant,
        self.sp_entity_id
    )
end

function _M.compress(self, request_xml)
    local i = 1
    local input = function(bufsize)
        if i > #request_xml then
            return nil
        end
        local ret = string.sub(request_xml, i, i + bufsize - 1)
        i = i + bufsize
        return ret
    end

    local output_table = {}
    local output = function(data)
        table.insert(output_table, data)
    end

    local options = {windowBits = 15}
    local ok, err = zlib.deflateGzip(input, output, nil, options)
    if not ok then
        return nil, string.format("failed to compress SAML request, err=%s", err)
    end

    local compressed = string.sub(table.concat(output_table, ''), 2 + 1, -(4 + 1))
    return compressed, nil
end

return _M
