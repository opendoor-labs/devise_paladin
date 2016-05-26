# DevisePaladin

Provides a template for a [Paladin](https://github.com/opendoor-labs/paladin)
umbrella application.

This application is intended to be used as a template only. Paladin itself it
brought in as a git submodule - the umbrella application contains only
customizations.

There are 2 applications in the umbrella app.

1. Paladin - a git submodule
2. DeviseUser - Provides authentication logic for accessing the UI using a
   devise user.

Paladin as a git submodule shouldn't be edited directly from within your
Umbrella application. DeviseUser however is the place where you should edit and
customize to your requirements.

## Installation

```sh
git clone https://github.com/opendoor-labs/devise_paladin
cd devise_paladin
git submodule update --init
mix deps.get
mix ecto.migrate -r Paladin.Repo
cd apps/paladin
npm install
cd ../..
```

Your umbrella application is just about ready to start in devlopment. Just edit
your db config in `config/dev.exs` so that it's pointing at your database with
your devise users.

### Preparing for production deploy

Before you deploy to production there are a couple of settings you should
update.

1. `config/prod.exs` - Update the `signing_salt` for the session
2. Ensure your endpoint configuration is correct

### Customizations

Any configuration option found in either `apps/paladin` or `apps/devise_user`
can be overwritten in the top level umbrella applications config files.

#### Restrict acces to some users

You might not want every user in your database to be able to access paladin.

Edit `apps/devise_user/lib/user_login.ex` to tweak the user lookup in the
`find_and_verify_user` function.

*NOTE* The default install allows all users access to Paladin.

#### Customize the login screen

By default, DevisePaladin uses email and password for authentication purposes.
If you want to provide a different setup, you can customize the login view by
writing a Phoenix view that behaves like you want. To tell Paladin to use this
add it in your umbrella applications `config/config.exs`

```elixir
config :paladin, Paladin.LoginController,
  view_module: DeviseUser.LoginView
```

#### BCrypt rounds (stretches)

You may have customized bcyrpt setup in Devise and it'll need to match here.
Update the configuration in the appropriate config file and include:

```elixir
config :comeonin, :bcrypt_log_rounds, 10
```

#### Available permissions

Paladin should know about all the permissions that your applications will be
putting into the access tokens so that it can restrict access appropriately.

Update your `config/config.exs` to reconfigure guardian

```elixir
config :guardian, Guardian,
  permissions: %{
    paladin: [:write_connections, :read_connections],
    web: [:profile_read, :profile_write],
  }
```

You can completely configure Guardian from here if you need to update anything
else like TTL etc.

## Deployment

In addition to the environment variables that Paladin expects, you'll also need
to set `USER_DATABASE_URL`. This can be changed in `config/prod.exs`

#### PALADIN\_USER\_EMAIL\_REGEX

You'll probably want to limit the email addresses that are able to login to
Paladin. Set this environment variable to specify via a regex which email
patterns are allowed to login to the Paladin UI.

```sh
PALADIN_USER_EMAIL_REGEX="@my\.app\.com$" mix phoenix_server
```

### Full list of environment variables

Paladin also requires some environment variables to use:

* `HOST` - The endpoint host
* `SECRET_KEY_BASE` - The phoenix endpoint secret key
* `DATABASE_URL` - The db url for the Paladin.Repo
* `GUARDIAN_SECRET_KEY_BASE` - The Guardian secret for signing Paladins JWTs for
  accessing the UI.

Devise Paladin requires some environment variables

* `USER_DATABASE_URL` - The url for your devise database url
* `PALADIN_USER_EMAIL_REGEX` - A regex pattern to limit the allowable email
  addresses that can be used to login. If you leave this out - all emails have
access to the Paladin UI.

### Example Devise strategy

If you're backing onto devise chances are you'll need a strategy to receive
Paladin generated tokens. This is an example strategy.

```ruby
module Devise
  module Models
    module Paladin
      class Strategy < Devise::Strategies::Authenticatable
        JWT_REG = /^Bearer:?\s+(.*?);?$/

        def store
          false
        end

        def valid?
          request.headers['HTTP_AUTHORIZATION'].present?
        end

        def authenticate!
          match = JWT_REG.match(request.headers['HTTP_AUTHORIZATION'])

          if match.blank? || match[1].blank?
            fail!('Authorization header required')
          else
            claims, user = user_and_claims_from_token(match[1])
            env['paladin.claims'] = claims
            success! user
          end
        rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
          fail!(e.message)
        end

        def user_and_claims_from_token(jwt)
          claims = JWT.decode(jwt, Rails.application.secrets.paladin_secret).first
          case claims['sub']
          when 'anon', nil
            [claims, 'anon']
          when /^User:\d+/
            [claims, User.find(claims['sub'].split(':').last)]
          else
            [claims, nil]
          end
        end
      end
    end
  end
end

# for warden, `:paladin_strategy` is just a name to identify the strategy
Warden::Strategies.add :paladin, Devise::Models::Paladin::Strategy

# for devise, there must be a module named 'Paladin' (name.to_s.classify), and then it looks to warden
# for that strategy. This strategy will only be enabled for models using devise and `:my_authentication` as an
# option in the `devise` class method within the model.
Devise.add_module :paladin, strategy: true
```

In your user model you'll need to add paladin as a strategy to login.

```ruby
  devise ...., :paladin, ....
```

### Implementing a client

When requesting a token from Paladin, first generate an assertion token to
exchange for an access token. This particular client implementation uses
a read through cache to Redis to cache the token for a user.

```ruby
# Provides a client for use obtaining access tokens via paladin
#
# Configured in config/secrets.yml you'll need to add your
# applications ID that you want to talk to.
class PaladinClient
  attr_reader :paladin_uri

  class InvalidToken < StandardError; end

  # Get an assertion token.
  # This is usually not used.
  # Access tokens are usually what you're after
  # @param user - The human record
  # @param app_id_to_talk_to - The paladin application ID you're asking for access to
  # @param claims - A set of claims that will be embedded into the token
  def self.assertion_token(user, app_id_to_talk_to, claims = {})
    new.assertion_token(user, app_id_to_talk_to, claims)
  end

  # Obtain an access token for use with another application from the Paladin authentication service
  # @param user - The human record
  # @param app_id_to_talk_to - The paladin application ID you're asking for access to
  # @param claims - A set of claims that will be embedded into the token
  def self.access_token(user, app_id_to_talk_to, claims = {})
    new.access_token(user, app_id_to_talk_to, claims)
  end

  def initialize
    @paladin_uri = Addressable::URI.parse(Rails.configuration.paladin_uri)
    @http = new_http
    @redis = Redis.new
  end

  def assertion_token(user, app_id_to_talk_to, claims = {})
    claims.merge!(
      aud: app_id_to_talk_to,
      sub: "User:#{user.id}",
      iss: Rails.application.secrets.paladin_app_id,
      iat: Time.now.utc.to_i,
      exp: (Time.now + 2.minutes).utc.to_i
    )

    JWT.encode(claims, Rails.application.secrets.paladin_secret, 'HS512')
  end

  def access_token(user, app_id_to_talk_to, claims = {})
    read_through_cache(user, app_id_to_talk_to) do
      token = assertion_token(user, app_id_to_talk_to, claims)

      params = {
        'grant_type' => 'urn:ietf:params:oauth:grant-type:sam12-bearer',
        'assertion' => token,
        'client_id' => Rails.application.secrets.paladin_app_id,
      }

      request = Net::HTTP::Post.new(paladin_uri.request_uri)
      request.body = params.to_json
      request.set_content_type('application/json')

      handle_response @http.request(request)
    end
  end

  private

  def handle_response(response)
    case response
    when Net::HTTPOK
      json = JSON.parse(response.body)
      exp = Time.at(response.header['x-expiry'].to_i)
      { token: json['token'], exp: exp }.with_indifferent_access
    when Net::HTTPUnauthorized
      json = JSON.parse(response.body)
      raise InvalidToken, json['error_description']
    else
      raise InvalidToken, response.body
    end
  end

  def read_through_cache(user, app_id)
    cache_key = "Paladin:User:#{user.id}:#{app_id}"
    raw_json = @redis.get(cache_key)
    return JSON.parse(raw_json).with_indifferent_access if raw_json.present?
    result = yield
    expire_in = (result[:exp] - Time.now).to_i - 30
    @redis.setex(cache_key, expire_in, result.to_json) if expire_in > 0
    result
  end

  def new_http
    http = Net::HTTP.new(
      paladin_uri.host,
      paladin_uri.port || Addressable::URI::PORT_MAPPING[paladin_uri.scheme]
    )

    if paladin_uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    http
  end
end
```

