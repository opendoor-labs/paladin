# Paladin

Paladin is an implementation of the OAuth2 assertion spec. It is intended to
provide service to service authentication by using JWT as the credential
mechanism.

It uses [Guardian](https://github.com/ueberauth/guardian) for it's JWT
processing.

Paladin is setup to use within an Umbrella application.

## General concept

#### Setup your services

1. Register you application with Paladin
2. Register a second application with Paladin.
3. Configure a connection from one to another (including max permissions and TTL)

#### Regular requests

1. Create an assertion token signed with your secret
2. Send the assertion token to Paladin to exchange for an access token signed
   with the other services secret.
3. Use the access token to make requests to your other service.

All tokens in the exchange are JWT.

When you register a service with Paladin, you will be issued with:

1. A service id (uuid)
2. A Secret

The secret is used in your service as the signing secret of your JWTs. For
Guardian this is the `secret_key_base`.

#### Example

Lets say you add `App1` and `App2` to Paladin, and `App1` would like to talk to
`App2`. Add a connection from `App1` to `App2`.

`App1` now wants to make a request to `App2`. The first thing to do is generate
a JWT and sign it with your Paladin provided secret.

Required claims that you must set are:

* `aud` - The uuid of the service that you're intending on speaking to
* `sub` - The subject. For user this could be: `"User:#{user.token}"`. When there is no
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

  def assertion_jwt(user, app_id_to_talk_to)
    claims = {
      aud: app_id_to_talk_to,
      sub: "User:#{user.id}",
      iss: MY_PALADIN_APP_ID,
      iat: Time.now.utc.to_i,
      exp: (Time.now + 2.minutes).utc.to_i,
    }

    JWT.encode(claims, MY_PALADIN_SECRET, 'HS256')
  end
```

*NOTE* When generating the token you need to include the `aud`, `sub`, `iss`,
`iat`, and the `exp` to be set. iat and exp should be UTC unix timestamp.

Now that you have your JWT, you'll need to request one that has been signed
correctly for the other service.

```ruby

  def access_token(user, app_to_talk_to_id)
    params = {
      "grant_type" => "urn:ietf:params:oauth:grant-type:sam12-bearer",
      "assertion" => assertion_jwt(user, app_to_talk_to_id),
      "client_id" => MY_PALADIN_APP_ID
    }

    response = HTTParty.post(
      PALADIN_DOMAIN + "/authorize",
      body: params.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    json = JSON.parse(response.body)
    if json["token"]
      exp = response.headers("x-expiry").to_i
      { token: json["token"], exp: exp }
    else
      raise "OH NO! #{json["error"]} - #{json["error_description"]}"
    end
  end

  token = access_token(user)[:token]

  # Now we have a token, lets
  profit = HTTParty.get(
    "https://the_service.com/blah/things",
    headers: {
      "Authorization" => "Bearer #{token}"
    }
  )
```

On the receiving side, if you're already using JWT for authentication (using the
secret from Paladin) you have nothing more to do. You'll receive a valid token
and you're away. If not, setting up JWT authentication can start simply.

Read from the Authorization header and strip out the part after `"Bearer "`

```ruby
token = read_auth_header_and_strip_bearer(env)
decoded_token = JWT.decode(token, PALADIN_SECRET, true, { :algorithm => 'HS512' }).first
```

If you get to here... you have a winner. You can find out who the user is:

```ruby

case decoded_token["sub"]
when "anon"
  nil
when /^User:.+$/
  User.find_by_token(decoded_token["sub"].split(":").last)
else
  raise "NOPE"
end
```

This covers the core part of what Paladin does. There's also a little more that
you can do:

### Permissions

When you configure one service to connect to another, you have an opportunity to
limit the permissions that may be granted. When generating the assertiong token, you should
include permissions that you want to request encoded using Guardian.Permissions method (a map of
bitstrings). Paladin will check the permissions requested against the maximum
permissions granted in Paladin. The resulting access token will have the
requested permissions, up to the limit of the maximum permissions.

### Token expiry

When generating your assertion token, you should use a short time, seconds
usually. Depending on your service, you may want the access token to be limited
in it's expiry also. You can configure the maximum TTL of an acces token when
setting up the connection in Paladin.

To request an expiry in your assertion token, set the expiry in the `rexp` key.
Paladin will check this, and check the max TTL giving you the requested time
unless it exceeds the max TTL. Then you will be given back an expiry of issued +
max TTL. By default you are given issued + max TTL.

## Installation and Setup

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
    ```
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
  signing_salt: "some_salt"
```

All other required configuration is exported as environment variables that need
to be set. Here is a list of them:

* `PORT` - The endpoint port
* `SECRET_KEY_BASE` - The phoenix endpoint secret key
* `DATABASE_URL` - The db url for the Paladin.Repo
* `GUARDIAN_SECRET_KEY_BASE` - The Guardian secret for signing Paladins JWTs for
  accessing the UI.

All of these can of course be overwritten by overwriting the required config
fields. The can all be found in `apps/paladin/config/prod.exs`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Deploying

Paladin is best kept behind a firewall if possible. It's not however required.

You _can_ deploy to heroku if you want. To do this configure the url host in
your umbrella application and use the following buildbacks:

```
https://github.com/HashNuke/heroku-buildpack-elixir.git
https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
```

You'll also need to setup a configuration file to compile assets correctly:

`phoenix_static_buildpack.config`

```
phoenix_relative_path=apps/paladin
```

#### Example Python Client:
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
