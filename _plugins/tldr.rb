class TldrInlineTag < Liquid::Tag
    def initialize(tag_name, input, tokens)
        super
    end

    def render(context)
        output =  "<div class=\"tldr\"><h5>TL;DR</h5><p>"
        return output;
    end
end
Liquid::Template.register_tag('tldr', TldrInlineTag)

class EndTldrInlineTag < Liquid::Tag
    def initialize(tag_name, input, tokens)
        super
    end

    def render(context)
        output =  "</p></div>"
        return output;
    end
end
Liquid::Template.register_tag('endtldr', EndTldrInlineTag)
