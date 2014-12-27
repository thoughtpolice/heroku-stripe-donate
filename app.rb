#!/usr/bin/env ruby
require 'json'
require 'stripe'
require 'sinatra'
require 'thin'

# ------------------------------------------------------------------------------
# -- Checks

if ENV['STRIPE_KEYS'].nil?
  puts "The environment variable STRIPE_KEYS must be set to a string containing"
  puts "Stripe API keys separated by a colon, e.g. 'PUBLIC_KEY:SECRET_KEY'"
  exit 1
end

# ------------------------------------------------------------------------------
# -- Setup

set :stripe_public_key,  ENV['STRIPE_KEYS'].split(':')[0]
set :stripe_secret_key,  ENV['STRIPE_KEYS'].split(':')[1]
set :stripe_charge_desc, ENV['STRIPE_CHARGE_DESC']

Stripe.api_key = settings.stripe_secret_key

get '/donate/pubkey.js' do
  response['Access-Control-Allow-Origin'] = '*'

  content_type 'text/javascript'
  "var stripe_pubkey = \"#{settings.stripe_public_key}\";"
end

get '/donate/ping' do
  response['Access-Control-Allow-Origin'] = '*'
  status 200
end

# ------------------------------------------------------------------------------
# -- Donation handler
post '/donate/charge' do
  @amount = params[:amount]
  @token  = params[:token]
  @email  = params[:email]

  response['Access-Control-Allow-Origin'] = '*'

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
