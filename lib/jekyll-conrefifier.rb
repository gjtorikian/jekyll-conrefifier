module Jekyll
  module ConrefifierUtils
    class << self; attr_accessor :og_paths; end

    # fetch the custom scope vars, as defined in _config.yml
    def self.data_file_variables(config, path)
      data_vars = {}
      scopes = config['data_file_variables'].select { |v| v['scope']['path'].empty? || Regexp.new(v['scope']['path']) =~ path }
      scopes.each do |scope|
        data_vars = data_vars.merge(scope['values'])
      end
      data_vars
    end

    def self.setup_config(site, opts, path)
      data_vars = path.nil? ? {} : ConrefifierUtils.data_file_variables(site.config, opts[:actual_path] || path)
      config = { 'page' => data_vars }
      config = { 'site' => { 'data' => site.data, 'config' => site.config } }.merge(config)
    end

    def self.convert(content, data_vars)
      value = Liquid::Template.parse(content).render(data_vars)
      # protects against situations where [page.version] prevented a conversion
      if value =~ /\{\{/
        value = Liquid::Template.parse(value).render(data_vars)
      end
      value = value.gsub('"', '\"')
    end
  end

  class Document
    # remove when on a moderner Jekyll
    FRONT_REGEXP = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m

    # allow us to use any variable within Jekyll Frontmatter; for example:
    # title: What are {{ site.data.conrefs.product_name[site.audience] }} Pages?
    # renders as "GitHub Pages?" for dotcom, but "GitHub Enterprise Pages?" for Enterprise
    def read(opts = {})
      if yaml_file?
        @data = SafeYAML.load_file(path)
      else
        begin
          defaults = @site.frontmatter_defaults.all(url, collection.label.to_sym)
          unless defaults.empty?
            @data = defaults
          end
          @content = File.read(path, merged_file_read_opts(opts))
          if content =~ FRONT_REGEXP
            @content = $POSTMATCH
            prev_match = $1
            prev_match = prev_match.gsub(/\{\{.+?\}\}/) do |match|
              data_vars = ConrefifierUtils.setup_config(@site, opts, path)
              value = ConrefifierUtils.convert(match, data_vars)
              value = Jekyll::Renderer.new(@site, self).convert(value)
              value = value.gsub(/:/, '&#58;')
              value = value.gsub(/\\"/, '&#34;')
              value.sub(/^<p>/, '').sub(/<\/p>$/, '').strip
            end

            data_file = SafeYAML.load(prev_match)
            unless data_file.nil?
              @data = Utils.deep_merge_hashes(defaults, data_file)
            end
          end
        rescue SyntaxError => e
          puts "YAML Exception reading #{path}: #{e.message}"
        rescue Exception => e
          puts "Error reading file #{path}: #{e.message}"
        end
      end

      @data.each_pair do |key, value|
        if value =~ /(\{% (?:if|unless).+? %\}.*?\{% end(?:if|unless) %\})/
          data_vars = ConrefifierUtils.setup_config(@site, opts, path)
          value = ConrefifierUtils.convert(value, data_vars)
          value = Jekyll::Renderer.new(@site, self).convert(value)
          @data[key] = value.sub(/^<p>/, '').sub(/<\/p>$/, '').strip
        end
      end
    end
  end

  class Site
    alias_method :old_read_collections, :read_collections

    def in_source_dir(*paths)
      paths.reduce(source) do |base, path|
        Jekyll.sanitized_path(base, path)
      end
    end

    # allows us to filter data file contents via conditionals, eg. `{% if page.version == ... %}`
    def read_data_to(dir, data)
      return unless File.directory?(dir) && (!safe || !File.symlink?(dir))

      entries = Dir.chdir(dir) do
        Dir['*.{yaml,yml,json,csv}'] + Dir['*'].select { |fn| File.directory?(fn) }
      end

      ConrefifierUtils.og_paths = [] if ConrefifierUtils.og_paths.nil?

      # all of this is copied from the Jekyll source, except...
      entries.each do |entry|
        path = self.in_source_dir(dir, entry)
        next if File.symlink?(path) && safe

        key = sanitize_filename(File.basename(entry, '.*'))
        if File.directory?(path)
          read_data_to(path, data[key] = {})
        else
          case File.extname(path).downcase
          when '.csv'
            data[key] = CSV.read(path, :headers => true).map(&:to_hash)
          else
            src = config['data_source']
            ConrefifierUtils.og_paths << path.slice(dir.index(src) + src.length + 1..-1).sub(/\.[^.]+\z/, '')
            # if we hit upon if/unless conditionals, we'll need to pause and render them
            contents = File.read(path)
            if (matches = contents.scan /(\{% (?:if|unless).+? %\}.*?\{% end(?:if|unless) %\})/m)
              unless ConrefifierUtils.data_file_variables(config, path).nil?
                contents = contents.gsub(/\{\{/, '[[')
                contents = apply_vars_to_datafile(contents, matches, path)
                contents = contents.gsub(/\[\[/, '{{')
              end
            end

            data[key] = SafeYAML.load(contents)
          end
        end
      end
    end

    def read_collections
      # once we're done reading in the data, we need to iterate once more to parse out `{{ }}` blocks.
      # two reasons for this: one, we need to collect every data file before attempting to
      # parse these vars; two, the Liquid parse above obliterates these tags, so we
      # first need to convert them into `[[ }}`, and *then* continue with the parse
      ConrefifierUtils.og_paths.each do |path|
        keys = path.split('/')
        value = keys.inject(data, :fetch)
        yaml_dump = YAML::dump value
        keys[0...-1].inject(data, :fetch)[keys.last] = SafeYAML.load transform_liquid_variables(yaml_dump, path)
      end
      old_read_collections
    end

    # apply the custom scope plus the rest of the `site.data` information
    def apply_vars_to_datafile(contents, matches, path)
      return contents if matches.empty?

      data_vars = path.nil? ? {} : ConrefifierUtils.data_file_variables(config, path)

      config = { 'page' => data_vars }
      config = { 'site' => { 'data' => self.data, 'config' => self.config } }.merge(config)

      matches.each do |match|
        match = match.is_a?(Array) ? match.first : match

        parsed_content = begin
                          Liquid::Template.parse(match).render(config)
                         rescue
                          match
                         end

        unless match =~ /\{\{/ && parsed_content.empty?
          contents = contents.sub(match, parsed_content)
        end
      end
      contents
    end

    # allow us to use any variable within Jekyll data files; for example:
    # - '{{ site.data.conrefs.product_name[site.audience] }} Glossary'
    # renders as "GitHub Glossary" for dotcom, but "GitHub Enterprise Glossary" for Enterprise
    def transform_liquid_variables(contents, path = nil)
      if (matches = contents.scan /(\{\{.+?\}\})/)
        contents = apply_vars_to_datafile(contents, matches, path)
      end

      contents
    end
  end

  class DataRenderTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super

      keys = text.strip.split('.', 3)
      keys.shift(2) # this is just site.data
      paren_arg = keys.last.match(/\((.+?)\)/)
      unless paren_arg.nil?
        last_key = keys.last.sub(paren_arg[0], '')
        keys.pop
        keys << last_key
        @hash_args = paren_arg[1].gsub(/[{}:]/,'').split(', ').map{|h| h1,h2 = h.split('=>'); {h1.strip => eval(h2.strip)}}.reduce(:merge)
      end
      @keys = keys
      @id = keys.join('-')
    end

    def fetch_datafile(context, keys)
      data_file = context.registers[:site].data["data_render_#{@id}"]
      return data_file unless data_file.nil?

      path = @id.gsub('.', '/')
      data_source = File.join(context.registers[:site].source, context.registers[:site].config['data_source'])
      data_file = File.read("#{data_source}/#{path}.yml")
      context.registers[:site].data["data_render_#{@id}"] = data_file
    end

    def render(context)
      datafile = fetch_datafile(context, @keys)

      config = { 'page' => @hash_args }
      config = { 'site' => { "data" => context.registers[:site].data } }.merge(config)
      versioned_yaml = SafeYAML.load(Liquid::Template.parse(datafile).render(config))
      context.registers[:site].data['data_render'] = versioned_yaml
      nil
    end
  end

  Liquid::Template.register_tag('data_render', Jekyll::DataRenderTag)
end
