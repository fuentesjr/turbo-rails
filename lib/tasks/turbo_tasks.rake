def run_turbo_install_template(path, namespace = nil)
  system "#{RbConfig.ruby} #{Rails.root}/bin/rails #{namespace}app:template LOCATION=#{File.expand_path("../install/#{path}.rb",  __dir__)}"
end

def redis_installed?
  system('which redis-server > /dev/null')
end

def switch_on_redis_if_available(namespace)
  if redis_installed?
    Rake::Task["#{namespace}turbo:install:redis"].invoke
  else
    puts "Run turbo:install:redis to switch on Redis and use it in development for turbo streams"
  end
end

def find_namespace(task)
  task.name.split(/turbo:install/).first
end


namespace :turbo do
  desc "Install Turbo into the app"
  task :install do |task|
    namespace = find_namespace(task)
    if Rails.root.join("config/importmap.rb").exist?
      Rake::Task["#{namespace}turbo:install:importmap"].invoke
    elsif Rails.root.join("package.json").exist?
      Rake::Task["#{namespace}turbo:install:node"].invoke
    else
      puts "You must either be running with node (package.json) or importmap-rails (config/importmap.rb) to use this gem."
    end
  end

  namespace :install do
    desc "Install Turbo into the app with asset pipeline"

    task :importmap do |task|
      namespace = find_namespace(task)
      run_turbo_install_template "turbo_with_importmap"
      switch_on_redis_if_available(namespace)
    end

    desc "Install Turbo into the app with webpacker"
    task :node do |task|
      namespace = find_namespace(task)
      run_turbo_install_template "turbo_with_node"
      switch_on_redis_if_available(namespace)
    end

    desc "Switch on Redis and use it in development"
    task :redis do
      run_turbo_install_template "turbo_needs_redis"
    end
  end
end
