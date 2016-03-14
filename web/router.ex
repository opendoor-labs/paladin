defmodule Paladin.Router do
  use Paladin.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :browser_auth do
    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.LoadResource
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authorize do
    plug :accepts, ["json"]
  end

  scope "/", Paladin do
    pipe_through [:browser, :browser_auth] # Use the default browser stack

    get "/", PageController, :index

    get "/auth/:strategy", LoginController, :request
    post "/auth/:strategy/callback", LoginController, :callback
    get "/auth/:strategy/callback", LoginController, :callback
    delete "/logout", LoginController, :delete, as: :logout

    resources "/services", ServiceController do
      patch "/reset_secret", ServiceController, :reset_secret, as: :reset_secret
      resources "/server_partners", ServerPartnerController
    end
  end

  scope "/", Paladin do
    pipe_through [:authorize]

    post "/authorize", AuthorizationController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", Paladin do
  #   pipe_through :api
  # end
end
