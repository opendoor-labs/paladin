# Paladin

Provides service to service authentication by registering services and
providing mappings for communication that is allowed.

Paladin is configured to operate as part of an umbrella application. To start
with paladin, generate an umbrella application and add a git-submodule for
Paladin.

```sh
mix new paladin_umbrella --umbrella
cd paladin_umbrella
git init .
git submodule add https://github.com/opendoor-labs/paladin.git apps/paladin
mix deps.get
cd apps/paladin
npm install
cd ../..
mix ecto.migrate -r Paladin.Repo
mix phoenix.server
```

### Required Umbrella configuration

There are some things that are required for your umbrella application to
function.

#### Implement `Paladin.UserLogin` behaviour

You'll need to help Paladin find your user to allow access to the Paladin UI
itself.

This behaviour requires 3 callbacks to be defined.

* `@callback find_and_verify_user(Ueberauth.Auth.t) :: {:ok, user} | {:error, atom | String.t}`
  * Finds the user from an Ueberauth.Auth struct. It should find the user and
    authorize them for access to Paladin.
* `@callback user_display_name(user) :: String.t`
  * Fetch the display name for the user found in `find_and_verify_user`
* `@callback user_paladin_permissions(user) :: Map.t`
  * Provide a map of permissions (Guardian.Permissions) - including at _least_
    the Paladin permissions. If you intend all access return
    ```elixir
      %{
        paladin: Guardian.Permissions.max
      }
    ```

Once you've implemented your UserLogin behaviour, make sure to include it in
your config

```elixir
config :paladin, Paladin.UserLogin,
  module: MyUmbrellaApp.UserLogin
```

#### Implement Guardian.Serializer

This is just whatever you'd normally use for the Guardian Serializer based on
the user that you found in the `Paladin.UserLogin`

```elixir
config :guardian, Guardian,
  serializer: MyUmbrellaApp.GuardianSerializer
```

### Production

Your production configuration should have some additional information in it.

1. Your host for the paladin endpoint
2. The session signing salt.

```elixir
use Mix.Config

config :paladin, Paladin.Endpoint,
  url: [scheme: "https", host: "paladin.my-application.com", port: 433]

config :paladin, Plug.Session,
  signing_salt: System.get_env("PALADIN_SESSION_SALT")
```

All other required configuration is exported as environment variables that need
to be set. Here is a list of them:

* `PORT` - The endpoint port
* `SECRET_KEY_BASE` - The phoenix endpoint secret key
* `DATABASE_URL` - The db url for the Paladin.Repo
* `GUARDIAN_SECRET_KEY_BASE` - The Guardian secret for signing Paladins JWTs for
  accessing the UI.

All of these can of course be overwritten by overwriting the required config
fields. The can all be found in `paladin/config/prod.exs`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## General Concepts

Paladin stands as a keeper of secrets. All services registered with guardian
are provided with a secret. Keep it close. Keep it safe.

1. Open Paladin, and login with your Opendoor credentials (email/pass)
2. Register your service
3. Choose a service to talk to
4. Setup your app to use the tokens

## Usage

Primarily based on JWT you'll need to be able to generate these to gain access
tokens, and consume to use the provided access token.

### Acting as a client

When you want to speak to another service, and you've configured in paladin.
You'll need to fetch a token that is valid for that service.

#### 1. Generate the claims you want to use

First step is to generate a JWT and sign it with your secret (provided to you by
Paladin).

Required claims that you must set are:

* `aud` - The uuid of the service that you're intending on speaking to
* `sub` - The subject. For users this is: `"User:#{user.token}"`. When there is no
  user you should use `"anon"`
* `iss` - Your application id as the issuer
* `iat` - When you issued the token
* `exp` - The expiry of the assertion token. You should use short expiry times.

Any other options that you want to use are fair game, but Paladin will overwrite
the following:

