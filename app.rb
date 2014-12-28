#!/usr/bin/env ruby
require 'json'
require 'logger'

require 'stripe'
require 'sinatra'
require 'thin'

require 'pushover'

# ------------------------------------------------------------------------------
# -- Checks

LOG = Logger.new(STDOUT)

if ENV['STRIPE_KEYS'].nil?
  LOG.fatal "STRIPE_KEYS must be set."
  Kernel.exit(1)
end

if ENV['STRIPE_KEYS'].split(':').length != 2
  LOG.fatal "STRIPE_KEYS must be of the form '<PUBKEY>:<SECRETKEY>'"
  Kernel.exit(1)
end

# Default setup
ENV['CORS_ACCEPT_DOMAIN'] = '*' if ENV['CORS_ACCEPT_DOMAIN'].nil?

# ------------------------------------------------------------------------------
# -- Setup

set :stripe_public_key,  ENV['STRIPE_KEYS'].split(':')[0]
set :stripe_secret_key,  ENV['STRIPE_KEYS'].split(':')[1]
set :stripe_charge_desc, ENV['STRIPE_CHARGE_DESC']

set :pushover_key,    ENV['PUSHOVER_USER_KEY']
set :pushover_token,  ENV['PUSHOVER_APP_TOKEN']
set :pushover_device, ENV['PUSHOVER_DEVICE']

Stripe.api_key = settings.stripe_secret_key

if (not settings.pushover_key.nil?) and (not settings.pushover_token.nil?)
  Pushover.configure do |c|
    c.user  = settings.pushover_key
    c.token = settings.pushover_token
  end
end


# ------------------------------------------------------------------------------
# -- Route handlers

# -- Show public key
get '/pubkey.js' do
  response['Access-Control-Allow-Origin'] = ENV['CORS_ACCEPT_DOMAIN']

  content_type 'text/javascript'
  "var stripe_pubkey = \"#{settings.stripe_public_key}\";"
end

# -- Ping URL
get '/ping' do
  LOG.info "Ping received."
  status 200
end

# -- Donation handler
post '/charge' do
  @amount = params[:amount]
  @token  = params[:token]
  @email  = params[:email]

  response['Access-Control-Allow-Origin'] = ENV['CORS_ACCEPT_DOMAIN']

  begin
    # Create charge.
    Stripe::Charge.create(
      :amount        => @amount,
      :card          => @token,
      :receipt_email => @email,
      :currency      => 'usd',
      :description   => settings.stripe_charge_desc,
    )

    Pushover.notification(
      url:       'https://dashboard.stripe.com',
      url_title: 'Visit your Stripe Dashboard',
      title:     'Awesome news',
      device:    settings.pushover_device,
      message:
        "You just received a donation of $#{@amount.to_f/100} USD "+
        "from #{@email}!",
    ) unless settings.pushover_key.nil? or settings.pushover_token.nil?

    # Finished
    status 200

  # -- Declined
  rescue Stripe::CardError => e
    status e.http_status
    body e.json_body[:error].to_json

  # -- TODO FIXME: This is bad; email?
  rescue Stripe::StripeError => e
    status e.http_status
    body e.json_body[:error].to_json

  # -- Some other transient error
  rescue Stripe::InvalidRequestError,
         Stripe::AuthenticationError,
         Stripe::APIConnectionError => e
    status e.http_status
    body e.json_body[:error].to_json
  end
end
