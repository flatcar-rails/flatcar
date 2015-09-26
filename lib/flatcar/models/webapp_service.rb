require('yaml')

module Flatcar
  class WebappService < Service

    def initialize(base_image, database)
      @base_image = base_image
      @database = database
    end

    def dockerfile
      [
        base_image_instruction,
        database_dependency_install_instruction,
        'RUN mkdir -p /usr/src/app',
        'WORKDIR /usr/src/app',
        'COPY . /usr/src/app',
        'RUN bundle install',
        'EXPOSE 3000'
      ].join("\n")
    end

    def to_h
      service_def = {
        'webapp' => {
          'build' => '.',
          'ports' => ['3000:3000'],
          'volumes' => ['.:/usr/src/app'],
          'working_dir' => '/usr/src/app',
          'command' => "bundle exec rails s -b '0.0.0.0'"
        }
      }
      service_def['webapp'].merge!(service_link) if @database
      service_def
    end

    private

    def service_link
      {
        'environment' => ["DATABASE_URL=#{@database.database_url}"],
        'links' => ['db:db']
      }
    end

    def base_image_instruction
      case @base_image
      when 'alpine'
        [
          'FROM flatcar/alpine-rails'
        ].join("\n")
      when 'ubuntu'
        [
          'FROM flatcar/ubuntu-rails'
        ].join("\n")
      when 'debian'
        [
          'FROM flatcar/debian-rails'
        ].join("\n")
      else
        [
          'FROM rails:latest',
          'RUN apt-get update && apt-get install -y nodejs --no-install-recommends && rm -rf /var/lib/apt/lists/*'
        ].join("\n")
      end
    end

    def database_dependency_install_instruction
      case @base_image
      when 'alpine'
        [
          "RUN apk --update --upgrade add #{alpine_database_dependencies} && rm -rf /var/cache/apk/*"
        ].join("\n")
      else
        [
          "RUN apt-get update && apt-get install -y #{debian_based_database_dependencies} --no-install-recommends && rm -rf /var/lib/apt/lists/*"
        ].join("\n")
      end
    end

    def alpine_database_dependencies
      case database_name
      when 'postgresql'
        'postgresql-dev'
      when 'mysql'
        'mysql'
      else
        'sqlite-dev'
      end
    end

    def debian_based_database_dependencies
      case database_name
      when 'postgresql'
        'postgresql-client'
      when 'mysql'
        'mysql-client'
      else
        'libsqlite3-dev'
      end
    end

    def database_name
      return 'default' if @database.nil?
      @database.name
    end
  end
end
