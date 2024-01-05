## ScalikeJDBC website

https://scalikejdbc.org/

### How to contribute scalikejdbc.org?

#### fork scalikejdbc.github.io project

Fork [https://github.com/scalikejdbc/scalikejdbc.github.io](https://github.com/scalikejdbc/scalikejdbc.github.io).

#### change under the website directory

How to debug:

```
git clone [your forked repository].
cd scalikejdbc.github.io
gem install bundler
bundle install --path vendor/bundle
# bundle exec middleman build
bundle exec middleman server
```

Access `http://localhost:4567/` from your browser.

#### make a pull request

Create a branch to request, and send your pull request to `develop` branch (not `master` branch).


