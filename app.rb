#!/usr/bin/env ruby
require 'json'
require 'logger'
require 'stripe'
require 'sinatra'
require 'thin'

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

Stripe.api_key = settings.stripe_secret_key

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

# ------------------------------------------------------------------------------
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
      :description   => settings.stripe_charge_desc
    )

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
