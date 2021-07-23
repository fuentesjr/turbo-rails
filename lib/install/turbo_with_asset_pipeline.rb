# frozen_string_literal: true

# Some preliminary CONSTANTS
MOUNTABLE_ENGINE        = !!Rails.root.to_s.match(%r{(spec|test)/dummy})
PROJECT_ROOT            = MOUNTABLE_ENGINE ? Rails.root.join("../..") : Rails.root
ENGINE_NAME             = PROJECT_ROOT.to_s.split('/').last
ENGINE_DIRECTORY        = MOUNTABLE_ENGINE ? "/#{ENGINE_NAME}" : ''
APPLICATION_LAYOUT_PATH = PROJECT_ROOT.join("app/views/layouts#{ENGINE_DIRECTORY}/application.html")
IMPORTMAP_PATH          = PROJECT_ROOT.join("app/assets/javascripts#{ENGINE_DIRECTORY}/importmap.json.erb")
CABLE_CONFIG_PATH       = Rails.root.join("config/cable.yml")

def locate_layout_application_file
  %w[.html.erb .html.slim .slim .html.haml .haml].each do |file_extension|
    filename = APPLICATION_LAYOUT_PATH.sub_ext(file_extension)
    return filename, file_extension if filename.exist?
  end
  [nil, nil]
end

def indents_in_layout_application(filename)
  spaces = File.open filename do |file|
    file.find { |line| line =~ /^(\s*)(<|=|= |%)title/ }
  end
  spaces.match(/^(\s*)/)[1] || '    '
end

def insert_yield_head_into_application_html(filename, file_extension, spaces)
  say "Add 'yield :head' to #{filename} (for cache helper).", :green
  insert_into_file filename.to_s,
                   case file_extension
                   when '.html.slim', '.slim', '.html.haml', '.haml'
                     "\n#{spaces}= yield :head"
                   else # defaults to ERB
                     "\n#{spaces}<%= yield :head %>"
                   end,
                   before: case file_extension
                           when '.html.slim', '.slim'
                             /\s*body/
                           when '.html.haml', '.haml'
                             /\s*%body/
                           else # defaults to ERB
                             %r{\s*</head>}
                           end
end

def insert_turbo_link_tag_into_application_html(filename, file_extension, spaces)
  say %(Add "javascript_include_tag :turbo" to #{filename}), :green
  insert_into_file filename.to_s,
                   case file_extension
                   when '.html.slim', '.slim', '.html.haml', '.haml'
                     %(\n#{spaces}= javascript_include_tag "turbo", type: "module-shim")
                   else # defaults for ERB
                     %(\n#{spaces}<%= javascript_include_tag "turbo", type: "module-shim" %>)
                   end,
                   after: if filename.read =~ /stimulus/
                            /=\s*stimulus_include_tags.*$/
                          else
                            # Different selector to original, but does the same thing
                            /yield :head.*$/
                          end
end

def update_layout_application_file
  file_name, file_extension = locate_layout_application_file
  if file_name.nil?
    say %(      Could not find application.html.erb|slim|haml.), :red
    say %(      You need to add the following to the <head> tag, after the stimulus_include_tags, in your custom layout:), :red
    say %(        <%= javascript_include_tag("turbo", type: "module-shim") %>), :red
    say %(        <%= yield :head %>), :red
    return
  end

  spaces = indents_in_layout_application file_name
  insert_yield_head_into_application_html file_name, file_extension, spaces
  insert_turbo_link_tag_into_application_html file_name, file_extension, spaces
end

def add_turbo_to_importmap_file
  if IMPORTMAP_PATH.exist?
    say %(Add Turbo to importmap), :green
    insert_into_file IMPORTMAP_PATH,
                     %(    "turbo": "<%= asset_path "turbo" %>",\n),
                     after: /  "imports": {\s*\n/
  else
    say %(Did not find the file #{IMPORTMAP_PATH}.), :yellow
    say %(      This file is used by StimulusJS.  If you create one later, add this:), :yellow
    say %(      "turbo": "<%= asset_path "turbo" %>",), :yellow
  end
end

def update_gemspec
  gemspec_file = Dir[PROJECT_ROOT.join("*.gemspec")].first
  say %(Could not find a .gemspec file.  Please add 'redis' as a dependency.), :red unless gemspec_file

  say %(Add redis as a dependency to the .gemspec file.), :green
  insert_into_file gemspec_file,
                   %(  spec.add_dependency "redis"\n),
                   before: /^end\s*$/
end

def update_gemfile
  say %(Could not find the Gemfile.  Please de-comment 'redis'.), :red unless PROJECT_ROOT.join("Gemfile").exist?

  say %(De-comment redis in the Gemfile.), :green
  uncomment_lines PROJECT_ROOT.join("Gemfile"), %(gem "redis")
end

def update_cable_yaml_file
  if CABLE_CONFIG_PATH.exist?
    say %(Update config/cable.yml to use redis in development mode.), :green
    gsub_file CABLE_CONFIG_PATH.to_s,
              /development:\n\s+adapter: async/,
              "development:\n  adapter: redis\n  url: redis://localhost:6379/1"
  else
    say %(ActionCable's config file (config/cable.yml) is missing.), :yellow
    say %(Create config/cable.yml to use the Turbo Streams broadcast feature.), :yellow
  end
end

#####
# Execute each step
say %(Adding turbo-rails using the asset pipeline:)
update_layout_application_file
add_turbo_to_importmap_file
MOUNTABLE_ENGINE ? update_gemspec : update_gemfile
update_cable_yaml_file
say "Turbo successfully installed ⚡️", :green

###############
## OLD CODE  ##
###############

# if APPLICATION_LAYOUT_PATH.exist?
  # say "Add 'Yield head' in application layout for cache helper"
  # insert_into_file APPLICATION_LAYOUT_PATH.to_s, "\n    <%= yield :head %>", before: %r{\s*</head>}

  # if APPLICATION_LAYOUT_PATH.read =~ /stimulus/
    # say "Add Turbo include tags in application layout"
    # insert_into_file APPLICATION_LAYOUT_PATH.to_s, %(\n    <%= javascript_include_tag "turbo", type: "module-shim" %>), after: /<%= stimulus_include_tags %>/

    # if IMPORTMAP_PATH.exist?
    #   say "Add Turbo to importmap"
    #   insert_into_file IMPORTMAP_PATH, %(    "turbo": "<%= asset_path "turbo" %>",\n), after: /  "imports": {\s*\n/
    # end
  # else
    # say "Add Turbo include tags in application layout"
    # insert_into_file APPLICATION_LAYOUT_PATH.to_s, %(\n    <%= javascript_include_tag "turbo", type: "module" %>), before: %r{\s*</head>}
  # end
# else
  # say "Default application.html.erb is missing!", :red
  # say %(        Add <%= javascript_include_tag("turbo", type: "module-shim") %> and <%= yield :head %> within the <head> tag after Stimulus includes in your custom layout.)
# end

# if CABLE_CONFIG_PATH.exist?
#   say "Enable redis in bundle"
#   uncomment_lines "Gemfile", %(gem 'redis')
#
#   say "Switch development cable to use redis"
#   gsub_file CABLE_CONFIG_PATH.to_s, /development:\n\s+adapter: async/, "development:\n  adapter: redis\n  url: redis://localhost:6379/1"
# else
#   say 'ActionCable config file (config/cable.yml) is missing. Uncomment "gem \'redis\'" in your Gemfile and create config/cable.yml to use the Turbo Streams broadcast feature.'
# end
