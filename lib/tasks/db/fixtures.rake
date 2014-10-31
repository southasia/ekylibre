namespace :db do
  namespace :fixtures do

    desc "Write database into fixtures files (removing existing files)"
    task :dump => :environment do
      Fixturing.dump(ENV["TENANT"] || ENV["name"] || "demo")
    end

    desc "Load fixtures files in tenant (removing existing data)"
    task :restore => :environment do
      Fixturing.restore(ENV["TENANT"] || ENV["name"] || "demo")
    end

    desc "There and Back Again like Bilbo"
    task :bilbo => [:restore, :dump]

    desc "Demodulates fixtures to have real ids"
    task :demodulate => :environment do
      Fixturing.columnize_keys
    end

    desc "Modulates fixtures to have human fixtures"
    task :modulate => :environment do
      Fixturing.reflectionize_keys
    end

  end
end
