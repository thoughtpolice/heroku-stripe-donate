# heroku-stripe-donate: Simple backend server for Stripe based donations

Lets say you have a website, and you'd like to accept donations
through it. [Stripe](https://www.stripe.com) is a pretty nifty service
to accept donations from all around the globe.

Unfortunately, like many people, it's much more convenient for me to
not have to run an application server to handle backend requests for
things like donations. Most of the content on my pages are static and
this is unlikely to change, and I'd rather not shove in and maintain a
server backend to handle requests for only this one dynamic aspect.

This application solves that - it's a precanned Ruby application
(designed to run on Heroku), that accepts POST requests from frontend
servers, charges people via Stripe, and that's all.

The idea is you can sign up for a free heroku account, start this
server, and then host a static page (anywhere you want, even on
another Heroku application) that makes requests to it for
donations. That way you can leave it alone and you don't have to run
your own server on-site.

**NOTE**: This server has only been tested with Credit Card and
Bitcoin payments through Stripe's (awesome) `checkout.js` project.

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/thoughtpolice/heroku-stripe-donate)

## Starting the server

Clone the repo, create an app.

```bash
$ git clone https://github.com/thoughtpolice/heroku-stripe-donate.git
$ cd heroku-stripe-donate
$ heroku create donate-MYAPP
Creating donate-MYAPP... done, stack is cedar-14
https://donate-MYAPP.herokuapp.com/ | git@heroku.com:donate-MYAPP.git
Git remote heroku added
```

Now add your Stripe publishable/secret keys to the `STRIPE_KEYS`
configuration variable. This variable takes the format
`"PUBLIC_STRIPE_KEY:PRIVATE_STRIPE_KEY"`

```bash
$ heroku config:add STRIPE_KEYS="pk_test_XXXXXXXX:sk_test_XXXXXXXX"
Setting config vars and restarting donate-MYAPP... done, v3
STRIPE_KEYS: "pk_test_XXXXXXXX:sk_test_XXXXXXXX"
```

Now push, and your server will start up:

```bash
$ git push heroku master
...
```

Your server is started. Now you need to make your frontend `POST`
charge requests to the server; see below for more.

**NOTE**: Your web dyno will spin down after a certain amount of
time. You might like to use my
[heroku-ping](https://github.com/thoughtpolice/heroku-ping)
application to keep it alive.

## Usage

Once the server is started, there are 3 URLs it makes available:

  - `/pubkey.js` - a JavaScript file that contains a single
    variable named `stripe_pubkey`, containing your publishable Stripe
    key.

  - `/charge` - a `POST` endpoint that you send Stripe tokens
    to, so the Stripe API can charge them. Note that this endpoint

  - `/ping` - making a `GET` request here only responds with a
    200 HTTP status and has no other effect. It is meant to be used by
    [heroku-ping](https://github.com/thoughtpolice/heroku-ping) or
    another application to keep your Dyno alive.

The basic idea is that you include
`https://donate-MYAPP.herokuapp.com/pubkey.js` on your page to
get access to your public key, and then you use that key to make a
request to `https://donate-MYAPP.herokuapp.com/charge` via an
API like `checkout.js`. **NB**: the server automatically sets outgoing
CORS headers, so browsers are happy with making external
`XMLHttpRequest` calls that would normally violate SOP.

The reason you include `pubkey.js` is so that you can switch API keys
easily and in a singular place by simply modifying your Heroku
environment variables for this application. This allows you to quickly
switch between test/live mode keys or separate accounts entirely
simply using `heroku config:set ...` - you won't need to update your
static pages unless your application URL itself changes.

## Running the demo

Under `demo/` you can find an example static website to make charges
via this backend server which uses Bootstrap and jQuery to make a neat
bona-fide whiz-bang AJAX-ized donation form.

Once you've completed the steps above, you can get running with the
demo by saying:

```bash
$ export HEROKU_URL=my-heroku-app.herokuapp.com
$ sed -i "s/MYAPPLICATION.herokuapp.com/$HEROKU_URL/g" demo/index.html demo/donate.js
$ cd demo && python -m SimpleHTTPServer
```

Now visit http://localhost:8000, and test out the donation button! It
works with both Credit Card and Bitcoin, too.

## [Pushover.net](https://pushover.net) support

If you have an account with [Pushover.net](https://pushover.net), you
can configure extra environment variables to enable push
notifications to be sent to your devices.

  - `PUSHOVER_USER_KEY`  - Your `pushover.net` user API key.
  - `PUSHOVER_APP_TOKEN` - Your `pushover.net` application token.
  - `PUSHOVER_DEVICE` - Specify a particular registered device by
    name; only this device will receive pushes.

It's recommended you simply create a new application for your
deployment (in the 'Apps & Plugins' section of the website) titled
something like 'Stripe Donations', and use that applications token for
push notifications.

# Join in

Be sure to read the [contributing guidelines][contribute]. File bugs
in the GitHub [issue tracker][].

Master [git repository][gh]:

* `git clone https://github.com/thoughtpolice/heroku-stripe-donate.git`

There's also a [BitBucket mirror][bb]:

* `git clone https://bitbucket.org/thoughtpolice/heroku-stripe-donate.git`

# Authors

See [AUTHORS.txt](https://raw.github.com/thoughtpolice/heroku-stripe-donate/master/AUTHORS.txt).

# License

MIT. See
[LICENSE.txt](https://raw.github.com/thoughtpolice/heroku-stripe-donate/master/LICENSE.txt)
for terms of copyright and redistribution.

[contribute]: https://github.com/thoughtpolice/heroku-stripe-donate/blob/master/CONTRIBUTING.md
[issue tracker]: http://github.com/thoughtpolice/heroku-stripe-donate/issues
[gh]: http://github.com/thoughtpolice/heroku-stripe-donate
[bb]: http://bitbucket.org/thoughtpolice/heroku-stripe-donate
