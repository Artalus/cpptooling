module Jekyll
    #everything is based on https://github.com/samrayner/jekyll-asset-path-plugin/blob/master/asset_path_tag.rb


    extend self # ruby magic to allow Jekyll.funcall
    def relative_url(context, *more)
        base = context['site']['baseurl']
        "\"#{File.join(base, more)}\""
    end

    def self.get_post_path(page_id, posts)
        #check for Jekyll version
        if Jekyll::VERSION < '3.0.0'
            #loop through posts to find match and get slug
            posts.each do |post|
                if post.id == page_id
                return post.slug
                end
            end
        else
            #loop through posts to find match and get slug, method calls for Jekyll 3
            posts.docs.each do |post|
                if post.id == page_id
                return post.data['slug']
                end
            end
        end

        return ""
    end

    class ImgInlineTag < Liquid::Tag
        def initialize(tag_name, input, tokens)
            @markup = input.strip.strip
            super
        end

        def render(context)
            if @markup.empty?
                return "Error processing input, expected syntax: {% img filename post_id %}"
            end
            #render the markup
            parameters = Liquid::Template.parse(@markup).render context
            parameters.strip!

            if ['"', "'"].include? parameters[0]
                # Quoted filename, possibly followed by post id
                last_quote_index = parameters.rindex(parameters[0])
                filename = parameters[1 ... last_quote_index]
                post_id = parameters[(last_quote_index + 1) .. -1].strip
            else
                # Unquoted filename, possibly followed by post id
                filename, post_id = parameters.split(/\s+/)
            end
            page = context.environments.first["page"]
            post_id = page["id"] if post_id == nil or post_id.empty?

            if post_id
                #if a post
                posts = context.registers[:site].posts
                path = Jekyll.get_post_path(post_id, posts)
              else
                path = page["url"]
              end

              #strip filename
            path = File.dirname(path) if path =~ /\.\w+$/
            lk = Jekyll::relative_url(context, 'assets', path, filename)
            output =  "<a href=#{lk} target=\"blank\"><img src=#{lk} /></a>"
        end
    end
end
Liquid::Template.register_tag('img', Jekyll::ImgInlineTag)