* `jti` - The id of the JWT
* `iat` - Issued at - Paladin issued it and it will determine the time
* `ttl` - Expiry, currently not configurable - 10 minutes
* `nbf` - Not before. Not before Paladin issued it
* `iss` - The issuer. It was Paladin that issued it

To request an expiry for your token you can use the `rexp` key

* `rexp` - The requested expiry. This must be less than or equal to `paladins
  issue time + partnership.ttl_seconds`

If you do not set the `rexp` key, the expiry will be set to the ttl for the
service partnership.

To construct a token in Ruby

```ruby

  def assertion_jwt(user, app_id)
    claims = {
      aud: app_id,
      sub: "User:#{user.token}",
      iss: PALADIN_APP_ID,
      iat: Time.now.utc.to_i,
      exp: (Time.now + 2.minutes).utc.to_i,
    }

    JWT.encode(claims, PALADIN_SECRET, 'HS256')
  end
```


*NOTE* When generating the token you need to include the `aud`, `sub`, `iss`,
`iat`, and the `exp` to be set. iat and exp should be UTC unix timestamp.

#### 2. Request a token to use on the other service

Now that you have your JWT, you'll need to request one that will work on the
other service.

```ruby

  def access_token(user, app_to_talk_to_id)
    params = {
      "grant_type" => "urn:ietf:params:oauth:grant-type:sam12-bearer",
      "assertion" => assertion_jwt(user, app_to_talk_to_id),
      "client_id" => PALADIN_APP_ID
    }

    response = HTTParty.post(
      PALADIN_DOMAIN + "/authorize",
      body: params.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    json = JSON.parse(response.body)
    if json["token"]
      exp = response.headers("x-expiry").to_i
      puts json["token"]
      puts "The token expires at #{exp}"
      json["token"]
    else
      raise "OH NO! #{json["error"]} - #{json["error_description"]}"
    end
  end

```

#### 3. Use it to talk to the other service

Now you have the final access token to talk to the other side.
You should make a request.

```ruby

  # NOTE: This could have an error key... then it's an error
  token = access_token(user)["jwt"]

  profit = HTTParty.get(
    "https://the_service.com/blah/things",
    headers: {
      "Authorization" => "Bearer #{token}"
    }
  )
=>
```

### Acting as a service

Read from the Authorization header and strip out the part after `"Bearer "`

```ruby
token = read_auth_header_and_strip_bearer(env)
decoded_token = JWT.decode token, PALADIN_SECRET, true, { :algorithm => 'HS512' }
```

If you get to here... you have a winner. You can find out who the user is:

```ruby

case decoded_token["aud"]
when "anon"
  nil
when /^User:.+$/
  User.find_by_token(decoded_token["aud"].split(":").last)
else
  raise "NOPE"
end
```

### Python sample code:

#### Client:
```python

# Creating claims
now = dt.datetime.utcnow()
expires = now+dt.timedelta(minutes=2)
assert_jwt = jwt.encode(
    {
        'aud':counterparty_app_id,
        'sub':'anon',
        'iss':PALADIN_APP_ID,
        'iat':calendar.timegm(now.timetuple()),
        'exp':calendar.timegm(expires.timetuple())
    },
    PALADIN_SECRET,
    algorithm='HS512')

# Requesting token
URL='https://paladin.opendoor.com/authorize'
req_params = {
   "grant_type": "urn:ietf:params:oauth:grant-type:sam12-bearer",
   "assertion": assert_jwt.decode('ascii'),
   "client_id": ADDRESSES_UUID,
}

response = requests.post(
    URL,
    headers={"Content-Type":'application/json'},
    data=json.dumps(req_params))
response.raise_for_status()
token = json.loads(response.content.decode('utf-8'))['token']
```

#### Service:
```python

token = read_auth_header_and_strip_bearer(request)
decoded_token = jwt.decode(
    token,
    PALADIN_SECRET,
    audience=PALADIN_APP_ID,
    algorithms=['HS512', 'HS256'])
# perform any app-specific validation on the sub or other token parts
```
