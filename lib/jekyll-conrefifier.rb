class Hash
  def insert_before(key, kvpair)
    arr = to_a
    pos = arr.index(arr.assoc(key))
    if pos
      arr.insert(pos, kvpair)
    else
      arr << kvpair
    end
    replace Hash[arr]
  end
end

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
    alias_method :old_read_data_to, :read_data_to

    def in_source_dir(*paths)
      paths.reduce(source) do |base, path|
        Jekyll.sanitized_path(base, path)
      end
    end

    # allows us to filter data file content out on conditionals, eg. `{% if page.version == ... %}`
    def read_data_to(dir, data)
      return unless File.directory?(dir) && (!safe || !File.symlink?(dir))

      entries = Dir.chdir(dir) do
        Dir['*.{yaml,yml,json,csv}'] + Dir['*'].select { |fn| File.directory?(fn) }
      end

      entries.each do |entry|
        path = in_source_dir(dir, entry)
        next if File.symlink?(path) && safe

        key = sanitize_filename(File.basename(entry, '.*'))
        if File.directory?(path)
          read_data_to(path, data[key] = {})
        else
          case File.extname(path).downcase
          when '.csv'
            data[key] = CSV.read(path, :headers => true).map(&:to_hash)
          else
            contents = File.read(path)
            if (matches = contents.scan /(\{% (?:if|unless).+? %\}.*?\{% end(?:if|unless) %\})/m)
              unless matches.empty?
                contents = apply_vars_to_datafile(contents, path, matches, config['data_file_variables'])
              end
            end
            data[key] = SafeYAML.load(contents)
          end
        end
      end
    end

    def apply_vars_to_datafile(contents, path, matches, data_file_variables)
      return contents if data_file_variables.nil?
      data_vars = {}
      scopes = data_file_variables.select { |v| v['scope']['path'].empty? || Regexp.new(v['scope']['path']) =~ path }
      scopes.each do |scope|
        data_vars = data_vars.merge(scope['values'])
      end
      temp_config = self.config.merge({ 'page' => data_vars })
      matches.each do |match|
        contents = contents.sub(match.first, Liquid::Template.parse(match.first).render(temp_config))
      end

      contents
    end

    # allow us to use any variable within Jekyll data files; for example:
    # - '{{ site.data.conrefs.product_name[site.audience] }} Glossary'
    # renders as "GitHub Glossary" for dotcom, but "GitHub Enterprise Glossary" for Enterprise
    def read
      keys_to_modify = {}
      old_read
      data.each_pair do |data_file, data_set|
        if data_set.is_a? Hash
          data_set.each_pair do |key, values|
            if key =~ /\{\{.+?\}\}/
              new_key = Liquid::Template.parse(key).render({ "site" => { "data" => data }.merge(config) })
              keys_to_modify[key] = new_key
            end
            if values.is_a? Array
              values.each_with_index do |value, i|
                if value =~ /\{\{.+?\}\}/
                  value = Liquid::Template.parse(value).render({ "site" => { "data" => data }.merge(config) })
                  data[data_file][key][i] = value
                end
              end
            end
          end
          keys_to_modify.each_pair do |old_key, new_key|
            data[data_file].insert_before(old_key, [new_key, data[data_file][old_key]])
            data[data_file].delete(old_key)
          end
        end
      end
    end
  end
end
