#!/usr/bin/env ruby
require 'json'
require 'logger'

require 'stripe'
require 'sinatra'
require 'thin'

require 'mailgun'
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
ENV['PUSH_ON_SUCCESS']    = '0' if ENV['PUSH_ON_SUCCESS'].nil?
ENV['PUSH_ON_FAILURE']    = '1' if ENV['PUSH_ON_FAILURE'].nil?
ENV['MAIL_ON_SUCCESS']    = '0' if ENV['MAIL_ON_SUCCESS'].nil?
ENV['MAIL_ON_FAILURE']    = '1' if ENV['MAIL_ON_FAILURE'].nil?

# ------------------------------------------------------------------------------
# -- Setup

set :stripe_public_key,  ENV['STRIPE_KEYS'].split(':')[0]
set :stripe_secret_key,  ENV['STRIPE_KEYS'].split(':')[1]
set :stripe_charge_desc, ENV['STRIPE_CHARGE_DESC']

set :pushover_key,    ENV['PUSHOVER_USER_KEY']
set :pushover_token,  ENV['PUSHOVER_APP_TOKEN']
set :pushover_device, ENV['PUSHOVER_DEVICE']
set :push_on_success, ENV['PUSH_ON_SUCCESS']
set :push_on_failure, ENV['PUSH_ON_FAILURE']

set :mailgun_key,     ENV['MAILGUN_API_KEY']
set :mailgun_from,    ENV['MAILGUN_FROM_ADDR']
set :mailgun_to,      ENV['MAILGUN_TO_ADDR']
set :mailgun_domain,  ENV['MAILGUN_DOMAIN']
set :mail_on_success, ENV['PUSH_ON_SUCCESS']
set :mail_on_failure, ENV['PUSH_ON_FAILURE']


Stripe.api_key = settings.stripe_secret_key

if (not settings.pushover_key.nil?) and (not settings.pushover_token.nil?)
  Pushover.configure do |c|
    c.user  = settings.pushover_key
    c.token = settings.pushover_token
  end
end

def send_email(subject, text)
  if (not settings.mailgun_key.nil?) and
      (not settings.mailgun_from.nil?) and
      (not settings.mailgun_to.nil?) and
      (not settings.mailgun_domain.nil?)

    LOG.info "Sending an email to #{settings.mailgun_to}..."
    mailgun_client = Mailgun::Client.new settings.mailgun_key
    mailgun_client.send_message settings.mailgun_domain, {
      :from    => settings.mailgun_from,
      :to      => settings.mailgun_to,
      :subject => subject,
      :text    => text,
    }
  end
end

def send_success_mail(subject, text)
  send_email(subject, text) if settings.mail_on_success == '1'
end

def send_failure_mail(subject, text)
  send_email(subject, text) if settings.mail_on_failure == '1'
end

def push_msg(title, msg)
    Pushover.notification(
      url:       'https://dashboard.stripe.com',
      url_title: 'Visit your Stripe Dashboard',
      device:    settings.pushover_device,
      title:     title,
      message:   msg,
    ) unless settings.pushover_key.nil? or settings.pushover_token.nil?
end

def send_success_push(subject, text)
  push_msg(subject, text) if settings.push_on_success == '1'
end

def send_failure_push(subject, text)
  push_msg(subject, text) if settings.push_on_failure == '1'
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
    dollars = (@amount.to_f/100).round(2)
    LOG.info "Got a donation request for $#{dollars} USD from #{@email}."

    # Create charge.
    Stripe::Charge.create(
      :amount        => @amount,
      :card          => @token,
      :receipt_email => @email,
      :currency      => 'usd',
      :description   => settings.stripe_charge_desc,
    )

    send_success_mail "You just got a donation!",
      "Hey, just letting you know that you just got a donation of "+
      "$#{dollars} USD from #{@email}!"

    send_success_push "Awesome news",
      "You just received a donation of $#{dollars} USD "+
      "from #{@email}!"

    # Finished
    LOG.info "Donation successful!"
    status 200

  # -- Declined
  rescue Stripe::CardError => e
    status e.http_status
    body e.json_body[:error].to_json

  # -- TODO FIXME: This is bad; email?
  rescue Stripe::StripeError => e
    status e.http_status
    body e.json_body[:error].to_json

    send_failure_mail "Whoops!", "Your donation server just had an error! #{e}"
    send_failure_push "Uh oh!", "Your donation server just had an error! #{e}"

  # -- Some other transient error
  rescue Stripe::InvalidRequestError,
         Stripe::AuthenticationError,
         Stripe::APIConnectionError => e
    status e.http_status
    body e.json_body[:error].to_json

    send_failure_mail "Whoops!", "Your donation server just had an error! #{e}"
    send_failure_push "Uh oh!", "Your donation server just had an error! #{e}"
  end

end
