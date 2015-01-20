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
          value = Liquid::Template.parse(value).render({ "site" => { "data" => @site.data }.merge(@site.config) })
          @data[key] = Jekyll::Renderer.new(@site, self).convert(value)
          @data[key] = @data[key].sub(/^<p>/, '').sub(/<\/p>$/, '').strip
        end
      end
    end
  end

  class Site
    alias_method :old_read, :read

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
