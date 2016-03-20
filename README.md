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
git pull --recurse-submodules
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

* `PORT` - The endpoint port
* `SECRET_KEY_BASE` - The phoenix endpoint secret key
* `DATABASE_URL` - The db url for the Paladin.Repo
* `GUARDIAN_SECRET_KEY_BASE` - The Guardian secret for signing Paladins JWTs for
  accessing the UI.

Devise Paladin requires some environment variables

* `USER_DATABASE_URL` - The url for your devise database url
* `PALADIN_USER_EMAIL_REGEX` - A regex pattern to limit the allowable email
  addresses that can be used to login. If you leave this out - all emails have
access to the Paladin UI.

