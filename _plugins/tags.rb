module Jekyll
    # list of all tags on the site, with font size proportional to count
    class TagCloudTag < Liquid::Tag
        def initialize(tag_name, input, tokens)
            super
        end

        def render(context)
            tags = context['site']['tags']

            links = tags.map { |tag, posts|
                "<a href=\"/tags/#{tag}/\"
                style=\"font-size: #{10 + posts.length*2}px\">
                    #{tag}
                </a>"
            }
            return links.join(' | ')
        end
    end

    # a list of tags related to a post
    class TaglistTag < Liquid::Tag
        def initialize(tag_name, input, tokens)
            super
            @ctx = input
        end

        def render(context)
            tags = context[@ctx]['tags']

            links = tags.map { |tag|
                "<a href=\"/tags/#{tag}/\"> ##{tag}</a>"
            }.join(' ')

            return " • <span class=\"tags\">#{links}</span>"
        end
    end

    # a tag index page, /tags/cmake/index.html
    class TagIndex < Page
      def initialize(site, base, dir, tag)
        @site = site
        @base = base
        @dir = dir
        @name = 'index.html'
        self.process(@name)
        self.read_yaml(File.join(base, '_layouts'), 'tagpage.html')
        self.data['tag'] = tag
        self.data['title'] = "Posts Tagged ##{tag}"
      end
    end
    # generator for /tags/cmake/index.html
    class TagGenerator < Generator
      safe true
      def generate(site)
        if site.layouts.key? 'tagpage'
          site.tags.keys.each do |tag|
            write_tag_index(site, File.join('tags', tag), tag)
          end
        end
      end
      def write_tag_index(site, dir, tag)
        index = TagIndex.new(site, site.source, dir, tag)
        index.render(site.layouts, site.site_payload)
        index.write(site.dest)
        site.static_files << index
      end
    end
end
Liquid::Template.register_tag('tag_cloud', Jekyll::TagCloudTag)
Liquid::Template.register_tag('tags', Jekyll::TaglistTag)
