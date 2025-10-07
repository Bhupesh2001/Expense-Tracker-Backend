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
      ["Authorization"] = auth_header,
      ["Content-Type"] = "application/json"
    }
  })

  if not res then
    kong.log.err("Failed to call auth service: ", err)
    return kong.response.exit(500, { message = "Internal Server Error" })
  end

  kong.log.debug("Auth service response status: ", res.status)
  kong.log.debug("Auth service response body: ", res.body)

  if res.status ~= 200 then
    kong.log.err("Auth service returned non-200 status: ", res.status)
    return kong.response.exit(401, { message = "Unauthorized" })
  end

  -- Parse the response body to extract user_id
  local user_id
  local success, parsed_body = pcall(cjson.decode, res.body)

  if success and type(parsed_body) == "table" then
    -- If response is JSON object
    user_id = parsed_body.userId or parsed_body.user_id or parsed_body.id or parsed_body.sub
  else
    -- If response is plain text/string
    user_id = res.body
  end

  if not user_id or user_id == "" then
    kong.log.err("Could not extract user_id from auth service response")
    return kong.response.exit(500, { message = "Internal Server Error - Invalid auth response" })
  end

  kong.log.debug("Setting X-User-ID header to: ", user_id)

  -- Set the header for upstream service
  kong.service.request.set_header("X-User-ID", user_id)

  -- Forward all original headers (important for HttpHeaders to work)
--   local headers = kong.request.get_headers()
--   for key, value in pairs(headers) do
--     if type(value) == "table" then
--       kong.service.request.set_header(key, value[1]) -- Take first value for multi-value headers
--     else
--       kong.service.request.set_header(key, value)
--     end
--   end

  kong.log.debug("=== Auth successful, proceeding to upstream ===")
end

-- Return the handler
return CustomAuthHandler