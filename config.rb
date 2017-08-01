###
# Compass
###

# Change Compass configuration
# compass_config do |config|
#   config.output_style = :compact
# end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

# Proxy pages (http://middlemanapp.com/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", :locals => {
#  :which_fake_page => "Rendering a fake page with a local variable" }

page "/documentation/1.x/*", :layout => "1.x"
page "/documentation/2.x/*", :layout => "2.x"

###
# Helpers
###

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes

# Reload the browser automatically whenever files change
# activate :livereload

# Methods defined in the helpers block are available in templates
# helpers do
#   def some_helper
#     "Helping"
#   end
# end

set :css_dir, 'stylesheets'

set :js_dir, 'javascripts'

set :images_dir, 'images'

activate :syntax

set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true, smartypants: true, autolink: true, with_toc_data: true

I18n.enforce_available_locales = false

# Latest versions
@latest_version = "3.0.2"
@latest_play_support_version = "2.6.0-scalikejdbc-3.0"
@v2_play_support_version = "2.5.1"
@v2_version = "2.5.2"
@v1_version = "1.7.7"
@v18_version = "1.8.2"

set :version,        @latest_version
set :latest_version, @latest_version
set :latest_play_support_version, @latest_play_support_version
set :v2_play_support_version,     @v2_play_support_version
set :v2_version,        @v2_version
set :v1_version,        @v1_version
set :v18_version,       @v18_version
set :v1_latest_version, @v1_version
set :h2_version,        "1.4.196"
set :logback_version,   "1.2.3"

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  # activate :minify_css

  # Minify Javascript on build
  # activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  # activate :relative_assets

  # Or use a different image path
  # set :http_prefix, "/Content/images/"
end

activate :deploy do |deploy|
  deploy.build_before = true
  deploy.method = :git
  deploy.branch = 'master'
end

