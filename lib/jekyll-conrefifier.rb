module Jekyll
  class Document
    alias_method :old_read, :read

    # allow us to use any variable within Jekyll Frontmatter; for example:
    # title: What are {{ site.data.conrefs.product_name[site.audience] }} Pages?
    # renders as "GitHub Pages?" for dotcom, but "GitHub Enterprise Pages?" for Enterprise
    def read(opts = {})
      old_read(opts)
      @data.each_pair do |key, value|
        if value =~ /\{\{.+?\}\}/
          value = Liquid::Template.parse(value).render({ 'site' => { 'data' => @site.data }.merge(@site.config) })
          @data[key] = Jekyll::Renderer.new(@site, self).convert(value)
          @data[key] = @data[key].sub(/^<p>/, '').sub(/<\/p>$/, '').strip
        end
      end
    end
  end

  class Site
    alias_method :old_read, :read

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
            # if we hit upon if/unless conditionals, we'll need to pause and render them
            contents = File.read(path)
            if (matches = contents.scan /(\{% (?:if|unless).+? %\}.*?\{% end(?:if|unless) %\})/m)
              unless data_file_variables(path).nil?
                contents = contents.gsub(/\{\{/, '[[')
                contents = apply_vars_to_datafile(contents, matches, path)
                contents = contents.gsub(/\[\[/, '{{')
              end
            end
            data[key] = SafeYAML.load(contents)
          end
        end
      end

      # once we're all done, we need to iterate once more to parse out `{{ }}` blocks.
      # two reasons for this: one, we need to collect every data file before attempting to
      # parse these vars; two, the Liquid parse above obliterates these tags, so we
      # first need to convert them into `[[ }}`, and *then* continue with the parse
      data.each_pair do |datafile, value|
        yaml_dump = YAML::dump value
        data[datafile] = SafeYAML.load transform_liquid_variables(yaml_dump, datafile)
      end
    end

    # apply the custom scoope plus the rest of the `site.data` information
    def apply_vars_to_datafile(contents, matches, path)
      return contents if matches.empty?

      data_vars = path.nil? ? {} : data_file_variables(path)

      config = { 'page' => data_vars }
      config = { 'site' => { 'data' => self.data } }.merge(config)

      matches.each do |match|
        parsed_content = begin
                          Liquid::Template.parse(match.first).render(config)
                         rescue
                          match.first
                         end

        contents = contents.sub(match.first, parsed_content)
      end

      contents
    end

    # fetch the custom scope vars, as defined in _config.yml
    def data_file_variables(path)
      data_vars = {}
      scopes = config['data_file_variables'].select { |v| v['scope']['path'].empty? || Regexp.new(v['scope']['path']) =~ path }
      scopes.each do |scope|
        data_vars = data_vars.merge(scope['values'])
      end

      data_vars
    end

    # allow us to use any variable within Jekyll data files; for example:
    # - '{{ site.data.conrefs.product_name[site.audience] }} Glossary'
    # renders as "GitHub Glossary" for dotcom, but "GitHub Enterprise Glossary" for Enterprise
    def transform_liquid_variables(contents, path=nil)
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
        @hash_args = paren_arg[1].gsub(/[{}:]/,'').split(', ').map{|h| h1,h2 = h.split('=>'); {h1.strip => h2.strip}}.reduce(:merge)
      end
      @keys = keys
      @id = keys.join('-')
    end

    def fetch_datafile(context, keys)
      data_file = context.registers[:site].data["data_render_#{@id}"]
      return data_file unless data_file.nil?

      path = @id.sub('.', '/')
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
