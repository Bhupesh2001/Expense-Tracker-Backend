-- Import required modules
local http = require "resty.http"
local cjson = require "cjson"

-- Define the handler
local CustomAuthHandler = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
}

function CustomAuthHandler:access(config)
  local auth_service_url = config.auth_service_url
  
  kong.log.debug("=== Custom Auth Plugin Called ===")
  kong.log.debug("Auth service URL: ", auth_service_url)
  
  local auth_header = kong.request.get_header("Authorization")
  kong.log.debug("Authorization header: ", auth_header)
  
  if not auth_header then
    kong.log.err("No Authorization header present")
    return kong.response.exit(401, { message = "Unauthorized - No token provided" })
  end
  
  -- Call auth service
  local httpc = http.new()
  httpc:set_timeout(5000)
  
  kong.log.debug("Calling auth service...")
  local res, err = httpc:request_uri(auth_service_url, {
    method = "GET",
    headers = {
      ["Authorization"] = auth_header
    }
  })
  
  if not res then
    kong.log.err("Failed to call auth service: ", err)
    return kong.response.exit(500, { message = "Internal Server Error" })
  end
  
  kong.log.debug("Auth service response status: ", res.status)
  kong.log.debug("Auth service response body: ", res.body)
  kong.log.debug("Auth service response headers: ", cjson.encode(res.headers))
  
  if res.status ~= 200 then
    kong.log.err("Auth service returned non-200 status: ", res.status)
    return kong.response.exit(401, { message = "Unauthorized" })
  end
  
  -- Extract user_id from response body
  local user_id = res.body
  kong.log.debug("Setting X-User-ID header to: ", user_id)
  
  kong.service.request.set_header("X-User-ID", user_id)
  kong.log.debug("=== Auth successful, proceeding to upstream ===")
end

-- Return the handler
return CustomAuthHandler