# C2

[![Build Status](https://travis-ci.org/18F/C2.svg?branch=master)](https://travis-ci.org/18F/C2)

For an overview of this project, please visit our github [pages](http://18f.github.io/C2/).

## INSTALLATION

In order to foster as much reuse as possible, the C2 project is a molecule of 3 repos,
each of which in theory might be reusable independently.  In practice, we on the
team need to have all three installed to have C2 function as demoed on our gitub [pages][http://18f.github.io/C2/].

These repos are:

[C2](https://github.com/18F/C2) -- this repo.
[mario](https://github.com/18F/Mario) -- the Mario repo reads email, in some cases invokes a scraper, and ultimately posts JSON back to C2.
[gsa-advantage-scrape](https://github.com/18F/gsa-advantage-scrape) -- This is a scraper for GSA Advantage which is independently usable,
but it is used, at least in some cases, by Mario.

These three repos must be installed, and must be configured to connect to each other properly.  Although there are of course many
ways to do this, this section describes one preferred mechanism for doing this.

## Installing the scraper

Follow the instructions in the gsa-advantage-scrape (https://github.com/18F/gsa-advantage-scrape) README.  This assumes that
you are installing with Apache, on the same machine, although you could install it some other way.

## Installing Mario

Although C2 can be used without Mario, the normal mode is to use Mario, which allows the C2 communicarts to be constructed by emails.  However, C2 has other features which allow carts to be constructed without email from arbitrary websites.  If you intend to use this approach, you don't need to install Mario.  Mario is dependent on both C2 and GSA Advantage.

## Installing C2

C2 is basically a standard rails application, so it can be installed with basic apparoaches.

```
git clone https://github.com/18F/C2
cd C2
```

To get database and tests running:

- Start mysql if it isn't already (mysql.server start at command line)
- Create a db config file by copying config/database.yml.example to config/database.yml
- Assuming that you don't have a password on mysql, you can use that file as is.
  Otherwise, update the info in the yml to match your creds.
- Create two database in mysql: 'c2_development' and 'c2_test'
- Run `rake db:migrate` and `RAILS_ENV=test rake db:migrate` from the project directory
- Run the specs with `rspec spec` at the command line 


To get app running:

- Create an environment config file by copying config/environment_variables.yml.example to config/environment_variables.yml
  - `GMAIL_USERNAME` should be rensender you're using (e.g. communicart.sender@gmail.com or communicart.test@gmail.com)
  - `GMAIL_PASSWORD` is the password for that email account