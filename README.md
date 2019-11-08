# Swap my Vote

Swap my Vote is a platform which allows voters to find a partner to swap their vote with.
Rather than voting for their preferred minority party in a constituency where a tactical
vote is necessary or worthwhile, a voter can find someone who will vote for their preferred
party somewhere where that vote makes sense, even under First Past The Post. In return, they
will vote for their partners preferred party as a tactical vote in their own constituency.

Swap my Vote ran a successful project in both the 2015 and 2017 UK general elections at
[www.swapmyvote.uk](https://www.swapmyvote.uk).

In the interests of transparency, all of the code that we have written and used is available
in this repository. We are in the process of working out how to make this project
sustainable, but providing an open and welcoming community for continued developed will be
important. So please have a look at any open issues or get in touch at hello@swapmyvote.uk if you'd like to help.

## Setting up Swap my Vote locally

You will need Ruby installed.

Clone this repository:

    git clone https://github.com/swapmyvote/swapmyvote.git

Install the necessary gems:

    bundle install

If this fails with error messages that mention `pg` or PostgreSQL, then
try instead:

    bundle install --without-production

since the PostgreSQL database is not normally needed for local
development (sqlite is used instead).

Set up some config variables in a `.env.development.local` file:

    $ cp .env.example .env.development.local

Now edit `.env.development.local` to contain the appropriate credentials.  These will get automatically loaded via the `dotenv-rails` gem.

Set up the database schema and populate it with constituency and poll data, as well as some test users accounts for local development.

    bundle exec rake db:setup

Run the application:

    # Ensure binding to localhost even if $HOST is set, so that
    # the URL is accepted by the facebook development app
    bundle exec rails server -b localhost

Open your browser to http://localhost:3000.

Note that in the development environment, emails are not sent but instead written
as files in the `tmp/mails/` subdirectory.

## Contributing to Swap my Vote

Any help would be well appreciated. Please take a look at the [GitHub
project](https://github.com/orgs/swapmyvote/projects/1).  The items in
each column are roughly sorted by priority descending, so a good place
to start would be near the top of the `Next Up` column.

If an issue is already assigned, then probably someone is already intending
to do that.  Likewise if it's unassigned then probably it's up for grabs.
However it's safer to ask on Slack before starting on anything, to avoid
accidentally duplicating effort.

Our roadmap can be seen in our [list of
 milestones](https://github.com/swapmyvote/swapmyvote/milestones?direction=asc&sort=due_date).

## Contact

You can contact us at hello@swapmyvote.uk.

## License

TBD.
